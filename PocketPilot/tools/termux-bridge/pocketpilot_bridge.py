#!/usr/bin/env python3
from __future__ import annotations

import argparse
import errno
import json
import os
import select
import selectors
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import BinaryIO, NoReturn

BRIDGE_VERSION = "1"
IDENTITY = "pocketpilot-bridge"
DEFAULT_HOST, DEFAULT_PORT = "127.0.0.1", 18422
DEFAULT_TIMEOUT_MS = MAX_TIMEOUT_MS = 120_000
DEFAULT_OUTPUT_BYTES = 65536
POLL_SEC = 0.25


class InvalidRequest(Exception):
    """The request cannot be executed with the supplied arguments."""


class WorkspaceEscape(Exception):
    """The requested working directory is outside the configured workspace."""


@dataclass(frozen=True)
class ExecSpec:
    command: str
    cwd: str
    timeout_ms: int
    env: dict[str, str]
    max_bytes: int


def pocketpilot_dir() -> Path:
    """Create and return the bridge's private state directory."""
    path = Path.home() / ".pocketpilot"
    path.mkdir(parents=True, exist_ok=True)
    return path


def workspace_root() -> Path:
    """Create and resolve the configured command working directory."""
    raw = os.environ.get("POCKETPILOT_WORKSPACE") or "~/pocketpilot/workspace"
    path = Path(os.path.expanduser(raw)).resolve()
    path.mkdir(parents=True, exist_ok=True)
    return path


def port_in_use() -> NoReturn:
    """Report a bridge address conflict and terminate startup."""
    print("port_in_use", file=sys.stderr)
    sys.exit(1)


def pid_alive(pid: int) -> bool:
    """Check whether a process is still reachable by its identifier.

    Args:
        pid: Process identifier.
    """
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def wait_dead(pid: int, timeout_sec: float) -> bool:
    """Wait up to the deadline for a process to exit.

    Args:
        pid: Process identifier.
        timeout_sec: Maximum wait in seconds.
    """
    deadline = time.monotonic() + timeout_sec
    while time.monotonic() < deadline:
        if not pid_alive(pid):
            return True
        time.sleep(0.05)
    return not pid_alive(pid)


