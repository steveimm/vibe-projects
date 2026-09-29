from __future__ import annotations

import argparse
import copy
import json
import logging
import os
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import yaml

from eval.aw_bridge.native_agent_bridge import BridgeConfig, NativeAgentBridge
from eval.aw_bridge.result_schema import TaskResult, summarize_results
from eval.aw_bridge.runner_execution import (
    resolve_task_bridge_config,
    run_one_task_instance,
)
from eval.aw_bridge.runner_preflight import (
    create_env,
    resolve_snapshot_policy,
    run_android_world_connectivity_preflight,
    run_preflight_checks,
    should_run_emulator_setup_retry,
)
from eval.aw_bridge.task_loader import (
    build_task_instances,
    ensure_android_world_importable,
    resolve_selected_tasks,
)


@dataclass
class RunnerConfig:
    suite_family: str
    output_root: str
    task_random_seed: int
    n_task_combinations: int
    use_identical_params: bool
    skip_unavailable_tasks: bool
    auto_install_missing_task_apps: bool
    perform_bridge_setup: bool
    retry_infra_failures: int
    snapshot_policy: str
    adb_serial: str | None
    reference_root: str
    console_port: int
    grpc_port: int
    adb_path: str | None
    perform_emulator_setup: bool
    freeze_datetime: bool
    auto_start_emulator: bool
    emulator_avd_name: str
    emulator_binary_path: str | None
    emulator_boot_timeout_sec: int
    bridge: BridgeConfig
    task_overrides: dict[str, dict[str, Any]]


_SERVER_ENV_NAMES = ("POCKETPILOT_SERVER_URL", "POCKETPILOT_MODEL_ID", "POCKETPILOT_API_KEY")
_DEFAULT_CONFIG_PATH = Path("eval/config/default.yaml")


def main() -> None:
    """Run the selected benchmark tasks and write results with aggregate metrics."""
    args = _parse_args()
    workspace_root = Path(__file__).resolve().parents[2]
    config = load_config(workspace_root, args)

    server = _load_server_settings(workspace_root)
    config.bridge.server_base_url = server.get("POCKETPILOT_SERVER_URL", config.bridge.server_base_url)
    config.bridge.main_model = server.get("POCKETPILOT_MODEL_ID", config.bridge.main_model)
    config.bridge.api_key = server.get("POCKETPILOT_API_KEY")
    _validate_server_settings(config)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = (workspace_root / config.output_root / timestamp).resolve()
    artifact_root = run_dir / "artifacts"
    artifact_root.mkdir(parents=True, exist_ok=True)
    runner_log = run_dir / "runner.log"
    _setup_logging(runner_log)

    logging.info("Run directory: %s", run_dir)
    logging.info("Config: %s", _safe_config_for_logging(config))

    ensure_android_world_importable(workspace_root, config.reference_root)
    run_android_world_connectivity_preflight(config)
    env = create_env(config)

    all_attempt_results: list[TaskResult] = []
    final_results: list[TaskResult] = []
    per_task_jsonl = run_dir / "per_task.jsonl"

    try:
        selected_tasks = resolve_selected_tasks(workspace_root, args.tasks, args.tasks_file)
        task_instances = build_task_instances(
            suite_family=config.suite_family,
            n_task_combinations=config.n_task_combinations,
            task_random_seed=config.task_random_seed,
            use_identical_params=config.use_identical_params,
            selected_tasks=selected_tasks,
            env=env,
        )
        logging.info("Loaded %d task instances", len(task_instances))

        try:
            task_instances = run_preflight_checks(config, task_instances, env)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            if should_run_emulator_setup_retry(config, exc):
                logging.warning("Preflight failed with recoverable setup issue; retrying once with perform_emulator_setup=true")
                env.close()
                config.perform_emulator_setup = True
                env = create_env(config)
                task_instances = build_task_instances(
                    suite_family=config.suite_family,
                    n_task_combinations=config.n_task_combinations,
                    task_random_seed=config.task_random_seed,
                    use_identical_params=config.use_identical_params,
                    selected_tasks=selected_tasks,
                    env=env,
                )
                logging.info(
                    "Reloaded %d task instances after emulator setup",
                    len(task_instances),
                )
                task_instances = run_preflight_checks(config, task_instances, env)
            else:
                raise

        bridge = NativeAgentBridge(config.bridge)
        for task_idx, task_instance in enumerate(task_instances):
            task_bridge_cfg = resolve_task_bridge_config(config.bridge, task_instance.task_name, config.task_overrides)
            task_bridge = bridge if task_bridge_cfg is config.bridge else NativeAgentBridge(task_bridge_cfg)
            final_result = run_one_task_instance(
                bridge=task_bridge,
                suite_family=config.suite_family,
                task_instance=task_instance,
                task_index=task_idx,
                run_prefix=f"aw_{timestamp}",
                artifact_root=artifact_root,
                runner_log=runner_log,
                max_infra_retries=config.retry_infra_failures,
                env=env,
                per_task_jsonl=per_task_jsonl,
                all_attempt_results=all_attempt_results,
            )
            final_results.append(final_result)
    finally:
        env.close()

    summary = summarize_results(final_results)
    safe_config = _safe_config_for_logging(config)
    summary_payload = {
        "run_timestamp": timestamp,
        "suite_family": config.suite_family,
        "num_task_instances": len(final_results),
        "num_attempts": len(all_attempt_results),
        "config": safe_config,
        "metrics": summary,
    }
    summary_path = run_dir / "summary.json"
    summary_path.write_text(
        json.dumps(summary_payload, ensure_ascii=True, indent=2),
        encoding="utf-8",
    )
    logging.info("Wrote summary: %s", summary_path)
    print(json.dumps(summary_payload["metrics"], ensure_ascii=True, indent=2))


