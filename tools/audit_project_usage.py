#!/usr/bin/env python3
"""Conservative first-party reference census. This is never a safe-delete list."""
import argparse
import collections
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = {"core", "entities", "gameplay", "ui", "world", "content"}
TEXT = {".gd", ".tscn", ".tres", ".godot", ".json"}


def audit(root=ROOT):
    root = Path(root)
    files = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                           cwd=root, capture_output=True, text=True)
    candidates = (root / name for name in files.stdout.splitlines()) if files.returncode == 0 else root.rglob("*")
    paths = [p for p in candidates if p.is_file()
             and not set(p.relative_to(root).parts) & {".git", ".godot", "godot_state_charts_examples", "demo"}]
    sources = {p.relative_to(root).as_posix(): p.read_text(encoding="utf-8", errors="replace")
               for p in paths if p.suffix in TEXT
               and p.relative_to(root).parts[0] not in {"addons", "docs"}
               and not any(part.startswith(".") for part in p.relative_to(root).parts)
               and "archive" not in p.relative_to(root).parts}
    classes = {}
    for name, text in sources.items():
        if name.endswith(".gd"):
            match = re.search(r"^class_name\s+(\w+)", text, re.M)
            if match:
                classes[match[1]] = name
    incoming = collections.defaultdict(set)
    dynamic = []
    edges = {}
    for name, text in sources.items():
        refs = set()
        for ref in re.findall(r'res://[^\s"\'<>]+', text):
            if any(mark in ref for mark in ("%", "{", "\\")):
                dynamic.append({"file": name, "expression": ref})
            elif ref.removeprefix("res://") in sources:
                refs.add(ref.removeprefix("res://"))
        # Over-approximation includes type names and comments; reachability is only a lead.
        for token in set(re.findall(r"\b[A-Za-z_]\w*\b", text)) & classes.keys():
            refs.add(classes[token])
        refs.discard(name)
        edges[name] = refs
        for target in refs:
            incoming[target].add(name)
    entrypoints = ["grayriver.tscn", "mvp.tscn", "main.tscn"]
    def reachable(roots, allowed_entry=None):
        seen = set()
        pending = list(roots)
        while pending:
            name = pending.pop()
            if name in seen or name in entrypoints and name != allowed_entry:
                continue
            seen.add(name)
            pending.extend(edges.get(name, ()))
        return seen

    reach = {entry: reachable([entry], entry) for entry in entrypoints}
    validation_roots = sorted(name for name in sources if name.split("/")[0] in {"tests", "tools", "demos"})
    validation_reach = reachable(validation_roots)
    scripts = sorted(n for n in sources if n.endswith(".gd") and n.split("/")[0] in RUNTIME)
    categories = {"possible_current_reference": [], "possible_legacy_only": [],
                  "validation_only_references": [], "referenced_outside_known_entrypoints": [],
                  "no_static_incoming_reference": []}
    for name in scripts:
        refs = incoming[name]
        if name in reach["grayriver.tscn"]:
            group = "possible_current_reference"
        elif name in reach["mvp.tscn"] | reach["main.tscn"]:
            group = "possible_legacy_only"
        elif name in validation_reach:
            group = "validation_only_references"
        elif refs:
            group = "referenced_outside_known_entrypoints"
        else:
            group = "no_static_incoming_reference"
        categories[group].append(name if group=="possible_current_reference" else {"path": name, "referenced_by": sorted(refs)})
    counts = collections.Counter(p.relative_to(root).parts[0] for p in paths if p.suffix == ".gd")
    return {"kind": "conservative_static_references", "entrypoints": entrypoints,
            "validation_roots": validation_roots,
            "limitations": ["References can be optional, inherited, dynamic or in comments.",
                            "Statically reachable does not mean instantiated, unlocked or played.",
                            "Validation reachability includes transitive helpers from tests, tools and demos.",
                            "Referenced outside known entrypoints means the caller chain needs review, not that the script has no callers.",
                            "Files without incoming references require scene/registry/runtime review before deletion.",
                            "Vendor implementations, docs, hidden agent metadata and archived prototypes are excluded from the graph."],
            "script_counts_by_top_directory": dict(sorted(counts.items())),
            "category_counts": {k: len(v) for k, v in categories.items()},
            "categories": categories,
            "dynamic_resource_expressions": sorted(dynamic, key=lambda x: (x["file"], x["expression"]))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/validation/project_usage.json")
    args = parser.parse_args()
    report = audit()
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["category_counts"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
