from __future__ import annotations

import argparse
import json
from pathlib import Path

from eval.aw_bridge.jsonl_utils import read_jsonl
from eval.aw_bridge.result_schema import summarize_results, task_result_from_dict


def main() -> None:
    """Print aggregate metrics from a saved per-task results file."""
    parser = argparse.ArgumentParser(description="Summarize per_task.jsonl metrics")
    parser.add_argument("--run-dir", required=True, help="Path to eval/results/<timestamp>")
    args = parser.parse_args()

    run_dir = Path(args.run_dir).resolve()
    per_task_path = run_dir / "per_task.jsonl"
    if not per_task_path.exists():
        raise FileNotFoundError(f"Missing per_task.jsonl: {per_task_path}")

    rows = [task_result_from_dict(row) for row in read_jsonl(per_task_path)]
    metrics = summarize_results(rows)
    payload = {
        "run_dir": str(run_dir),
        "num_rows": len(rows),
        "metrics": metrics,
    }
    print(json.dumps(payload, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