def _resolve_config_path(workspace_root: Path, config_path: str | Path) -> Path:
    """Resolve a configuration path relative to the project root.

    Args:
        workspace_root: Project root used to resolve relative paths.
        config_path: Runner configuration file path.
    """
    return (workspace_root / Path(config_path)).resolve()


def _read_config_mapping(path: Path) -> dict[str, Any]:
    """Load a YAML configuration and reject non-mapping content.

    Args:
        path: File path to read or write.
    """
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(raw, dict):
        raise ValueError(f"Config root must be a mapping: {path}")
    return raw


def _deep_merge_mappings(
    base: dict[str, Any],
    override: dict[str, Any],
) -> dict[str, Any]:
    """Recursively apply overrides without mutating either source mapping.

    Args:
        base: Settings to preserve unless overridden.
        override: Settings to apply over the base mapping.
    """
    merged = copy.deepcopy(base)
    for key, override_value in override.items():
        base_value = merged.get(key)
        if isinstance(base_value, dict) and isinstance(override_value, dict):
            merged[key] = _deep_merge_mappings(base_value, override_value)
        else:
            merged[key] = copy.deepcopy(override_value)
    return merged


def load_config_dict(workspace_root: Path, config_path: str | Path) -> dict[str, Any]:
    """Load ``default.yaml`` and deep-merge any non-default override config on top."""
    default_path = _resolve_config_path(workspace_root, _DEFAULT_CONFIG_PATH)
    requested_path = _resolve_config_path(workspace_root, config_path)
    default_cfg = _read_config_mapping(default_path)
    if requested_path == default_path:
        return default_cfg
    override_cfg = _read_config_mapping(requested_path)
    return _deep_merge_mappings(default_cfg, override_cfg)