def read_pidfile(pidfile: Path) -> dict[str, object]:
    """Read bridge ownership metadata, removing unreadable or malformed files.

    Args:
        pidfile: Path to bridge ownership metadata.
    """
    if not pidfile.exists():
        return {}
    try:
        data = json.loads(pidfile.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        try:
            pidfile.unlink()
        except OSError:
            pass
        return {}


def health_is_bridge(port: object) -> bool:
    """Check whether a local port serves this bridge's health identity.

    Args:
        port: Local TCP listening port.
    """
    if isinstance(port, bool) or not isinstance(port, int):
        return False
    try:
        url = f"http://127.0.0.1:{port}/v1/health"
        with urllib.request.urlopen(url, timeout=1) as response:
            data = json.loads(response.read().decode())
        return isinstance(data, dict) and data.get("identity") == IDENTITY
    except (OSError, ValueError, json.JSONDecodeError, urllib.error.URLError):
        return False


def terminate_pid(pid: int) -> None:
    """Terminate an existing bridge process, escalating to kill after the deadline.

    Args:
        pid: Process identifier.
    """
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    except OSError:
        port_in_use()
    if not wait_dead(pid, 2):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        if not wait_dead(pid, 1):
            port_in_use()


def kill_old_bridge(pidfile: Path) -> None:
    """Stop the prior bridge only after validating its PID file and health identity.

    Args:
        pidfile: Path to bridge ownership metadata.
    """
    data = read_pidfile(pidfile)
    if not data:
        return
    pid = data.get("pid")
    if isinstance(pid, bool) or not isinstance(pid, int) or pid <= 0 or not pid_alive(pid):
        try:
            pidfile.unlink()
        except OSError:
            pass
        return
    if data.get("identity") != IDENTITY or not health_is_bridge(data.get("port")):
        port_in_use()
    terminate_pid(pid)


def write_pidfile(pidfile: Path, port: int) -> None:
    """Record the current bridge process identity and listening port.

    Args:
        pidfile: Path to bridge ownership metadata.
        port: Local TCP listening port.
    """
    payload = {"pid": os.getpid(), "port": port, "version": BRIDGE_VERSION, "identity": IDENTITY, "started_at": time.time()}
    pidfile.write_text(json.dumps(payload, separators=(",", ":")))


def remove_own_pidfile(pidfile: Path) -> None:
    """Remove the PID file only if it still identifies this process.

    Args:
        pidfile: Path to bridge ownership metadata.
    """
    try:
        data = json.loads(pidfile.read_text())
        if isinstance(data, dict) and data.get("pid") == os.getpid() and data.get("identity") == IDENTITY:
            pidfile.unlink()
    except (OSError, json.JSONDecodeError):
        pass


class Capture:
    def __init__(self, call_id: str, stream: str, max_bytes: int) -> None:
        self.stream = stream
        self.max_bytes = max_bytes
        self.visible = bytearray()
        self.truncated = False
        self.ref: str | None = None
        self._artifact: BinaryIO | None = None
        self.call_id = call_id

    def append(self, chunk: bytes) -> None:
        """Append output, spilling the complete stream to disk after the display limit.

        Args:
            chunk: Raw subprocess output bytes.
        """
        if not chunk:
            return
        if not self.truncated and len(self.visible) + len(chunk) <= self.max_bytes:
            self.visible.extend(chunk)
            return
        if not self.truncated:
            self.truncated = True
            artifact_dir = pocketpilot_dir() / "artifacts"
            artifact_dir.mkdir(parents=True, exist_ok=True)
            self.ref = str(artifact_dir / f"{self.call_id}_{self.stream}")
            self._artifact = open(self.ref, "wb")
            self._artifact.write(self.visible)
        remaining = self.max_bytes - len(self.visible)
        if remaining > 0:
            self.visible.extend(chunk[:remaining])
        if self._artifact is not None:
            self._artifact.write(chunk)

    def close(self) -> None:
        """Close an output artifact when capture has overflowed to disk."""
        if self._artifact:
            self._artifact.close()

    def text(self) -> str:
        """Decode the visible output prefix with replacement for invalid UTF-8."""
        return bytes(self.visible).decode(errors="replace")


def client_connected(conn: socket.socket) -> bool:
    """Probe whether the HTTP client has disconnected without consuming request bytes.

    Args:
        conn: HTTP client socket.
    """
    try:
        readable, _, _ = select.select([conn], [], [], 0)
        if not readable:
            return True
        return bool(conn.recv(1, socket.MSG_PEEK))
    except BlockingIOError:
        return True
    except OSError:
        return False


def kill_process_group(proc: subprocess.Popen[bytes], graceful: bool) -> None:
    """Stop the command and its descendants, even if the parent shell has exited.

    Args:
        proc: Child process to monitor or stop.
        graceful: Whether to send SIGTERM before killing remaining descendants.
    """
    # start_new_session makes the child's PID its process group ID, even after the shell exits.
    pgid = proc.pid
    try:
        os.killpg(pgid, signal.SIGTERM if graceful else signal.SIGKILL)
    except (ProcessLookupError, OSError):
        return
    if not graceful:
        return
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(pgid, signal.SIGKILL)
    except OSError:
        pass


def positive_int(value: object, default: int) -> int:
    """Validate a positive integer or use the default for an omitted value.

    Args:
        value: Input value to validate or normalize.
        default: Value used when the caller omits the setting.
    """
    if value is None:
        return default
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise InvalidRequest
    return value


def parse_timeout(value: object) -> int:
    """Validate and cap the requested execution timeout.

    Args:
        value: Input value to validate or normalize.
    """
    return min(positive_int(value, DEFAULT_TIMEOUT_MS), MAX_TIMEOUT_MS)


def resolve_cwd(value: object) -> str:
    """Resolve a working directory and reject workspace or symlink escapes.

    Args:
        value: Input value to validate or normalize.
    """
    root = workspace_root()
    if value is None or value == "":
        return str(root)
    if not isinstance(value, str) or "\x00" in value:
        raise InvalidRequest
    path = Path(os.path.expanduser(value)).resolve()
    if path != root and root not in path.parents:
        raise WorkspaceEscape
    if not path.is_dir():
        raise InvalidRequest
    return str(path)


def parse_env(value: object) -> dict[str, str]:
    """Merge validated subprocess environment overrides with the daemon environment.

    Args:
        value: Input value to validate or normalize.
    """
    merged = os.environ.copy()
    if value is None:
        return merged
    if not isinstance(value, dict):
        raise InvalidRequest
    for key, val in value.items():
        if not isinstance(key, str) or not isinstance(val, str):
            raise InvalidRequest
        if not key or "=" in key or "\x00" in key or "\x00" in val:
            raise InvalidRequest
        merged[key] = val
    return merged


def parse_exec(payload: dict[str, object]) -> ExecSpec:
    """Validate command arguments before occupying the execution slot.

    Args:
        payload: JSON-compatible record to validate or serialize.
    """
    command = payload.get("command")
    if not isinstance(command, str) or "\x00" in command:
        raise InvalidRequest
    return ExecSpec(
        command=command,
        cwd=resolve_cwd(payload.get("cwd")),
        timeout_ms=parse_timeout(payload.get("timeout_ms")),
        env=parse_env(payload.get("env")),
        max_bytes=positive_int(payload.get("max_output_bytes"), DEFAULT_OUTPUT_BYTES),
    )


def run_command(request: Handler, spec: ExecSpec) -> tuple[int, dict[str, object], bool]:
    """Execute a command with bounded output, timeout, and disconnect cleanup.

    Args:
        request: Active HTTP request carrying the client connection.
        spec: Validated command and execution limits.
    """
    call_id = uuid.uuid4().hex
    stdout = Capture(call_id, "stdout", spec.max_bytes)
    stderr = Capture(call_id, "stderr", spec.max_bytes)
    start = time.monotonic()
    timed_out = False
    disconnected = False
    try:
        proc = subprocess.Popen(
            ["bash", "-c", spec.command],
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=spec.cwd,
            env=spec.env,
        )
    except OSError:
        return 500, {"error": "exec_failed"}, False
    assert proc.stdout is not None and proc.stderr is not None
    try:
        with selectors.DefaultSelector() as streams:
            streams.register(proc.stdout, selectors.EVENT_READ, stdout)
            streams.register(proc.stderr, selectors.EVENT_READ, stderr)
            while proc.poll() is None or streams.get_map():
                if int((time.monotonic() - start) * 1000) >= spec.timeout_ms:
                    timed_out = True
                    kill_process_group(proc, graceful=True)
                    break
                if not client_connected(request.connection):
                    disconnected = True
                    kill_process_group(proc, graceful=False)
                    break
                for key, _ in streams.select(timeout=POLL_SEC):
                    chunk = os.read(key.fd, 4096)
                    if chunk:
                        key.data.append(chunk)
                    else:
                        streams.unregister(key.fileobj)
    finally:
        if proc.poll() is None:
            kill_process_group(proc, graceful=False)
        proc.wait()
        proc.stdout.close()
        proc.stderr.close()
        stdout.close()
        stderr.close()
    return (
        200,
        {
            "exit_code": None if timed_out else proc.returncode,
            "stdout": stdout.text(),
            "stderr": stderr.text(),
            "stdout_truncated": stdout.truncated,
            "stderr_truncated": stderr.truncated,
            "stdout_ref": stdout.ref,
            "stderr_ref": stderr.ref,
            "timed_out": timed_out,
            "duration_ms": int((time.monotonic() - start) * 1000),
        },
        disconnected,
    )


class BridgeServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], handler: type[Handler], idle_timeout_sec: int, watchdog_tick_sec: float) -> None:
        super().__init__(address, handler)
        self.started_at = time.monotonic()
        self.last_request_at = self.started_at
        self.last_request_lock = threading.Lock()
        self.exec_lock = threading.Lock()
        self.idle_timeout_sec = idle_timeout_sec
        self.watchdog_tick_sec = watchdog_tick_sec

    def touch_request(self) -> None:
        """Record request activity for the idle watchdog."""
        with self.last_request_lock:
            self.last_request_at = time.monotonic()

    def uptime_ms(self) -> int:
        """Return milliseconds since server startup."""
        return int((time.monotonic() - self.started_at) * 1000)

    def last_request_ms_ago(self) -> int:
        """Return elapsed milliseconds since the most recent request."""
        with self.last_request_lock:
            return int((time.monotonic() - self.last_request_at) * 1000)


