from __future__ import annotations

import re
import time
from dataclasses import dataclass
from pathlib import Path

# SessionCompleted without a reason can be teardown, so wait for the service log.
COMPLETED_PATTERN = re.compile(
    "|".join(
        [
            "AgentSession: Emitted event: TaskCompleted",
            "AgentService: Received event: TaskCompleted",
            "AgentService: Session completed",
            "AgentService: Task completed",
        ]
    )
)
# USER_STOPPED marks teardown of an earlier session, not completion of the current task.
_USER_STOPPED_PATTERN = re.compile(r"reason[=:]\s*USER_STOPPED")
ERROR_PATTERN = re.compile(
    "|".join(
        [
            "AgentSession: Emitted event: SessionError",
            "AgentService: Session error",
            "Fatal error",
            "TurnExecutionPhase: Executing tool: ask_user",
            r"ANR in id\.steveimm\.pocketpilot",
            r"Timeout executing service: ServiceRecord\{[^}]*id\.steveimm\.pocketpilot/.app.AgentService",
        ]
    )
)
REASON_PATTERN = re.compile(r"reason[=:]\s*([A-Za-z_]+)")


@dataclass
class MonitorResult:
    bridge_status: str
    agent_completion_reason: str | None
    matched_line: str | None


class LogcatCompletionMonitor:
    def __init__(self, max_wait_seconds: float, poll_interval_seconds: float) -> None:
        self._max_wait_seconds = max_wait_seconds
        self._poll_interval_seconds = poll_interval_seconds

    def wait(self, logcat_path: Path) -> MonitorResult:
        """Wait for completion or failure, ignoring teardown events from prior sessions.

        Args:
            logcat_path: Growing logcat capture for the current task.
        """
        started_at = time.monotonic()
        cursor = 0

        while True:
            if logcat_path.exists():
                with logcat_path.open("r", encoding="utf-8", errors="replace") as stream:
                    stream.seek(cursor)
                    for line in stream:
                        if COMPLETED_PATTERN.search(line):
                            if _USER_STOPPED_PATTERN.search(line):
                                continue
                            return MonitorResult(
                                bridge_status="completed",
                                agent_completion_reason=_extract_reason(line),
                                matched_line=line.strip(),
                            )
                        if ERROR_PATTERN.search(line):
                            return MonitorResult(
                                bridge_status="error",
                                agent_completion_reason=_extract_reason(line) or _infer_reason(line),
                                matched_line=line.strip(),
                            )
                    cursor = stream.tell()

            if (time.monotonic() - started_at) >= self._max_wait_seconds:
                return MonitorResult(
                    bridge_status="timeout",
                    agent_completion_reason=None,
                    matched_line=None,
                )

            time.sleep(self._poll_interval_seconds)


def _extract_reason(line: str) -> str | None:
    """Extract the explicit completion reason from a log line.

    Args:
        line: Log or JSONL record to inspect.
    """
    match = REASON_PATTERN.search(line)
    if not match:
        return None
    return match.group(1)


def _infer_reason(line: str) -> str | None:
    """Identify blocked user interaction or an agent ANR from an error log.

    Args:
        line: Log or JSONL record to inspect.
    """
    if "Executing tool: ask_user" in line:
        return "ASK_USER_BLOCKED"
    if "ANR in id.steveimm.pocketpilot" in line:
        return "AGENT_ANR"
    if "Timeout executing service: ServiceRecord" in line and "id.steveimm.pocketpilot/.app.AgentService" in line:
        return "AGENT_ANR"
    return None
