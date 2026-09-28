import importlib
import shlex
import subprocess
from pathlib import Path
from types import ModuleType
from typing import TextIO
from unittest.mock import Mock

import pytest

from scripts import token_counts


@pytest.fixture
def ux_modules(monkeypatch: pytest.MonkeyPatch) -> tuple[ModuleType, ModuleType]:
    """Import the repository-owned UX helper scripts without connecting to a device."""
    helpers = Path(__file__).resolve().parents[2] / ".claude/skills/ux-visual-debug/scripts"
    monkeypatch.syspath_prepend(str(helpers))
    return importlib.import_module("ux_runner_core"), importlib.import_module("agent_link")


def test_token_report_reads_current_default_agent_prompt() -> None:
    """Detect stale source paths or extraction markers that silently report zero tokens."""
    assert token_counts.AGENT_DEF.is_file()
    counts = token_counts.measure_system_prompt()
    assert counts["chars"] > 0
    assert counts["tokens"] > 0
    assert counts["lines"] > 1


def test_ux_shell_preserves_literal_arguments(
    ux_modules: tuple[ModuleType, ModuleType], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Pass UI input text through Android's shell without interpreting its metacharacters."""
    core, _ = ux_modules
    calls: list[list[str]] = []

    def run(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        """Record the ADB call in place of invoking a real device."""
        calls.append(command)
        return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

    monkeypatch.setattr(core.subprocess, "run", run)
    runner = core.UXRunner({"name": "quoting"}, tmp_path, serial="test-device")
    text = "literal spaces & $(echo ignored) 'quote'"
    runner.shell("input", "text", text)
    assert calls[0][:4] == ["adb", "-s", "test-device", "shell"]
    assert shlex.split(calls[0][4]) == ["input", "text", text]


def test_agent_launcher_closes_parent_log_handle(
    ux_modules: tuple[ModuleType, ModuleType], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Release the parent's file descriptor after the child inherits its output log."""
    _, links = ux_modules
    handles: list[TextIO] = []

    def start(command: list[str], **kwargs: object) -> Mock:
        """Capture the launch log without running the debug script."""
        log = kwargs["stdout"]
        assert not log.closed
        handles.append(log)
        return Mock()

    monkeypatch.setattr(links.subprocess, "Popen", start)
    link = links.AgentLink(
        project_root=tmp_path,
        run_dir=tmp_path,
        serial=None,
        goal="Open Settings",
        mode="parallel",
        run_setup=False,
        debug_args=[],
        join_timeout_sec=1,
        start_delay_ms=0,
    )
    link._start_debug_run()
    assert handles[0].closed
    assert link.state.debug_run_started
