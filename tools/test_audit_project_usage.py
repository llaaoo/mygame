"""Reference classification contracts, including indirect validation helpers."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("usage_audit", Path(__file__).with_name("audit_project_usage.py"))
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class UsageAuditTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def classification(self):
        report = audit.audit(self.root)
        by_path = {}
        for category, entries in report["categories"].items():
            for entry in entries:
                path = entry if isinstance(entry, str) else entry["path"]
                by_path[path] = category
                if category == "no_static_incoming_reference":
                    self.assertEqual(entry["referenced_by"], [])
        return report, by_path

    def test_transitive_validation_helpers_have_validation_callers(self):
        self.write("tools/check.gd", 'preload("res://gameplay/validator.gd")')
        self.write("gameplay/validator.gd", "class_name Validator\nvar helper: Geometry")
        self.write("gameplay/geometry.gd", "class_name Geometry")
        report, categories = self.classification()
        self.assertEqual(categories["gameplay/validator.gd"], "validation_only_references")
        self.assertEqual(categories["gameplay/geometry.gd"], "validation_only_references")
        self.assertEqual(report["category_counts"]["no_static_incoming_reference"], 0)

    def test_unrooted_reference_chain_is_distinct_from_zero_incoming(self):
        self.write("experiments/probe.gd", 'preload("res://gameplay/referenced.gd")')
        self.write("gameplay/referenced.gd", "extends RefCounted")
        self.write("gameplay/orphan.gd", "extends RefCounted")
        _, categories = self.classification()
        self.assertEqual(categories["gameplay/referenced.gd"], "referenced_outside_known_entrypoints")
        self.assertEqual(categories["gameplay/orphan.gd"], "no_static_incoming_reference")

    def test_unrooted_cycle_does_not_lose_its_callers(self):
        self.write("gameplay/first.gd", "class_name First\nvar second: Second")
        self.write("gameplay/second.gd", "class_name Second\nvar first: First")
        report, categories = self.classification()
        self.assertEqual(set(categories.values()), {"referenced_outside_known_entrypoints"})
        self.assertEqual(report["category_counts"]["no_static_incoming_reference"], 0)

    def test_product_reachability_takes_precedence_over_test_callers(self):
        self.write("grayriver.tscn", 'path="res://gameplay/live.gd"')
        self.write("gameplay/live.gd", "class_name Live")
        self.write("tests/test_live.gd", "var value: Live")
        _, categories = self.classification()
        self.assertEqual(categories["gameplay/live.gd"], "possible_current_reference")

    def test_legacy_launch_link_does_not_merge_runtime_entrypoints(self):
        self.write("grayriver.tscn", 'path="res://mvp.tscn"')
        self.write("mvp.tscn", 'path="res://gameplay/legacy.gd"')
        self.write("gameplay/legacy.gd", "extends Node")
        _, categories = self.classification()
        self.assertEqual(categories["gameplay/legacy.gd"], "possible_legacy_only")


if __name__ == "__main__":
    unittest.main()
