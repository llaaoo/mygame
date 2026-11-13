#!/usr/bin/env python3
"""Run Godot regressions with isolated saves, bounded runtime and retained logs."""
import argparse
import concurrent.futures
from contextlib import contextmanager
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
QUICK = ["gut_domain", "save_system", "save_recovery", "skill_catalog", "skill_upgrades", "room_generation"]
INTEGRATION = [
    "first_expedition_loop", "worldview_journey", "magic_awakening", "mundane_spray_input",
    "content_preflight", "throw_trajectory_input", "item_feedback_input",
    "project_optimization",
    "selector_feedback_input", "accessibility_input",
    "world_depth_knowledge", "world_depth_property", "world_depth_economy", "world_depth_journey", "world_depth_territory", "world_depth_input",
    "fieldcraft", "enemy_diversity", "fieldcraft_input", "enemy_diversity_input",
    "map_authoring", "map_preview_input",
    "save_sections", "save_sections_game", "town_cells", "town_cells_input", "presentation_system", "presentation_input",
    "actor_animation", "animation_demo_input", "weapon_hold", "weapon_hold_input", "weapon_hold_handover_input", "weapon_art_routes", "weapon_art_input", "martial_followups", "martial_followup_input", "weapon_combos", "weapon_combo_contacts", "weapon_combo_input", "weapon_response", "weapon_response_input", "interface_navigation", "world_feedback", "world_feedback_input", "followup_fixes", "grayriver_demo",
    "spell_form_assist", "contextual_choices", "combat_choices_input", "flow_input",
    "provision_lifecycle", "production_learning", "extensibility_input",
    "campaign_effects", "inventory_stability", "new_journey",
    "weapon_enchantment", "enchantment_input",
    "counterplay", "counterplay_input", "counterplay_encounters", "combat_tactics", "tactical_ai", "tactics_input", "system_depth", "weapon_actions", "depth_input",
    "slot_materials", "inventory_lifecycle", "realtime_interaction", "keyboard_casting", "visual_interface", "controls_workflow", "unified_quickslots", "legacy_operation_coverage", "input_bindings", "world_pointer_input", "enemy_retaliation", "item_actions", "spray_channel", "reaction_sources", "spell_operations", "foundation_inventory", "foundation_combat", "foundation_systems",
    "frontier_expedition", "frontier_projects",
    "grayriver_loot",
    "archive_adventure", "enemy_observation_input",
    "enemy_disengagement", "enemy_phase_input",
    "combat_learning",
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
    "rpg_attributes", "rpg_progression", "rpg_progression_input", "npc_interactions", "npc_interaction_input", "world_coherence", "coherence_input",
    "playtest_iteration", "tactical_balance",
    "normal_budget_tactics", "content_expansion", "environment_attunement", "five_element_rules",
    "partial_boons",
    "element_knowledge",
    "element_world", "enemy_surfaces",
    "element_trials",
    "cast_refactor", "status_transactions", "content_contracts", "region_lifecycle", "player_components", "soul_spell_system", "expedition_builds", "existing_spell_interactions", "emergent_mediums", "boon_choices", "joint_interactions", "advanced_spells",
    "spell_materials", "exploration_content", "exploration_mvp", "fire_combinations",
    "ui_vertical_input", "ui_prototype_input", "immersive_ui_input", "ui_system", "run_loop", "equipment_system", "gameplay",
]
CHECKS = ["content", "maps", "startup"]
DIAGNOSTIC = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:)", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-9;]*m")


@contextmanager
def checkout_lock():
    """Prevent independent runners from competing over this checkout/import cache."""
    lock = ROOT / ".godot/run_tests.lock"
    lock.parent.mkdir(exist_ok=True)
    with lock.open("a+b") as stream:
        if os.name == "nt":
            import msvcrt
            stream.seek(0)
            stream.write(b"0")
            stream.flush()
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Closing releases the OS lock even on abnormal process exit.
        yield


def input_probe(name):
    """Follow script inheritance, rather than guessing from test-name suffixes."""
    script = ROOT / f"tests/test_{name}.gd"
    visited = set()
    while script.exists() and script not in visited:
        visited.add(script)
        if script == ROOT / "tests/support/input_scene_probe.gd":
            return True
        source = script.read_text(encoding="utf-8")
        if re.search(r"\b(?:Input\.|push_input\(|InputEvent)", source):
            return True
        parent = re.search(r'^extends\s+["\']res://([^"\']+)["\']', source, re.MULTILINE)
        if not parent:
            break
        script = ROOT / parent[1]
    return False


