from scripts import token_counts


def test_token_report_reads_current_default_agent_prompt() -> None:
    """Detect stale source paths or extraction markers that silently report zero tokens."""
    assert token_counts.AGENT_DEF.is_file()
    counts = token_counts.measure_system_prompt()
    assert counts["chars"] > 0
    assert counts["tokens"] > 0
    assert counts["lines"] > 1

