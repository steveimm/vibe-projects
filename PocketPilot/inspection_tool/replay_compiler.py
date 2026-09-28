#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import time
from collections import defaultdict
from collections.abc import Iterable
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    """Parse command-line options for this tool."""
    parser = argparse.ArgumentParser(description="Compile trace replay indexes")
    parser.add_argument("trace_dir", help="Directory that contains trace.jsonl")
    return parser.parse_args()


def safe_json_loads(line: str) -> dict[str, Any] | None:
    """Decode a JSON object, ignoring blank, malformed, or non-object records.

    Args:
        line: Log or JSONL record to inspect.
    """
    line = line.strip()
    if not line:
        return None
    try:
        parsed = json.loads(line)
    except json.JSONDecodeError:
        return None
    if not isinstance(parsed, dict):
        return None
    return parsed


def read_events(trace_file: Path) -> list[dict[str, Any]]:
    """Read valid trace events and order them by sequence and timestamp.

    Args:
        trace_file: Raw trace JSONL file.
    """
    events: list[dict[str, Any]] = []
    for raw_line in trace_file.read_text(encoding="utf-8").splitlines():
        event = safe_json_loads(raw_line)
        if event is not None:
            events.append(event)

    events.sort(key=event_sort_key)
    return events


def event_sort_key(event: dict[str, Any]) -> tuple[int, int]:
    """Return numeric ordering fields, defaulting malformed values to zero.

    Args:
        event: Raw trace event.
    """
    return _integer(event.get("seq")), _integer(event.get("tsMs"))


def _integer(value: object) -> int:
    """Read an integer trace field, defaulting malformed metadata to zero.

    Args:
        value: Unvalidated trace field.
    """
    return value if isinstance(value, int) else 0


def event_type(event: dict[str, Any]) -> str:
    """Read the event type from current or legacy trace fields.

    Args:
        event: Raw trace event.
    """
    raw = event.get("type")
    if isinstance(raw, str) and raw:
        return raw
    raw = event.get("event")
    if isinstance(raw, str) and raw:
        return raw
    return "unknown"


def event_session_id(event: dict[str, Any]) -> str | None:
    """Read the session identifier from current or legacy trace fields.

    Args:
        event: Raw trace event.
    """
    value = event.get("sessionId")
    if isinstance(value, str) and value:
        return value
    value = event.get("session_id")
    if isinstance(value, str) and value:
        return value
    ctx = event.get("ctx")
    if isinstance(ctx, dict):
        value = ctx.get("session_id")
        if isinstance(value, str) and value:
            return value
    return None


def event_turn_number(event: dict[str, Any]) -> int | None:
    """Read the turn number from current or legacy trace fields.

    Args:
        event: Raw trace event.
    """
    value = event.get("turnNumber")
    if isinstance(value, int):
        return value
    ctx = event.get("ctx")
    if isinstance(ctx, dict):
        value = ctx.get("turn_number")
        if isinstance(value, int):
            return value
    return None


def event_turn_id(event: dict[str, Any]) -> str | None:
    """Read the turn identifier from current or legacy trace fields.

    Args:
        event: Raw trace event.
    """
    value = event.get("turnId")
    if isinstance(value, str) and value:
        return value
    ctx = event.get("ctx")
    if isinstance(ctx, dict):
        value = ctx.get("turn_id")
        if isinstance(value, str) and value:
            return value
    return None


def event_artifacts(event: dict[str, Any]) -> list[dict[str, Any]]:
    """Return only artifact objects from the event's artifact list.

    Args:
        event: Raw trace event.
    """
    artifacts = event.get("artifacts")
    if isinstance(artifacts, list):
        return [a for a in artifacts if isinstance(a, dict)]
    return []


def parse_parent_session_id(session_id: str) -> str | None:
    """Remove the final delegation segment to identify a parent session.

    Args:
        session_id: Session identifier containing optional delegation segments.
    """
    parent, separator, _ = session_id.rpartition("::")
    return parent if separator else None


def extract_artifact(artifacts: Iterable[dict[str, Any]], kind: str) -> dict[str, Any] | None:
    """Return the first artifact matching the requested kind.

    Args:
        artifacts: Artifact records attached to a trace event.
        kind: Artifact kind to match.
    """
    for artifact in artifacts:
        if artifact.get("kind") == kind:
            return artifact
    return None


def summarize_event(event: dict[str, Any]) -> dict[str, Any]:
    """Select event fields needed by the replay frontend.

    Args:
        event: Raw trace event.
    """
    return {
        "seq": event.get("seq"),
        "ts_ms": event.get("tsMs"),
        "type": event_type(event),
        "data": event.get("data"),
        "artifacts": event_artifacts(event),
    }


