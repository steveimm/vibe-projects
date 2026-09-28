import json
from pathlib import Path

from inspection_tool.replay_compiler import compile_sessions, compile_steps, read_events


def test_replay_links_delegation_and_preserves_screen_artifacts(tmp_path: Path) -> None:
    """Compile a delegated turn into linked parent and child replay steps."""
    events = [
        {"type": "session_started", "sessionId": "main", "seq": 1, "data": {"agent_role": "main"}},
        {
            "type": "screen_captured",
            "sessionId": "main",
            "turnNumber": 1,
            "seq": 2,
            "artifacts": [{"kind": "screenshot", "path": "screen.png"}],
        },
        {"type": "tool_call", "sessionId": "main", "turnNumber": 1, "seq": 3, "data": {"id": "call1", "name": "delegate_task"}},
        {
            "type": "session_started",
            "sessionId": "main::child",
            "seq": 4,
            "data": {"delegation_call_id": "call1", "agent_role": "subagent"},
        },
        {"type": "llm_request", "sessionId": "main::child", "turnNumber": 1, "seq": 5},
        {
            "type": "tool_result",
            "sessionId": "main",
            "turnNumber": 1,
            "seq": 6,
            "artifacts": [{"kind": "sanitized_a11y_tree", "path": "tree.txt"}],
        },
        {"type": "session_stopped", "sessionId": "main::child", "seq": 7, "data": {"reason": "GOAL_ACHIEVED"}},
    ]
    trace = tmp_path / "trace.jsonl"
    trace.write_text("\n".join(json.dumps(event) for event in reversed(events)))
    loaded = read_events(trace)
    sessions, _ = compile_sessions(loaded)
    steps = {step["session_id"]: step for step in compile_steps(loaded, sessions)}
    assert sessions["main"]["children"] == ["main::child"]
    assert sessions["main::child"]["status"] == "GOAL_ACHIEVED"
    assert steps["main::child"]["links"]["parent_step_id"] == "main::turn-1"
    assert steps["main"]["links"]["child_session_ids"] == ["main::child"]
    assert steps["main"]["world"]["pre"]["screenshot"]["path"] == "screen.png"
    assert steps["main"]["world"]["post"]["sanitized_a11y_tree"]["path"] == "tree.txt"


def test_malformed_ordering_fields_do_not_break_step_compilation(tmp_path: Path) -> None:
    """Handle interrupted traces and malformed ordering fields consistently."""
    event = {"type": "llm_request", "sessionId": "main", "turnNumber": 1, "seq": None, "tsMs": "invalid"}
    trace = tmp_path / "trace.jsonl"
    trace.write_text(json.dumps(event) + '\n{"partial":\n[]\n')
    events = read_events(trace)
    sessions, _ = compile_sessions(events)
    steps = compile_steps(events, sessions)
    assert len(steps) == 1
    assert steps[0]["mind"]["llm_request"]["type"] == "llm_request"