def failure_category(code, output, timed_out=False):
    if timed_out:
        return "timeout"
    if "SCRIPT ERROR:" in output:
        return "script_error"
    if re.search(r"^ERROR:", output, re.MULTILINE):
        return "godot_error"
    if re.search(r"^WARNING:", output, re.MULTILINE):
        return "warning"
    return "exit_code" if code != 0 else "passed"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=["quick", "integration", "all"], default="all")
    parser.add_argument("--tests", nargs="+", choices=QUICK + INTEGRATION + CHECKS)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--report", type=Path, help="JSON report path (default: retained log directory/results.json)")
    parser.add_argument("--source-revision", help="Source commit label for a git-archive export without .git")
    args = parser.parse_args()
    if args.jobs < 1 or args.timeout <= 0:
        parser.error("jobs and timeout must be positive")
    godot = shutil.which(args.godot)
    if not godot:
        parser.error(f"Godot executable not found: {args.godot}")
    logs = Path(tempfile.mkdtemp(prefix="mygame-tests-"))
    print(f"Logs and isolated saves: {logs}", flush=True)
    report_path = args.report or logs / "results.json"
    names = args.tests or (QUICK + CHECKS if args.suite == "quick" else
                           INTEGRATION if args.suite == "integration" else
                           QUICK + INTEGRATION + CHECKS)
    names = list(dict.fromkeys(names))
    def git_value(*options):
        result = subprocess.run(["git", *options], cwd=ROOT, capture_output=True, text=True, timeout=10)
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    version = subprocess.run([godot, "--version"], capture_output=True, text=True, timeout=10)
    status = git_value("status", "--porcelain")
    report = {"schema": 1, "revision": args.source_revision or git_value("rev-parse", "HEAD"),
              "dirty": None if status == "unknown" else status != "", "godot": version.stdout.strip(),
              "platform": platform.platform(), "jobs": args.jobs, "timeout": args.timeout,
              "logs": str(logs), "requested": names, "results": [], "skipped": [], "complete": False}

    def save_report():
        report_path.parent.mkdir(parents=True, exist_ok=True)
        staging = report_path.with_suffix(report_path.suffix + ".tmp")
        staging.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        staging.replace(report_path)

    save_report()

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
        timed_out = False
        command = [godot, "--headless", "--path", str(ROOT), *options]
        with path.open("w", encoding="utf-8") as output_file:
            try:
                result = subprocess.run(
                    command,
                    cwd=ROOT, env=env, stdout=output_file, stderr=subprocess.STDOUT,
                    text=True, timeout=args.timeout,
                )
                code = result.returncode
            except subprocess.TimeoutExpired:
                output_file.write(f"\nERROR: timeout after {args.timeout} seconds\n")
                code = -1
                timed_out = True
        output = ANSI.sub("", path.read_text(encoding="utf-8", errors="replace"))
        category = failure_category(code, output, timed_out)
        # A successful process without discovered/executed tests is not a green GUT run.
        if name == "gut_domain" and category == "passed":
            try:
                xml = ET.parse(logs / "gut-domain.xml").getroot()
                cases = list(xml.iter("testcase"))
                if not cases or any(case.find("failure") is not None or case.find("skipped") is not None or
                                    case.find("error") is not None for case in cases):
                    category = "test_result"
            except (OSError, ET.ParseError):
                category = "missing_test_result"
        good = category == "passed"
        duration = time.monotonic() - started
        diagnostic = DIAGNOSTIC.search(output)
        excerpt = output[diagnostic.start():].splitlines()[:8] if diagnostic else output.splitlines()[-8:]
        print(f"{'PASS' if good else 'FAIL'} {name} ({time.monotonic() - started:.1f}s)" +
              (f" [{category}] — {path}\n" + "\n".join(excerpt) if not good else ""), flush=True)
        return {"name": name, "passed": good, "category": category, "exit_code": code,
                "seconds": round(duration, 3), "command": command, "log": str(path),
                "diagnostic": excerpt if not good else []}

    def record(result):
        report["results"].append(result)
        save_report()
        return result["passed"]

    # Recovery mode imports assets/classes without starting editor plugins.
    if not (ROOT / ".godot/global_script_class_cache.cfg").exists():
        if not record(execute("import", ["--editor", "--import", "--recovery-mode"])):
            report["skipped"] = names
            save_report()
            return 1

    def run(name):
        if name == "gut_domain":
            options = ["--script", "res://addons/gut/gut_cmdln.gd", "-gexit", "-gdisable_colors",
                       f"-gjunit_xml_file={logs / 'gut-domain.xml'}"]
        elif name == "startup":
            options = ["--quit-after", "180"]
        else:
            script = "tools/validate_mvp_content.gd" if name == "content" else "tools/validate_maps.gd" if name == "maps" else f"tests/test_{name}.gd"
            options = ["--script", f"res://{script}"]
        return execute(name, options)

    # Validate authored content first; do not turn one parser/catalog error into 140 failures.
    preflight = [name for name in ["content", "maps", "gut_domain"] if name in names]
    for name in preflight:
        if not record(run(name)):
            done = {result["name"] for result in report["results"]}
            report["skipped"] = [pending for pending in names if pending not in done]
            save_report()
            print(f"Preflight failed; remaining checks not run. Report: {report_path}", flush=True)
            return 1
    remaining = [name for name in names if name not in preflight]
    probes = [name for name in remaining if input_probe(name)]
    domain = [name for name in remaining if name not in probes]
    # Native input/short combat windows run alone; never overlap them with domain workers.
    print(f"Schedule: {len(domain)} parallel-domain checks, then {len(probes)} serial input checks", flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for future in concurrent.futures.as_completed([pool.submit(run, name) for name in domain]):
            record(future.result())
    for name in probes:
        record(run(name))
    results = [result["passed"] for result in report["results"] if result["name"] in names]
    report["complete"] = len(results) == len(names)
    save_report()
    print(f"{sum(results)}/{len(names)} checks passed. Logs: {logs}. Report: {report_path}")
    return 0 if all(results) else 1


if __name__ == "__main__":
    try:
        with checkout_lock():
            code = main()
    except BlockingIOError:
        print("Another test runner owns this checkout; wait for it to finish before running again.", flush=True)
        code = 2
    raise SystemExit(code)
