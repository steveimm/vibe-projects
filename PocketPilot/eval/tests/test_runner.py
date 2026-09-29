from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock
import argparse

from eval.aw_bridge.native_agent_bridge import BridgeConfig
from eval.aw_bridge.runner import (
    RunnerConfig,
    _validate_server_settings,
    _safe_config_for_logging,
    load_config,
    load_config_from_path,
)
from eval.aw_bridge.runner_preflight import (
    TASK_REQUIRED_PACKAGES,
    run_adb,
    run_adb_global,
    run_android_world_connectivity_preflight,
    wait_for_emulator_stability,
)


def _bridge_config() -> BridgeConfig:
    return BridgeConfig(
        package_name="id.steveimm.pocketpilot",
        activity="id.steveimm.pocketpilot/.app.MainActivity",
        server_base_url="http://localhost:8000/v1",
        platform_mode="accessibility",
        main_model="minimax-m2.5",
        max_turns=30,
        auto_start=True,
        fresh_session=True,
        debug_mode=False,
        trace_enabled=True,
        max_wait_seconds=900,
        poll_interval_seconds=1.0,
        adb_serial=None,
        stop_agent_after_task=True,
        adb_command_timeout_sec=60,
        adb_pull_timeout_sec=300,
        api_key=None,
        shizuku_apk_path=None,
        excluded_tools="",
    )


def _runner_config(**overrides: object) -> RunnerConfig:
    config = RunnerConfig(
        suite_family="android_world",
        output_root="eval/results",
        task_random_seed=30,
        n_task_combinations=1,
        use_identical_params=False,
        skip_unavailable_tasks=True,
        auto_install_missing_task_apps=False,
        perform_bridge_setup=True,
        retry_infra_failures=1,
        snapshot_policy="auto_repair",
        adb_serial=None,
        reference_root=".reference/eval/android_world",
        console_port=5554,
        grpc_port=8554,
        adb_path=None,
        perform_emulator_setup=False,
        freeze_datetime=False,
        auto_start_emulator=False,
        emulator_avd_name="AndroidWorldAvd",
        emulator_binary_path=None,
        emulator_boot_timeout_sec=180,
        bridge=_bridge_config(),
        task_overrides={},
    )
    for name, value in overrides.items():
        setattr(config, name, value)
    if "adb_serial" in overrides:
        config.bridge.adb_serial = config.adb_serial
    return config


class RunnerAdbTest(unittest.TestCase):
    def test_load_default_config_disables_user_questions_for_eval(self) -> None:
        workspace_root = Path(__file__).resolve().parents[2]
        config = load_config_from_path(workspace_root, "eval/config/default.yaml")

        self.assertIn("ask_user", config.bridge.excluded_tools)

    def test_run_adb_uses_default_timeout(self) -> None:
        config = _runner_config(adb_serial="emulator-5554")
        completed = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="", stderr="")
        with mock.patch("eval.aw_bridge.runner_preflight.subprocess.run", return_value=completed) as run_mock:
            run_adb(config, ["devices"], check=False, capture_output=True)

        self.assertEqual(run_mock.call_args[1]["timeout"], 60.0)

    def test_run_adb_honors_timeout_override(self) -> None:
        config = _runner_config(adb_serial="emulator-5554")
        completed = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="", stderr="")
        with mock.patch("eval.aw_bridge.runner_preflight.subprocess.run", return_value=completed) as run_mock:
            run_adb(
                config,
                ["wait-for-device"],
                check=False,
                capture_output=True,
                timeout_sec=222,
            )

        self.assertEqual(run_mock.call_args[1]["timeout"], 222.0)

    def test_run_adb_uses_configured_binary(self) -> None:
        config = _runner_config(adb_serial="emulator-5554", adb_path="/opt/android/platform-tools/adb")
        completed = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="", stderr="")
        with mock.patch("eval.aw_bridge.runner_preflight.subprocess.run", return_value=completed) as run_mock:
            run_adb(config, ["devices"], check=False, capture_output=True)

        self.assertEqual(
            run_mock.call_args[0][0],
            ["/opt/android/platform-tools/adb", "-s", "emulator-5554", "devices"],
        )

    def test_run_adb_global_uses_configured_binary(self) -> None:
        config = _runner_config(adb_path="/opt/android/platform-tools/adb")
        completed = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="", stderr="")
        with mock.patch("eval.aw_bridge.runner_preflight.subprocess.run", return_value=completed) as run_mock:
            run_adb_global(config, ["start-server"], check=False, capture_output=True)

        self.assertEqual(
            run_mock.call_args[0][0],
            ["/opt/android/platform-tools/adb", "start-server"],
        )


