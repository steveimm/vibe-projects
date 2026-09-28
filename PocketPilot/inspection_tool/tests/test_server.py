import asyncio
import subprocess
import sys
import threading
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from inspection_tool import server


@pytest.fixture
def trace_roots(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Keep replay fixtures separate from real user traces."""
    monkeypatch.setattr(server, "DEBUG_OUTPUT_DIR", tmp_path / "debug")
    monkeypatch.setattr(server, "EVAL_RESULTS_DIR", tmp_path / "eval")
    trace = server.DEBUG_OUTPUT_DIR / "run_sample" / "trace"
    trace.mkdir(parents=True)
    (trace / "trace.jsonl").write_text('{"type":"session_started","sessionId":"main","seq":1}\n')
    return trace


def test_catalog_compile_and_file_endpoints(trace_roots: Path) -> None:
    """Compile a real trace, retain the legacy route, and serve its replay artifact."""
    with TestClient(server.app) as client:
        catalog = client.get("/api/catalog").json()
        trace_id = catalog["debug_runs"][0]["trace_id"]
        assert catalog["debug_runs"][0]["compiled"] is False
        assert client.post(f"/api/traces/{trace_id}/compile").status_code == 200
        assert client.get("/api/runs").json() == [{"id": "run_sample", "timestamp": None, "compiled": True}]
        response = client.get(f"/traces/{trace_id}/derived/agent_tree.json")
        assert response.status_code == 200
        assert response.json()["sessions"][0]["session_id"] == "main"
        assert client.post("/api/runs/run_sample/compile").status_code == 200


def test_trace_paths_reject_traversal_and_symlink_escape(trace_roots: Path, tmp_path: Path) -> None:
    """Reject access to files and directories outside the configured roots."""
    outside = tmp_path / "private.txt"
    outside.write_text("private")
    (trace_roots / "escape").symlink_to(outside)
    escaped_id = server._encode_trace_id({"k": "debug", "r": "../../outside"})
    valid_id = server._encode_trace_id({"k": "debug", "r": "run_sample"})
    with TestClient(server.app) as client:
        assert client.post(f"/api/traces/{escaped_id}/compile").status_code == 403
        assert client.get(f"/traces/{valid_id}/escape").status_code == 403
        assert client.get(f"/traces/{valid_id}/derived").status_code == 404
        assert client.post("/api/traces/not_valid!!/compile").status_code == 400


def test_compile_timeout_returns_gateway_timeout(trace_roots: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Expose a bounded compiler timeout without hiding interpreter selection."""

    def timeout(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        """Simulate an unresponsive replay compiler."""
        assert command[0] == sys.executable
        assert kwargs["timeout"] == server.COMPILE_TIMEOUT_SECONDS
        raise subprocess.TimeoutExpired(command, server.COMPILE_TIMEOUT_SECONDS)

    monkeypatch.setattr(server.subprocess, "run", timeout)
    with TestClient(server.app) as client:
        assert client.post("/api/runs/run_sample/compile").status_code == 504


def test_compilation_does_not_block_catalog_requests(trace_roots: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Keep catalog requests responsive while compilation waits for a subprocess."""
    started, release = threading.Event(), threading.Event()
    event_loop_thread = threading.get_ident()

    def compile_trace(trace_dir: Path) -> dict[str, str]:
        """Hold compilation until a concurrent catalog request finishes."""
        assert threading.get_ident() != event_loop_thread
        started.set()
        assert release.wait(3), "Catalog request was blocked by compilation"
        return {"status": "success", "output": ""}

    async def requests() -> None:
        """Issue both requests on one event loop to expose accidental blocking."""
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=server.app), base_url="http://test") as client:
            compile_request = asyncio.create_task(client.post("/api/runs/run_sample/compile"))
            try:
                assert await asyncio.to_thread(started.wait, 2)
                catalog = await asyncio.wait_for(client.get("/api/catalog"), timeout=1)
                assert catalog.status_code == 200
            finally:
                release.set()
                response = await compile_request
            assert response.status_code == 200

    monkeypatch.setattr(server, "_compile_trace_dir", compile_trace)
    asyncio.run(requests())
