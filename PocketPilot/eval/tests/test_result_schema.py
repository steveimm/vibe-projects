from __future__ import annotations

import unittest

from eval.aw_bridge.result_schema import ArtifactPaths, TaskResult, summarize_results


def _result(
    reason: str | None,
    success: bool,
    tool_calls: int,
    tool_failures: int,
    duration: float,
) -> TaskResult:
    return TaskResult(
        task_name="DummyTask",
        suite_family="android_world",
        seed=1,
        goal="dummy",
        run_id="run_1",
        attempt=0,
        bridge_status="completed",
        agent_completion_reason=reason,
        task_status="success" if success else "failure",
        answer=None,
        scripted_score=1.0 if success else 0.0,
        scripted_success=success,
        duration_sec=duration,
        turns_executed=1,
        tool_calls=tool_calls,
        tool_failures=tool_failures,
        artifact_paths=ArtifactPaths(trace_dir=None, logcat=None, runner_log=None),
        exception=None,
    )


class ResultSchemaTest(unittest.TestCase):
    def test_finished_tasks_are_scored_only_by_verified_results(self) -> None:
        """Native completion does not imply scripted success."""
        metrics = summarize_results([_result("finished", True, 2, 0, 10), _result("finished", False, 2, 1, 12)])
        self.assertEqual(metrics["scripted_success_rate"], 0.5)
        self.assertEqual(metrics["tool_failure_rate"], 0.25)

    def test_empty_results(self) -> None:
        metrics = summarize_results([])
        self.assertEqual(metrics["num_results"], 0)
        self.assertAlmostEqual(metrics["scripted_success_rate"], 0.0)


if __name__ == "__main__":
    unittest.main()
