from __future__ import annotations

from dataclasses import asdict, dataclass
from statistics import median
from typing import Any


@dataclass
class ArtifactPaths:
    trace_dir: str | None
    logcat: str | None
    runner_log: str | None


@dataclass
class TaskResult:
    task_name: str
    suite_family: str
    seed: int | None
    goal: str
    run_id: str
    attempt: int
    bridge_status: str
    agent_completion_reason: str | None
    task_status: str | None
    answer: str | None
    scripted_score: float | None
    scripted_success: bool
    duration_sec: float
    turns_executed: int
    tool_calls: int
    tool_failures: int
    artifact_paths: ArtifactPaths
    exception: str | None

    def to_dict(self) -> dict[str, Any]:
        """Serialize the record and its nested dataclasses for JSON output."""
        return asdict(self)


def summarize_results(results: list[TaskResult]) -> dict[str, Any]:
    """Aggregate success rates, latency, and tool failures across task results.

    Args:
        results: Per-task results to aggregate.
    """
    total = len(results)
    if total == 0:
        return {
            "num_results": 0,
            "scripted_success_rate": 0.0,
            "timeout_rate": 0.0,
            "infra_failure_rate": 0.0,
            "error_rate": 0.0,
            "duration_p50_sec": 0.0,
            "duration_p90_sec": 0.0,
            "goal_claim_precision": None,
            "tool_failure_rate": None,
        }

    scripted_successes = sum(1 for r in results if r.scripted_success)
    timeout_count = sum(1 for r in results if r.bridge_status == "timeout")
    infra_count = sum(1 for r in results if r.bridge_status == "infra_failure")
    error_count = sum(1 for r in results if r.bridge_status == "error")
    durations = sorted(r.duration_sec for r in results)

    claimed_goal = [r for r in results if (r.agent_completion_reason or "").strip().lower().replace("_", "") == "goalachieved"]
    claimed_goal_successes = sum(1 for r in claimed_goal if r.scripted_success)

    total_tool_calls = sum(r.tool_calls for r in results)
    total_tool_failures = sum(r.tool_failures for r in results)

    return {
        "num_results": total,
        "scripted_success_rate": scripted_successes / total,
        "timeout_rate": timeout_count / total,
        "infra_failure_rate": infra_count / total,
        "error_rate": error_count / total,
        "duration_p50_sec": _percentile(durations, 50),
        "duration_p90_sec": _percentile(durations, 90),
        "goal_claim_precision": (claimed_goal_successes / len(claimed_goal) if claimed_goal else None),
        "tool_failure_rate": (total_tool_failures / total_tool_calls if total_tool_calls > 0 else None),
    }


def _percentile(sorted_values: list[float], p: int) -> float:
    """Read a percentile from sorted durations, using the median for p50.

    Args:
        sorted_values: Values in ascending order.
        p: Requested percentile from zero to one hundred.
    """
    if not sorted_values:
        return 0.0
    if p == 50:
        return float(median(sorted_values))
    idx = int(round((p / 100.0) * (len(sorted_values) - 1)))
    idx = max(0, min(idx, len(sorted_values) - 1))
    return float(sorted_values[idx])


def task_result_from_dict(row: dict[str, Any]) -> TaskResult:
    """Deserialize a saved result, applying defaults for older run records.

    Args:
        row: Per-task result loaded from JSONL.

    Returns:
        Result with typed counters and nested artifact paths.
    """
    artifact_paths = row.get("artifact_paths") or {}
    return TaskResult(
        task_name=row["task_name"],
        suite_family=row["suite_family"],
        seed=row.get("seed"),
        goal=row["goal"],
        run_id=row["run_id"],
        attempt=int(row.get("attempt", 0)),
        bridge_status=row["bridge_status"],
        agent_completion_reason=row.get("agent_completion_reason"),
        task_status=row.get("task_status"),
        answer=row.get("answer"),
        scripted_score=row.get("scripted_score"),
        scripted_success=bool(row.get("scripted_success", False)),
        duration_sec=float(row.get("duration_sec", 0.0)),
        turns_executed=int(row.get("turns_executed", 0)),
        tool_calls=int(row.get("tool_calls", 0)),
        tool_failures=int(row.get("tool_failures", 0)),
        artifact_paths=ArtifactPaths(
            trace_dir=artifact_paths.get("trace_dir"),
            logcat=artifact_paths.get("logcat"),
            runner_log=artifact_paths.get("runner_log"),
        ),
        exception=row.get("exception"),
    )
