#!/usr/bin/env python3
"""Run Godot regressions with isolated saves, bounded runtime and retained logs."""
import argparse
import concurrent.futures
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
QUICK = ["save_system", "save_recovery", "skill_catalog", "skill_upgrades", "room_generation"]
INTEGRATION = [
    "input_bindings", "world_pointer_input", "enemy_retaliation", "item_actions", "spray_channel", "reaction_sources", "spell_operations", "foundation_inventory", "foundation_combat", "foundation_systems",
    "frontier_expedition", "frontier_projects",
    "grayriver_loot",
    "grayriver_salvage",
    "shared_characters",
    "field_work",
    "grayriver_foundation",
    "grayriver_content",
    "grayriver_journey",
    "grayriver_routes",
    "material_intent",
    "retreat_ledger",
    "enemy_preparation",
    "field_outpost",
    "expedition_feedback",
    "survival_needs",
    "survival_world",
    "survival_rest",
    "alchemy_repair",
    "material_recycling",
    "rpg_attributes",
    "playtest_iteration", "tactical_balance",
    "normal_budget_tactics", "content_expansion", "environment_attunement", "five_element_rules",
    "partial_boons",
    "element_knowledge",
    "element_world", "enemy_surfaces",
    "element_trials",
    "cast_refactor", "status_transactions", "content_contracts", "region_lifecycle", "player_components", "soul_spell_system", "expedition_builds", "existing_spell_interactions", "emergent_mediums", "boon_choices", "joint_interactions", "advanced_spells",
    "spell_materials", "exploration_content", "exploration_mvp", "fire_combinations",
    "ui_system", "run_loop", "equipment_system", "gameplay",
]
CHECKS = ["content", "startup"]
DIAGNOSTIC = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:)", re.MULTILINE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=["quick", "integration", "all"], default="all")
    parser.add_argument("--tests", nargs="+", choices=QUICK + INTEGRATION + CHECKS)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if args.jobs < 1 or args.timeout <= 0:
        parser.error("jobs and timeout must be positive")
    godot = shutil.which(args.godot)
    if not godot:
        parser.error(f"Godot executable not found: {args.godot}")
    logs = Path(tempfile.mkdtemp(prefix="mygame-tests-"))
    print(f"Logs and isolated saves: {logs}", flush=True)

    def execute(name, options):
        workspace = logs / name
        workspace.mkdir()
        env = os.environ.copy()
        if os.name == "nt":
            env["APPDATA"] = str(workspace / "roaming")
            env["LOCALAPPDATA"] = str(workspace / "local")
        else:
            for kind in ["DATA", "CONFIG", "CACHE"]:
                env[f"XDG_{kind}_HOME"] = str(workspace / kind.lower())
        started = time.monotonic()
        path = logs / f"{name}.log"
        with path.open("w", encoding="utf-8") as output_file:
            try:
                result = subprocess.run(
                    [godot, "--headless", "--path", str(ROOT), *options],
                    cwd=ROOT, env=env, stdout=output_file, stderr=subprocess.STDOUT,
                    text=True, timeout=args.timeout,
                )
                code = result.returncode
            except subprocess.TimeoutExpired:
                output_file.write(f"\nERROR: timeout after {args.timeout} seconds\n")
                code = -1
        output = path.read_text(encoding="utf-8", errors="replace")
        good = code == 0 and not DIAGNOSTIC.search(output)
        print(f"{'PASS' if good else 'FAIL'} {name} ({time.monotonic() - started:.1f}s)" +
              (f" — {path}" if not good else ""), flush=True)
        return good

    # Recovery mode imports assets/classes without starting editor plugins.
    if not (ROOT / ".godot/global_script_class_cache.cfg").exists():
        if not execute("import", ["--editor", "--import", "--recovery-mode"]):
            return 1
    names = args.tests or (QUICK + CHECKS if args.suite == "quick" else
                           INTEGRATION if args.suite == "integration" else
                           QUICK + INTEGRATION + CHECKS)
    names = list(dict.fromkeys(names))

    def run(name):
        if name == "startup":
            options = ["--quit-after", "180"]
        else:
            script = "tools/validate_mvp_content.gd" if name == "content" else f"tests/test_{name}.gd"
            options = ["--script", f"res://{script}"]
        return execute(name, options)

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(run, names))
    print(f"{sum(results)}/{len(results)} checks passed. Logs: {logs}")
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