def load_config(workspace_root: Path, args: argparse.Namespace) -> RunnerConfig:
    """Load configuration and apply the command-line overrides.

    Args:
        workspace_root: Project root used to resolve relative paths.
        args: Parsed command-line options or command arguments.
    """
    raw = load_config_dict(workspace_root, args.config)

    suite_family = args.suite or raw.get("suite_family", "android_world")
    runner_cfg = raw.get("runner", {})
    aw_cfg = raw.get("android_world", {})
    bridge_cfg = raw.get("bridge", {})

    n_task_combinations = (
        args.n_task_combinations if args.n_task_combinations is not None else int(runner_cfg.get("n_task_combinations", 1))
    )
    task_random_seed = args.task_random_seed if args.task_random_seed is not None else int(runner_cfg.get("task_random_seed", 30))
    snapshot_policy = resolve_snapshot_policy(args.snapshot_policy or runner_cfg.get("snapshot_policy", "auto_repair")).value

    bridge = BridgeConfig(
        package_name=str(bridge_cfg.get("package_name", "id.steveimm.pocketpilot")),
        activity=str(bridge_cfg.get("activity", "id.steveimm.pocketpilot/.app.MainActivity")),
        server_base_url=str(bridge_cfg.get("server_base_url", "")),
        perception_mode=str(bridge_cfg.get("perception_mode", "accessibility_only")),
        platform_mode=str(args.platform_mode or bridge_cfg.get("platform_mode", "accessibility")),
        main_model=str(bridge_cfg.get("main_model", "")),
        max_turns=int(bridge_cfg.get("max_turns", 30)),
        auto_start=bool(bridge_cfg.get("auto_start", True)),
        fresh_session=bool(bridge_cfg.get("fresh_session", True)),
        debug_mode=bool(bridge_cfg.get("debug_mode", False)),
        trace_enabled=bool(bridge_cfg.get("trace_enabled", True)),
        max_wait_seconds=int(bridge_cfg.get("max_wait_seconds", 900)),
        poll_interval_seconds=float(bridge_cfg.get("poll_interval_seconds", 1)),
        adb_serial=_nullable_str(args.adb_serial or runner_cfg.get("adb_serial")),
        stop_agent_after_task=bool(runner_cfg.get("stop_agent_after_task", True)),
        adb_command_timeout_sec=int(runner_cfg.get("adb_command_timeout_sec", 60)),
        adb_pull_timeout_sec=int(runner_cfg.get("adb_pull_timeout_sec", 300)),
        shizuku_apk_path=_nullable_str(bridge_cfg.get("shizuku_apk_path")),
        excluded_tools=str(bridge_cfg.get("excluded_tools", "")),
    )

    return RunnerConfig(
        suite_family=suite_family,
        output_root=str(args.output_root or runner_cfg.get("output_root", "eval/results")),
        task_random_seed=task_random_seed,
        n_task_combinations=n_task_combinations,
        use_identical_params=bool(runner_cfg.get("use_identical_params", False)),
        skip_unavailable_tasks=bool(runner_cfg.get("skip_unavailable_tasks", True)),
        auto_install_missing_task_apps=bool(runner_cfg.get("auto_install_missing_task_apps", True)),
        perform_bridge_setup=bool(runner_cfg.get("perform_bridge_setup", True)),
        retry_infra_failures=int(runner_cfg.get("retry_infra_failures", 1)),
        snapshot_policy=snapshot_policy,
        adb_serial=_nullable_str(args.adb_serial or runner_cfg.get("adb_serial")),
        reference_root=str(aw_cfg.get("reference_root", ".reference/eval/android_world")),
        console_port=int(aw_cfg.get("console_port", 5554)),
        grpc_port=int(aw_cfg.get("grpc_port", 8554)),
        adb_path=_nullable_path_str(aw_cfg.get("adb_path")),
        perform_emulator_setup=bool(aw_cfg.get("perform_emulator_setup", False)),
        freeze_datetime=bool(aw_cfg.get("freeze_datetime", False)),
        auto_start_emulator=bool(aw_cfg.get("auto_start_emulator", True)),
        emulator_avd_name=str(aw_cfg.get("emulator_avd_name", "AndroidWorldAvd")),
        emulator_binary_path=_nullable_path_str(aw_cfg.get("emulator_binary_path")),
        emulator_boot_timeout_sec=int(aw_cfg.get("emulator_boot_timeout_sec", 180)),
        bridge=bridge,
        task_overrides=dict(bridge_cfg.get("task_overrides", {})),
    )