def compile_sessions(events: list[dict[str, Any]]) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]]]:
    """Build session metadata and parent-child links from session lifecycle events.

    Args:
        events: Trace events ordered by sequence and timestamp.
    """
    sessions: dict[str, dict[str, Any]] = {}
    raw_session_nodes: list[dict[str, Any]] = []

    for event in events:
        if event_type(event) != "session_started":
            continue

        session_id = event_session_id(event)
        if not session_id:
            continue

        data = event.get("data") if isinstance(event.get("data"), dict) else {}
        parent_session_id = data.get("parent_session_id")
        if not isinstance(parent_session_id, str):
            parent_session_id = parse_parent_session_id(session_id)

        role = data.get("agent_role") if isinstance(data.get("agent_role"), str) else "unknown"
        status = "running"
        sessions[session_id] = {
            "session_id": session_id,
            "parent_session_id": parent_session_id,
            "agent_role": role,
            "agent_id": data.get("agent_id") if isinstance(data.get("agent_id"), str) else session_id,
            "goal": data.get("goal"),
            "task_id": data.get("task_id"),
            "delegation_call_id": data.get("delegation_call_id") if isinstance(data.get("delegation_call_id"), str) else None,
            "status": status,
            "started_at_ms": event.get("tsMs"),
            "stopped_at_ms": None,
            "children": [],
        }

    for event in events:
        if event_type(event) != "session_stopped":
            continue
        session_id = event_session_id(event)
        if not session_id:
            continue
        if session_id not in sessions:
            sessions[session_id] = {
                "session_id": session_id,
                "parent_session_id": parse_parent_session_id(session_id),
                "agent_role": "unknown",
                "agent_id": session_id,
                "goal": None,
                "task_id": None,
                "delegation_call_id": None,
                "status": "stopped",
                "started_at_ms": None,
                "stopped_at_ms": event.get("tsMs"),
                "children": [],
            }

        data = event.get("data") if isinstance(event.get("data"), dict) else {}
        reason = data.get("reason") if isinstance(data.get("reason"), str) else "stopped"
        sessions[session_id]["status"] = reason
        sessions[session_id]["stopped_at_ms"] = event.get("tsMs")

    for session_id, info in sessions.items():
        parent_id = info.get("parent_session_id")
        if isinstance(parent_id, str) and parent_id in sessions:
            sessions[parent_id]["children"].append(session_id)

    for session_id in sorted(sessions.keys()):
        raw_session_nodes.append(sessions[session_id])

    return sessions, raw_session_nodes


