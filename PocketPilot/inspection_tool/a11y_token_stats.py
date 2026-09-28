#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class TokenStats:
    step_id: str
    turn_number: int
    role: str
    raw_tokens: int | None
    sanitized_tokens: int | None
    raw_chars: int | None
    sanitized_chars: int | None
    raw_path: str
    sanitized_path: str


class Tokenizer:
    def __init__(self, model: str | None, encoding: str | None) -> None:
        self._name = "heuristic"
        self._encode = None
        self._init_tiktoken(model, encoding)

    def _init_tiktoken(self, model: str | None, encoding: str | None) -> None:
        """Select a supported tokenizer, retaining the character heuristic if none loads.

        Args:
            model: Preferred tokenizer model name.
            encoding: Explicit tokenizer encoding name.
        """
        try:
            import tiktoken  # type: ignore
        except Exception:
            return

        if encoding:
            try:
                enc = tiktoken.get_encoding(encoding)
                self._name = f"tiktoken:{encoding}"
                self._encode = enc.encode
                return
            except Exception:
                pass

        if model:
            try:
                enc = tiktoken.encoding_for_model(model)
                self._name = f"tiktoken:{enc.name}"
                self._encode = enc.encode
                return
            except Exception:
                pass

        for fallback in ("o200k_base", "cl100k_base"):
            try:
                enc = tiktoken.get_encoding(fallback)
                self._name = f"tiktoken:{enc.name}"
                self._encode = enc.encode
                return
            except Exception:
                continue

    @property
    def name(self) -> str:
        """Return the selected tokenizer name for reporting."""
        return self._name

    def count(self, text: str) -> int:
        """Count encoded tokens or estimate one token per four characters.

        Args:
            text: Text to count or process.
        """
        if self._encode is None:
            return int(len(text) * 0.25)
        return len(self._encode(text))


def parse_args() -> argparse.Namespace:
    """Parse command-line options for this tool."""
    parser = argparse.ArgumentParser(description="Compute a11y tree token stats")
    parser.add_argument("--run", help="Path to debug-output/run_xxx (defaults to latest)")
    parser.add_argument("--root", default=".", help="Project root (default: current directory)")
    parser.add_argument("--model", help="Model name for tokenizer (tiktoken, optional)")
    parser.add_argument("--encoding", help="Tokenizer encoding (tiktoken, optional)")
    parser.add_argument("--csv", help="Optional CSV output path")
    return parser.parse_args()


def find_latest_run(debug_root: Path) -> Path:
    """Find the newest debug run containing a raw trace.

    Args:
        debug_root: Root directory containing debug runs.
    """
    runs = [p for p in debug_root.glob("run_*") if p.is_dir()]
    if not runs:
        raise FileNotFoundError(f"No run_* directories under {debug_root}")
    runs.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    for run_dir in runs:
        if (run_dir / "trace" / "trace.jsonl").exists():
            return run_dir
    raise FileNotFoundError(f"No run_* directories with trace.jsonl under {debug_root}")


def load_steps(path: Path) -> list[dict[str, Any]]:
    """Read compiled replay steps from a JSONL file.

    Args:
        path: File path to read or write.
    """
    steps: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        steps.append(json.loads(line))
    return steps


def artifact_path(artifacts: Iterable[dict[str, Any]], kind: str, trace_dir: Path) -> Path | None:
    """Resolve the first matching artifact path relative to its trace directory.

    Args:
        artifacts: Artifact records attached to a trace event.
        kind: Artifact kind to match.
        trace_dir: Directory containing the raw trace and its artifacts.
    """
    for artifact in artifacts:
        if artifact.get("kind") == kind:
            raw_path = artifact.get("path")
            if isinstance(raw_path, str):
                return trace_dir / raw_path
    return None


def read_text(path: Path | None) -> str | None:
    """Read optional artifact text when the file exists.

    Args:
        path: File path to read or write.
    """
    if path is None or not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def collect_stats(run_dir: Path, tokenizer: Tokenizer) -> list[TokenStats]:
    """Measure raw and sanitized accessibility-tree sizes for each replay step.

    Args:
        run_dir: Directory containing this run's artifacts and summaries.
        tokenizer: Tokenizer or heuristic used for counting.
    """
    trace_dir = run_dir / "trace"
    steps_path = trace_dir / "derived" / "steps.jsonl"
    if not steps_path.exists():
        raise FileNotFoundError(f"Missing steps.jsonl at {steps_path}")

    steps = load_steps(steps_path)
    stats: list[TokenStats] = []

    for step in steps:
        # a11y tree artifacts are in world.pre, not mind.llm_request
        world = step.get("world") or {}
        pre = world.get("pre") or {}

        raw_artifact = pre.get("raw_a11y_tree") or {}
        sanitized_artifact = pre.get("sanitized_a11y_tree") or {}

        raw_rel = raw_artifact.get("path")
        sanitized_rel = sanitized_artifact.get("path")

        raw_path = trace_dir / raw_rel if raw_rel else None
        sanitized_path = trace_dir / sanitized_rel if sanitized_rel else None

        raw_text = read_text(raw_path)
        sanitized_text = read_text(sanitized_path)

        raw_tokens = tokenizer.count(raw_text) if raw_text is not None else None
        sanitized_tokens = tokenizer.count(sanitized_text) if sanitized_text is not None else None

        stats.append(
            TokenStats(
                step_id=step.get("step_id", "(missing)"),
                turn_number=step.get("turn_number", -1),
                role=step.get("agent_role", "unknown"),
                raw_tokens=raw_tokens,
                sanitized_tokens=sanitized_tokens,
                raw_chars=len(raw_text) if raw_text is not None else None,
                sanitized_chars=len(sanitized_text) if sanitized_text is not None else None,
                raw_path=str(raw_path.relative_to(run_dir)) if raw_path else "(missing)",
                sanitized_path=str(sanitized_path.relative_to(run_dir)) if sanitized_path else "(missing)",
            )
        )

    return stats