def load_config_from_path(workspace_root: Path, config_path: str | Path) -> RunnerConfig:
    """Load runner configuration using default command-line options.

    Args:
        workspace_root: Project root used to resolve relative paths.
        config_path: Runner configuration file path.
    """
    return load_config(
        workspace_root,
        argparse.Namespace(
            config=str(config_path),
            suite=None,
            tasks=None,
            tasks_file=None,
            n_task_combinations=None,
            task_random_seed=None,
            output_root=None,
            adb_serial=None,
            snapshot_policy=None,
            platform_mode=None,
        ),
    )


def _parse_args() -> argparse.Namespace:
    """Parse command-line options for this tool."""
    parser = argparse.ArgumentParser(description="AndroidWorld bridge runner")
    parser.add_argument("--config", default="eval/config/default.yaml")
    parser.add_argument("--suite", default=None)
    parser.add_argument("--tasks-file", default=None)
    parser.add_argument("--tasks", default=None, help="Comma-separated task names")
    parser.add_argument("--n-task-combinations", type=int, default=None)
    parser.add_argument("--task-random-seed", type=int, default=None)
    parser.add_argument("--output-root", default=None)
    parser.add_argument("--adb-serial", default=None)
    parser.add_argument(
        "--snapshot-policy",
        default=None,
        choices=["strict", "auto_repair", "best_effort", "off"],
    )
    parser.add_argument(
        "--platform-mode",
        default=None,
        choices=["accessibility", "virtual_display"],
        help="Platform mode: accessibility (default) or virtual_display",
    )
    return parser.parse_args()


def _setup_logging(log_path: Path) -> None:
    """Send runner logs to the console and the run log file.

    Args:
        log_path: Destination for runner log records.
    """
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(log_path, encoding="utf-8"),
            logging.StreamHandler(),
        ],
    )


def _nullable_str(value: Any) -> str | None:
    """Normalize an optional value to a nonblank string.

    Args:
        value: Input value to validate or normalize.
    """
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _nullable_path_str(value: Any) -> str | None:
    """Expand an optional path string, preserving missing values.

    Args:
        value: Input value to validate or normalize.
    """
    text = _nullable_str(value)
    if text is None:
        return None
    return os.path.expanduser(os.path.expandvars(text))


def _load_server_settings(workspace_root: Path) -> dict[str, str]:
    """Load the configured server URL, model ID, and optional key from .env and environment."""
    keys: dict[str, str] = {}
    env_file = workspace_root / ".env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            name, _, value = line.partition("=")
            name = name.strip()
            value = value.strip().strip("\"'")
            if name in _SERVER_ENV_NAMES:
                keys[name] = value
    for name in _SERVER_ENV_NAMES:
        val = os.environ.get(name)
        if val is not None:
            keys[name] = val
    return keys


def _validate_server_settings(config: RunnerConfig) -> None:
    """Require an explicit HTTP(S) server and model without requiring authentication.

    Args:
        config: Runner settings for the target device and benchmark.
    """
    parsed = urlparse(config.bridge.server_base_url.strip())
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise RuntimeError("Set POCKETPILOT_SERVER_URL to your server API base URL")
    if parsed.username is not None or parsed.password is not None or parsed.query or parsed.fragment:
        raise RuntimeError("The model server URL must not contain credentials, a query, or a fragment")
    model = config.bridge.main_model.strip()
    if not model or any(character.isspace() for character in model):
        raise RuntimeError("Set POCKETPILOT_MODEL_ID to the exact model ID served by your endpoint")
    config.bridge.main_model = model
    config.bridge.server_base_url = config.bridge.server_base_url.strip().rstrip("/").removesuffix("/chat/completions")


def _safe_config_for_logging(config: RunnerConfig) -> dict[str, Any]:
    """Serialize runner settings with API credentials redacted.

    Args:
        config: Runner settings for the target device and benchmark.
    """
    safe = asdict(config)
    bridge = safe.get("bridge")
    if isinstance(bridge, dict):
        bridge["api_key"] = "***" if bridge.get("api_key") else ""
    return safe


if __name__ == "__main__":
    main()