def compile_steps(events: list[dict[str, Any]], sessions: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    """Group events by session and turn, linking screens, tools, and delegated sessions.

    Args:
        events: Trace events ordered by sequence and timestamp.
        sessions: Compiled metadata indexed by session identifier.
    """
    grouped: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)

    for event in events:
        session_id = event_session_id(event)
        turn_number = event_turn_number(event)
        if not session_id or turn_number is None:
            continue
        grouped[(session_id, turn_number)].append(event)

    call_to_step: dict[str, str] = {}
    steps: list[dict[str, Any]] = []

    for key in sorted(grouped.keys(), key=lambda item: (item[0], item[1])):
        session_id, turn_number = key
        turn_events = grouped[key]
        turn_events.sort(key=event_sort_key)

        first = turn_events[0]
        last = turn_events[-1]
        turn_id = next((event_turn_id(e) for e in turn_events if event_turn_id(e)), None)
        step_id = f"{session_id}::turn-{turn_number}"

        screen_pre = None
        llm_req = None
        llm_resp = None
        tool_calls: list[dict[str, Any]] = []
        tool_results: list[dict[str, Any]] = []
        screen_post = None

        for event in turn_events:
            et = event_type(event)
            data = event.get("data") if isinstance(event.get("data"), dict) else {}
            artifacts = event_artifacts(event)

            if et == "screen_captured" and screen_pre is None:
                screen_pre = {
                    "event": summarize_event(event),
                    "screenshot": extract_artifact(artifacts, "screenshot"),
                    "raw_a11y_tree": extract_artifact(artifacts, "raw_a11y_tree"),
                    "sanitized_a11y_tree": extract_artifact(artifacts, "sanitized_a11y_tree"),
                }
            elif et == "llm_request" and llm_req is None:
                llm_req = summarize_event(event)
            elif et == "llm_response" and llm_resp is None:
                llm_resp = summarize_event(event)
            elif et == "tool_call":
                tool_calls.append(summarize_event(event))
                call_id = data.get("id") if isinstance(data.get("id"), str) else None
                if call_id:
                    call_to_step[call_id] = step_id
            elif et == "tool_result":
                tool_results.append(summarize_event(event))
                post_screen_candidate = {
                    "event": summarize_event(event),
                    "screenshot": extract_artifact(artifacts, "screenshot"),
                    "raw_a11y_tree": extract_artifact(artifacts, "raw_a11y_tree"),
                    "sanitized_a11y_tree": extract_artifact(artifacts, "sanitized_a11y_tree"),
                }
                if (
                    post_screen_candidate["screenshot"]
                    or post_screen_candidate["raw_a11y_tree"]
                    or post_screen_candidate["sanitized_a11y_tree"]
                ):
                    screen_post = post_screen_candidate

        session_info = sessions.get(session_id, {})
        step = {
            "step_id": step_id,
            "session_id": session_id,
            "agent_id": session_info.get("agent_id", session_id),
            "agent_role": session_info.get("agent_role", "unknown"),
            "turn_number": turn_number,
            "turn_id": turn_id,
            "seq_start": first.get("seq"),
            "seq_end": last.get("seq"),
            "ts_start_ms": first.get("tsMs"),
            "ts_end_ms": last.get("tsMs"),
            "event_types": [event_type(e) for e in turn_events],
            "world": {
                "pre": screen_pre,
                "post": screen_post,
            },
            "mind": {
                "llm_request": llm_req,
                "llm_response": llm_resp,
            },
            "tool": {
                "calls": tool_calls,
                "results": tool_results,
            },
            "links": {
                "parent_step_id": None,
                "child_session_ids": [],
            },
        }
        steps.append(step)

    # Connect parent step by delegation call id captured in child session start metadata.
    for step in steps:
        session_id = step.get("session_id")
        if not isinstance(session_id, str):
            continue
        session_info = sessions.get(session_id)
        if not isinstance(session_info, dict):
            continue
        delegation_call_id = session_info.get("delegation_call_id")
        if isinstance(delegation_call_id, str) and delegation_call_id in call_to_step:
            parent_step_id = call_to_step[delegation_call_id]
            step["links"]["parent_step_id"] = parent_step_id

    step_index = {step["step_id"]: step for step in steps if isinstance(step.get("step_id"), str)}
    for step in steps:
        parent_step_id = step.get("links", {}).get("parent_step_id")
        if not isinstance(parent_step_id, str):
            continue
        parent_step = step_index.get(parent_step_id)
        if not parent_step:
            continue
        child_session_id = step.get("session_id")
        children = parent_step["links"].setdefault("child_session_ids", [])
        if isinstance(child_session_id, str) and child_session_id not in children:
            children.append(child_session_id)

    steps.sort(key=lambda step: (_integer(step.get("ts_start_ms")), str(step.get("step_id"))))
    return steps


def write_json(path: Path, payload: Any) -> None:
    """Write a human-readable JSON artifact.

    Args:
        path: File path to read or write.
        payload: JSON-compatible record to validate or serialize.
    """
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def write_jsonl(path: Path, rows: Iterable[Any]) -> None:
    """Write replay rows as newline-delimited JSON objects.

    Args:
        path: File path to read or write.
        rows: Records to write to the output file.
    """
    lines = [json.dumps(row, ensure_ascii=False) for row in rows]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def main() -> int:
    """Compile raw trace events into the replay frontend's derived indexes."""
    args = parse_args()
    trace_dir = Path(args.trace_dir).expanduser().resolve()
    trace_file = trace_dir / "trace.jsonl"

    if not trace_file.exists():
        raise SystemExit(f"trace.jsonl not found: {trace_file}")

    events = read_events(trace_file)
    sessions, session_nodes = compile_sessions(events)
    steps = compile_steps(events, sessions)

    derived_dir = trace_dir / "derived"
    derived_dir.mkdir(parents=True, exist_ok=True)

    replay_index = {
        "version": 1,
        "trace_file": str(trace_file.name),
        "events": len(events),
        "sessions": len(session_nodes),
        "steps": len(steps),
        "generated_at_ms": time.time_ns() // 1_000_000,
        "files": {
            "agent_tree": "derived/agent_tree.json",
            "steps": "derived/steps.jsonl",
        },
    }

    write_json(derived_dir / "replay_index.json", replay_index)
    write_json(derived_dir / "agent_tree.json", {"sessions": session_nodes})
    write_jsonl(derived_dir / "steps.jsonl", steps)

    print(f"Compiled replay index: {derived_dir}")
    print(f"  events:   {len(events)}")
    print(f"  sessions: {len(session_nodes)}")
    print(f"  steps:    {len(steps)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