class Handler(BaseHTTPRequestHandler):
    server: BridgeServer
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args: object) -> None:
        """Suppress the default HTTP access log.

        Args:
            fmt: Unused HTTP log format string.
        """
        return

    def send_error(self, code: int, message: str | None = None, explain: str | None = None) -> None:
        """Return protocol errors using the bridge's JSON response format.

        Args:
            code: HTTP error status.
            message: Unused HTTP error message.
            explain: Unused HTTP error explanation.
        """
        self.send_json(code, {"error": "http_error"})

    def send_json(self, status: int, body: dict[str, object]) -> None:
        """Write a JSON response and close the HTTP connection.

        Args:
            status: HTTP response status.
            body: JSON response fields.
        """
        data = json.dumps(body, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True

    def read_json(self) -> dict[str, object]:
        """Read a bounded JSON request body under a short socket timeout."""
        old_timeout = self.connection.gettimeout()
        self.connection.settimeout(5)
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 1024 * 1024:
                raise ValueError
            data = json.loads(self.rfile.read(length).decode())
        except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError):
            raise InvalidRequest
        finally:
            self.connection.settimeout(old_timeout)
        if not isinstance(data, dict):
            raise InvalidRequest
        return data

    def do_GET(self) -> None:
        """Serve bridge health checks and reject other GET routes."""
        self.server.touch_request()
        if self.path.split("?", 1)[0] != "/v1/health":
            self.send_json(404, {"error": "not_found"})
            return
        self.send_json(
            200,
            {
                "status": "ok",
                "version": BRIDGE_VERSION,
                "identity": IDENTITY,
                "uptime_ms": self.server.uptime_ms(),
                "last_request_ms_ago": self.server.last_request_ms_ago(),
            },
        )

    def do_POST(self) -> None:
        """Validate and serialize command execution requests, returning errors as JSON."""
        self.server.touch_request()
        if self.path.split("?", 1)[0] != "/v1/exec":
            self.send_json(404, {"error": "not_found"})
            return
        try:
            spec = parse_exec(self.read_json())
        except WorkspaceEscape:
            self.send_json(400, {"error": "workspace_escape"})
            return
        except InvalidRequest:
            self.send_json(400, {"error": "invalid_request"})
            return
        if not self.server.exec_lock.acquire(blocking=False):
            self.send_json(409, {"error": "busy"})
            return
        try:
            status, body, disconnected = run_command(self, spec)
            if not disconnected:
                self.send_json(status, body)
        finally:
            self.server.exec_lock.release()


