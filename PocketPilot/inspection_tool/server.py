import base64
import binascii
import json
import subprocess
import sys
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

app = FastAPI()

INSPECTION_TOOL_DIR = Path(__file__).parent.resolve()
DEBUG_OUTPUT_DIR = (INSPECTION_TOOL_DIR / "../debug-output").resolve()
EVAL_RESULTS_DIR = (INSPECTION_TOOL_DIR / "../eval/results").resolve()
REPLAY_V2_DIR = INSPECTION_TOOL_DIR / "replay_v2"
COMPILE_TIMEOUT_SECONDS = 120


class TraceInfo(BaseModel):
    id: str
    trace_id: str
    compiled: bool


class EvalRunInfo(BaseModel):
    id: str
    tasks: list[TraceInfo]


class CatalogResponse(BaseModel):
    debug_runs: list[TraceInfo]
    eval_runs: list[EvalRunInfo]


class RunInfo(BaseModel):
    id: str
    timestamp: str | None = None
    compiled: bool


def _encode_trace_id(payload: dict[str, str]) -> str:
    """Encode a trace location as a URL-safe identifier.

    Args:
        payload: Trace kind, run name, and optional task name.

    Returns:
        Base64 identifier without padding.
    """
    raw = json.dumps(payload, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _decode_trace_id(trace_id: str) -> dict[str, str]:
    """Decode and validate a catalog trace identifier.

    Args:
        trace_id: Encoded trace location from the catalog.

    Returns:
        Validated trace location fields.

    Raises:
        HTTPException: The identifier is malformed or lacks required fields.
    """
    pad = "=" * (-len(trace_id) % 4)
    try:
        decoded = base64.b64decode(trace_id + pad, altchars=b"-_", validate=True).decode("utf-8")
        payload = json.loads(decoded)
    except (ValueError, UnicodeError, binascii.Error) as exc:
        raise HTTPException(status_code=400, detail="Invalid trace id") from exc

    if isinstance(payload, dict):
        kind, run_id, task_id = payload.get("k"), payload.get("r"), payload.get("t")
        if isinstance(run_id, str) and run_id:
            if kind == "debug":
                return {"k": kind, "r": run_id}
            if kind == "eval" and isinstance(task_id, str) and task_id:
                return {"k": kind, "r": run_id, "t": task_id}
    raise HTTPException(status_code=400, detail="Invalid trace id")


def _ensure_within(root: Path, target: Path) -> None:
    """Reject paths outside the allowed root, including symlink escapes.

    Args:
        root: Allowed directory.
        target: Requested path.

    Raises:
        HTTPException: The resolved path escapes the root.
    """
    if not target.resolve().is_relative_to(root.resolve()):
        raise HTTPException(status_code=403, detail="Access denied")


def _resolve_trace_dir(trace_id: str) -> Path:
    """Resolve a trace identifier within its configured artifact root.

    Args:
        trace_id: Catalog trace identifier.

    Returns:
        Contained, resolved trace directory.
    """
    payload = _decode_trace_id(trace_id)
    if payload["k"] == "debug":
        root = DEBUG_OUTPUT_DIR
        trace_dir = root / payload["r"] / "trace"
    else:
        root = EVAL_RESULTS_DIR
        trace_dir = root / payload["r"] / "artifacts" / payload["t"] / "trace"
    _ensure_within(root, trace_dir)
    return trace_dir.resolve()


def _trace_info(directory: Path, payload: dict[str, str]) -> TraceInfo:
    """Build the shared catalog entry for a debug run or evaluation task.

    Args:
        directory: Directory containing the trace folder.
        payload: Trace identifier fields.

    Returns:
        Catalog entry and current compilation state.
    """
    return TraceInfo(
        id=directory.name,
        trace_id=_encode_trace_id(payload),
        compiled=(directory / "trace" / "derived" / "steps.jsonl").is_file(),
    )


def _build_catalog() -> CatalogResponse:
    """Scan debug and evaluation roots for replayable traces.

    Returns:
        Catalog ordered by descending run name and ascending task name.
    """
    debug_runs = [
        _trace_info(run, {"k": "debug", "r": run.name})
        for run in sorted(DEBUG_OUTPUT_DIR.glob("run_*"), reverse=True)
        if run.is_dir()
    ]
    eval_runs = []
    for run in sorted(EVAL_RESULTS_DIR.glob("*"), reverse=True):
        if not run.is_dir() or run.name.startswith("."):
            continue
        tasks = [
            _trace_info(task, {"k": "eval", "r": run.name, "t": task.name})
            for task in sorted((run / "artifacts").glob("*"))
            if task.is_dir() and (task / "trace").is_dir()
        ]
        if tasks:
            eval_runs.append(EvalRunInfo(id=run.name, tasks=tasks))
    return CatalogResponse(debug_runs=debug_runs, eval_runs=eval_runs)


def _compile_trace_dir(trace_dir: Path) -> dict[str, str]:
    """Compile replay files with the server's Python interpreter.

    Args:
        trace_dir: Validated trace directory.

    Returns:
        Compilation status and compiler output.

    Raises:
        HTTPException: Trace input is missing, compilation fails, or it times out.
    """
    if not trace_dir.is_dir():
        raise HTTPException(status_code=404, detail="Trace directory not found")
    if not (trace_dir / "trace.jsonl").is_file():
        raise HTTPException(status_code=404, detail="trace.jsonl not found")

    try:
        result = subprocess.run(
            [sys.executable, str(INSPECTION_TOOL_DIR / "replay_compiler.py"), str(trace_dir)],
            capture_output=True,
            text=True,
            check=True,
            timeout=COMPILE_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        raise HTTPException(status_code=504, detail="Compilation timed out") from exc
    except subprocess.CalledProcessError as exc:
        raise HTTPException(status_code=500, detail=f"Compilation failed: {exc.stderr}") from exc
    return {"status": "success", "output": result.stdout}


@app.get("/api/catalog", response_model=CatalogResponse)
def get_catalog() -> CatalogResponse:
    """Return available traces, scanning files in FastAPI's worker thread pool."""
    return _build_catalog()


@app.get("/api/runs", response_model=list[RunInfo])
def list_runs_legacy() -> list[RunInfo]:
    """Return debug runs in the original frontend's response format."""
    return [RunInfo(id=run.id, compiled=run.compiled) for run in _build_catalog().debug_runs]


@app.post("/api/traces/{trace_id}/compile")
def compile_trace(trace_id: str) -> dict[str, str]:
    """Compile a catalog trace in a worker thread.

    Args:
        trace_id: Encoded catalog location.

    Returns:
        Compiler status and output.
    """
    return _compile_trace_dir(_resolve_trace_dir(trace_id))


@app.post("/api/runs/{run_id}/compile")
def compile_run_legacy(run_id: str) -> dict[str, str]:
    """Compile a debug run requested by the original frontend.

    Args:
        run_id: Debug run directory name.

    Returns:
        Compiler status and output.
    """
    trace_dir = (DEBUG_OUTPUT_DIR / run_id / "trace").resolve()
    _ensure_within(DEBUG_OUTPUT_DIR, trace_dir)
    return _compile_trace_dir(trace_dir)


@app.get("/traces/{trace_id}/{path:path}")
def get_trace_file(trace_id: str, path: str) -> FileResponse:
    """Serve a file contained within a catalog trace.

    Args:
        trace_id: Encoded catalog location.
        path: File path relative to the trace directory.

    Returns:
        Streamed trace artifact.

    Raises:
        HTTPException: The trace or file is missing, or the path escapes its root.
    """
    trace_dir = _resolve_trace_dir(trace_id)
    if not trace_dir.is_dir():
        raise HTTPException(status_code=404, detail="Trace directory not found")
    safe_path = (trace_dir / path).resolve()
    _ensure_within(trace_dir, safe_path)
    if not safe_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(safe_path)


if REPLAY_V2_DIR.exists():
    app.mount("/", StaticFiles(directory=str(REPLAY_V2_DIR), html=True), name="static")

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
