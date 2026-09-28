from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class TaskInstance:
    task_name: str
    instance_index: int
    seed: int | None
    goal: str
    task: Any


def ensure_android_world_importable(workspace_root: Path, reference_root: str) -> None:
    """Make the checked-out AndroidWorld reference importable.

    Args:
        workspace_root: Project root used to resolve relative paths.
        reference_root: Path to the AndroidWorld checkout relative to the project root.
    """
    aw_root = (workspace_root / reference_root).resolve()
    if not aw_root.exists():
        raise FileNotFoundError(f"AndroidWorld reference path not found: {aw_root}")
    path_value = str(aw_root)
    if path_value not in sys.path:
        sys.path.insert(0, path_value)


def load_task_names_from_file(path: Path) -> list[str]:
    """Read task names, ignoring blank lines and full-line comments.

    Args:
        path: File path to read or write.
    """
    lines = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        lines.append(stripped)
    return lines


def resolve_selected_tasks(workspace_root: Path, tasks: str | None, tasks_file: str | None) -> list[str] | None:
    """Resolve task names from inline options or a task-list file.

    Args:
        workspace_root: Root used to resolve a relative task-list path.
        tasks: Comma-separated names, taking precedence over the file option.
        tasks_file: Optional file containing task names and comments.

    Returns:
        Selected names, or no filter when neither option is supplied.

    Raises:
        FileNotFoundError: The requested task-list file does not exist.
    """
    if tasks:
        return [name.strip() for name in tasks.split(",") if name.strip()]
    if tasks_file:
        path = (workspace_root / tasks_file).resolve()
        if not path.exists():
            raise FileNotFoundError(f"Tasks file not found: {path}")
        return load_task_names_from_file(path)
    return None


def build_task_instances(
    suite_family: str,
    n_task_combinations: int,
    task_random_seed: int,
    use_identical_params: bool,
    selected_tasks: list[str] | None,
    env: Any,
) -> list[TaskInstance]:
    """Build reproducible AndroidWorld task instances for the selected suite.

    Args:
        suite_family: AndroidWorld task registry family.
        n_task_combinations: Parameter combinations to generate per task.
        task_random_seed: Seed controlling task selection and parameters.
        use_identical_params: Whether repeated tasks reuse identical parameters.
        selected_tasks: Task-name filter, or all tasks when absent.
        env: AndroidWorld device environment.
    """
    from android_world import (
        registry,  # type: ignore
        suite_utils,  # type: ignore
    )

    task_registry = registry.TaskRegistry()
    family_registry = task_registry.get_registry(family=suite_family)
    suite = suite_utils.create_suite(
        family_registry,
        n_task_combinations=n_task_combinations,
        seed=task_random_seed,
        tasks=selected_tasks,
        use_identical_params=use_identical_params,
        env=env,
    )

    items: list[TaskInstance] = []
    for task_name, instances in suite.items():
        for idx, task in enumerate(instances):
            seed = task.params.get("seed") if hasattr(task, "params") else None
            items.append(
                TaskInstance(
                    task_name=task_name,
                    instance_index=idx,
                    seed=seed,
                    goal=task.goal,
                    task=task,
                )
            )
    return items