class RunnerConnectivityPreflightTest(unittest.TestCase):
    def test_rejects_serial_console_port_mismatch(self) -> None:
        config = _runner_config(adb_serial="emulator-5556", console_port=5554, auto_start_emulator=False)
        completed = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="", stderr="")
        with mock.patch("eval.aw_bridge.runner_preflight.run_adb_global", return_value=completed), mock.patch(
            "eval.aw_bridge.runner_preflight.is_expected_emulator_online", return_value=True
        ), mock.patch(
            "eval.aw_bridge.runner_preflight.is_local_tcp_port_open", return_value=True
        ), mock.patch(
            "eval.aw_bridge.runner_preflight.wait_for_emulator_stability"
        ) as wait_mock:
            with self.assertRaisesRegex(RuntimeError, "must match console_port mapping"):
                run_android_world_connectivity_preflight(config)

        wait_mock.assert_not_called()


class RunnerEmulatorStabilityTest(unittest.TestCase):
    def test_wait_for_device_uses_boot_timeout(self) -> None:
        config = _runner_config(adb_serial="emulator-5554", emulator_boot_timeout_sec=180)
        ok = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="ok", stderr="")
        boot_done = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="1\n", stderr="")
        whoami = subprocess.CompletedProcess(args=["adb"], returncode=0, stdout="shell\n", stderr="")

        with mock.patch("eval.aw_bridge.runner_preflight.run_adb", return_value=ok) as run_adb_mock, mock.patch(
            "eval.aw_bridge.runner_preflight.is_expected_emulator_online", return_value=True
        ), mock.patch(
            "eval.aw_bridge.runner_preflight.run_adb_shell", side_effect=[boot_done, whoami]
        ), mock.patch("eval.aw_bridge.runner_preflight.time.sleep"):
            wait_for_emulator_stability(config, "emulator-5554")

        first_call = run_adb_mock.call_args_list[0]
        self.assertEqual(first_call[1]["timeout_sec"], 180)


class RunnerServerValidationTest(unittest.TestCase):
    def test_keyless_server_is_valid(self) -> None:
        config = _runner_config()
        config.bridge.server_base_url = "http://localhost:8000/v1/chat/completions"
        config.bridge.main_model = "local-model"
        _validate_server_settings(config)
        self.assertEqual(config.bridge.server_base_url, "http://localhost:8000/v1")

    def test_missing_server_never_uses_a_cloud_default(self) -> None:
        config = _runner_config()
        config.bridge.server_base_url = ""
        with self.assertRaisesRegex(RuntimeError, "POCKETPILOT_SERVER_URL"):
            _validate_server_settings(config)

    def test_url_credentials_are_rejected_without_echoing_them(self) -> None:
        config = _runner_config()
        config.bridge.server_base_url = "http://user:SECRET@local:8000/v1"
        with self.assertRaises(RuntimeError) as error:
            _validate_server_settings(config)
        self.assertNotIn("SECRET", str(error.exception))

    def test_server_key_is_redacted_in_diagnostic_configuration(self) -> None:
        config = _runner_config()
        config.bridge.api_key = "private-token"
        self.assertNotIn("private-token", json.dumps(_safe_config_for_logging(config)))


class RunnerTaskPackageMapTest(unittest.TestCase):
    def test_includes_recipe_and_sms_requirements(self) -> None:
        self.assertEqual(
            TASK_REQUIRED_PACKAGES.get("RecipeAddSingleRecipe"),
            ("com.flauschcode.broccoli",),
        )
        self.assertEqual(
            TASK_REQUIRED_PACKAGES.get("SimpleSmsSend"),
            ("com.simplemobiletools.smsmessenger",),
        )