def print_table(stats: list[TokenStats]) -> None:
    """Print aligned per-step accessibility token statistics.

    Args:
        stats: Per-step accessibility token statistics.
    """
    headers = [
        "turn",
        "role",
        "raw_tokens",
        "san_tokens",
        "delta",
        "ratio",
        "raw_chars",
        "san_chars",
    ]
    rows: list[list[str]] = []

    for stat in stats:
        if stat.raw_tokens is None or stat.sanitized_tokens is None:
            delta = ""
            ratio = ""
        else:
            delta = str(stat.raw_tokens - stat.sanitized_tokens)
            ratio = f"{(stat.sanitized_tokens / stat.raw_tokens):.2f}" if stat.raw_tokens else "0.00"
        rows.append(
            [
                str(stat.turn_number),
                stat.role,
                "" if stat.raw_tokens is None else str(stat.raw_tokens),
                "" if stat.sanitized_tokens is None else str(stat.sanitized_tokens),
                delta,
                ratio,
                "" if stat.raw_chars is None else str(stat.raw_chars),
                "" if stat.sanitized_chars is None else str(stat.sanitized_chars),
            ]
        )

    widths = [len(h) for h in headers]
    for row in rows:
        for idx, cell in enumerate(row):
            widths[idx] = max(widths[idx], len(cell))

    def fmt_row(row: list[str]) -> str:
        """Pad table cells to the previously calculated column widths.

        Args:
            row: Record to serialize or render.
        """
        return "  ".join(cell.ljust(widths[idx]) for idx, cell in enumerate(row))

    print(fmt_row(headers))
    print("  ".join("-" * w for w in widths))
    for row in rows:
        print(fmt_row(row))


def summarize(stats: list[TokenStats]) -> dict[str, int | float]:
    """Aggregate raw and sanitized token counts across available screens.

    Args:
        stats: Per-step accessibility token statistics.
    """
    raw = [s.raw_tokens for s in stats if s.raw_tokens is not None]
    san = [s.sanitized_tokens for s in stats if s.sanitized_tokens is not None]
    if not raw or not san:
        return {}
    raw_total = sum(raw)
    san_total = sum(san)
    avg_raw = raw_total / len(raw)
    avg_san = san_total / len(san)
    ratio = san_total / raw_total if raw_total else 0.0
    return {
        "screens": len(raw),
        "raw_total": raw_total,
        "san_total": san_total,
        "avg_raw": avg_raw,
        "avg_san": avg_san,
        "ratio": ratio,
    }


def write_csv(stats: list[TokenStats], path: Path) -> None:
    """Write per-step token statistics to a CSV file.

    Args:
        stats: Per-step accessibility token statistics.
        path: File path to read or write.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "step_id",
                "turn_number",
                "role",
                "raw_tokens",
                "sanitized_tokens",
                "raw_chars",
                "sanitized_chars",
                "raw_path",
                "sanitized_path",
            ]
        )
        for stat in stats:
            writer.writerow(
                [
                    stat.step_id,
                    stat.turn_number,
                    stat.role,
                    stat.raw_tokens,
                    stat.sanitized_tokens,
                    stat.raw_chars,
                    stat.sanitized_chars,
                    stat.raw_path,
                    stat.sanitized_path,
                ]
            )


def main() -> int:
    """Print accessibility-tree token statistics and optionally export CSV."""
    args = parse_args()
    root = Path(args.root).resolve()
    debug_root = root / "debug-output"

    if args.run:
        run_dir = Path(args.run)
        if not run_dir.is_absolute():
            run_dir = root / run_dir
    else:
        run_dir = find_latest_run(debug_root)

    tokenizer = Tokenizer(model=args.model, encoding=args.encoding)
    stats = collect_stats(run_dir, tokenizer)

    print(f"Run: {run_dir.name}")
    print(f"Tokenizer: {tokenizer.name}")
    print()

    print_table(stats)

    summary = summarize(stats)
    if summary:
        print()
        print("Summary")
        print(f"screens: {summary['screens']}")
        print(f"raw_total: {summary['raw_total']}")
        print(f"san_total: {summary['san_total']}")
        print(f"avg_raw: {summary['avg_raw']:.2f}")
        print(f"avg_san: {summary['avg_san']:.2f}")
        print(f"san/raw ratio: {summary['ratio']:.2f}")

    if args.csv:
        write_csv(stats, Path(args.csv))
        print()
        print(f"Wrote CSV: {args.csv}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
