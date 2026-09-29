import json
from pathlib import Path
import tempfile
import unittest

from eval.aw_bridge.trace_parser import empty_trace_result, parse_trace

class TraceParserTest(unittest.TestCase):
    def test_reads_native_final_answer_without_inventing_success(self) -> None:
        """Only final assistant content becomes the evaluation answer."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "answer.txt").write_text("The app is not installed.")
            (root / "summary.json").write_text(json.dumps({"stop_reason": "finished", "turns_executed": 2,
                                                         "tool_calls": 1, "tool_failures": 1}))
            events = [
                {"type": "llm_response", "data": {"is_complete": False},
                 "artifacts": [{"kind": "llm_response_text", "path": "missing.txt"}]},
                {"type": "llm_response", "data": {"is_complete": True},
                 "artifacts": [{"kind": "llm_response_text", "path": "answer.txt"}]},
                {"type": "session_stopped", "artifacts": [{"kind": "run_summary", "path": "summary.json"}]},
            ]
            (root / "trace.jsonl").write_text("\n".join(json.dumps(event) for event in events))
            result = parse_trace(root)
            self.assertEqual(result.answer, "The app is not installed.")
            self.assertEqual(result.completion_reason, "finished")
            self.assertEqual((result.turns_executed, result.tool_calls, result.tool_failures), (2, 1, 1))
            events.append({"type": "session_started"})
            (root / "trace.jsonl").write_text("\n".join(json.dumps(event) for event in events))
            self.assertIsNone(parse_trace(root).answer)

    def test_missing_or_corrupt_trace_has_no_answer(self) -> None:
        """Unreadable traces do not fabricate answers or completion metrics."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(parse_trace(root), empty_trace_result())
            (root / "trace.jsonl").write_text("not json\n{broken\n")
            self.assertEqual(parse_trace(root), empty_trace_result())