class RunnerConfigLoadingTest(unittest.TestCase):
    def _write_default_config(
        self,
        root: Path,
        perform_bridge_setup: str | None = None,
        adb_path: str | None = None,
    ) -> Path:
        config_dir = root / "eval" / "config"
        config_dir.mkdir(parents=True, exist_ok=True)
        perform_bridge_line = (
            f"  perform_bridge_setup: {perform_bridge_setup}\n"
            if perform_bridge_setup is not None
            else ""
        )
        adb_path_line = f"  adb_path: {adb_path}\n" if adb_path is not None else ""
        config_path = config_dir / "default.yaml"
        config_path.write_text(
            (
                "suite_family: android_world\n"
                "runner:\n"
                "  output_root: eval/results\n"
                "  task_random_seed: 30\n"
                "  n_task_combinations: 1\n"
                "  use_identical_params: false\n"
                "  skip_unavailable_tasks: true\n"
                "  auto_install_missing_task_apps: true\n"
                f"{perform_bridge_line}"
                "android_world:\n"
                "  console_port: 5554\n"
                "  grpc_port: 8554\n"
                f"{adb_path_line}"
                "  auto_start_emulator: false\n"
                "bridge:\n"
                "  server_base_url: http://localhost:8000/v1\n"
                "  package_name: id.steveimm.pocketpilot\n"
                "  activity: id.steveimm.pocketpilot/.app.MainActivity\n"
                "  approval_mode: SMART\n"
                "  platform_mode: accessibility\n"
                "  main_model: minimax-m2.5\n"
                "  max_turns: 30\n"
                "  auto_start: true\n"
                "  fresh_session: true\n"
                "  debug_mode: false\n"
                "  trace_enabled: true\n"
                "  max_wait_seconds: 900\n"
                "  poll_interval_seconds: 1\n"
                "  task_overrides:\n"
                "    BrowserDraw:\n"
                "      approval_mode: AUTO_APPROVE\n"
            ),
            encoding="utf-8",
        )
        return config_path

    def _write_overlay_config(self, root: Path, body: str = "") -> Path:
        config_dir = root / "eval" / "config"
        config_dir.mkdir(parents=True, exist_ok=True)
        config_path = config_dir / "test.yaml"
        config_path.write_text(body, encoding="utf-8")
        return config_path

    def _args_for(self, config_path: Path) -> argparse.Namespace:
        return argparse.Namespace(
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
        )

    def test_perform_bridge_setup_defaults_true(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_default_config(root)
            config_path = self._write_overlay_config(root)
            config = load_config(root, self._args_for(config_path))
        self.assertTrue(config.perform_bridge_setup)

    def test_perform_bridge_setup_can_be_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_default_config(root)
            config_path = self._write_overlay_config(
                root,
                "runner:\n"
                "  perform_bridge_setup: false\n",
            )
            config = load_config(root, self._args_for(config_path))
        self.assertFalse(config.perform_bridge_setup)

    def test_load_config_from_path_uses_same_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_default_config(root)
            config_path = self._write_overlay_config(root)
            config = load_config_from_path(root, config_path)
        self.assertTrue(config.perform_bridge_setup)

    def test_load_config_expands_adb_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with mock.patch.dict("os.environ", {"HOME": "/tmp/remote-home"}, clear=False):
                self._write_default_config(root)
                config_path = self._write_overlay_config(
                    root,
                    "android_world:\n"
                    "  adb_path: ~/android-sdk/platform-tools/adb\n",
                )
                config = load_config(root, self._args_for(config_path))
        self.assertEqual(config.adb_path, "/tmp/remote-home/android-sdk/platform-tools/adb")

    def test_overlay_config_deep_merges_default_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_default_config(root, perform_bridge_setup="true", adb_path="/usr/local/bin/adb")
            config_path = self._write_overlay_config(
                root,
                (
                    "runner:\n"
                    "  perform_bridge_setup: false\n"
                    "bridge:\n"
                    "  main_model: gpt-5.4\n"
                    "  task_overrides:\n"
                    "    BrowserDraw:\n"
                    "      max_turns: 60\n"
                    "    BrowserMaze:\n"
                    "      approval_mode: AUTO_APPROVE\n"
                ),
            )
            config = load_config(root, self._args_for(config_path))

        self.assertFalse(config.perform_bridge_setup)
        self.assertEqual(config.adb_path, "/usr/local/bin/adb")
        self.assertEqual(config.bridge.main_model, "gpt-5.4")
        self.assertEqual(
            config.task_overrides["BrowserDraw"],
            {"approval_mode": "AUTO_APPROVE", "max_turns": 60},
        )
        self.assertEqual(
            config.task_overrides["BrowserMaze"],
            {"approval_mode": "AUTO_APPROVE"},
        )


if __name__ == "__main__":
    unittest.main()