def watchdog(server: BridgeServer) -> None:
    """Stop the HTTP server after the configured period without requests.

    Args:
        server: Bridge server whose activity is monitored.
    """
    while True:
        time.sleep(server.watchdog_tick_sec)
        if server.idle_timeout_sec <= 0:
            continue
        with server.last_request_lock:
            idle = time.monotonic() - server.last_request_at
        if idle > server.idle_timeout_sec:
            server.shutdown()
            return


def parse_args() -> argparse.Namespace:
    """Parse command-line options for this tool."""
    parser = argparse.ArgumentParser(description="PocketPilot Termux bridge daemon")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--idle-timeout-sec", type=int, default=1800)
    parser.add_argument("--watchdog-tick-sec", type=float, default=60, help=argparse.SUPPRESS)
    return parser.parse_args()


def main() -> int:
    """Start the bridge daemon and clean up its ownership file on exit."""
    args = parse_args()
    pidfile = pocketpilot_dir() / "bridge.pid"
    kill_old_bridge(pidfile)
    try:
        server = BridgeServer((args.host, args.port), Handler, args.idle_timeout_sec, args.watchdog_tick_sec)
    except OSError as exc:
        if exc.errno == errno.EADDRINUSE:
            print("port_in_use", file=sys.stderr)
        else:
            print(f"internal_error: {exc.strerror or exc}", file=sys.stderr)
        return 1
    write_pidfile(pidfile, args.port)
    threading.Thread(target=watchdog, args=(server,), daemon=True).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        remove_own_pidfile(pidfile)
    return 0


if __name__ == "__main__":
    sys.exit(main())
