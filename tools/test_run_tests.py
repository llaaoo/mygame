"""Exercise runner failure detection with a fake engine, not a second game suite."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).with_name("run_tests.py")
SPEC = importlib.util.spec_from_file_location("runner", RUNNER)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RunnerContractTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "tools").mkdir()
        shutil.copyfile(RUNNER, self.root / "tools/run_tests.py")
        (self.root / ".godot").mkdir()
        (self.root / ".godot/global_script_class_cache.cfg").touch()
        self.engine = self.root / "fake-godot"
        self.engine.write_text("""#!/usr/bin/env python3
import os, sys, time
if '--version' in sys.argv:
    print('fake-godot-4.6'); sys.exit(0)
mode = os.environ.get('RUNNER_FAKE_MODE', 'passed')
if mode == 'timeout': time.sleep(5)
if mode == 'script_error': print('SCRIPT ERROR: deliberate fixture failure')
if mode == 'warning': print('\\x1b[33mWARNING: deliberate fixture warning\\x1b[0m')
if mode == 'exit_code': sys.exit(7)
if mode.startswith('xml_'):
    path = next(arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('-gjunit_xml_file='))
    case = '' if mode == 'xml_empty' else '<testcase>' + {'xml_pass': '', 'xml_fail': '<failure/>', 'xml_skip': '<skipped/>'}[mode] + '</testcase>'
    open(path, 'w').write('<testsuites><testsuite>' + case + '</testsuite></testsuites>')
print('PASS fixture')
""", encoding="utf-8")
        self.engine.chmod(0o755)

    def invoke(self, mode="passed", tests=("save_system",), timeout=5):
        path = self.root / "result.json"
        env = dict(os.environ, RUNNER_FAKE_MODE=mode)
        result = subprocess.run([sys.executable, str(self.root / "tools/run_tests.py"),
                                 "--godot", str(self.engine), "--tests", *tests,
                                 "--timeout", str(timeout), "--report", str(path)],
                                capture_output=True, text=True, env=env, timeout=15)
        report = json.loads(path.read_text(encoding="utf-8"))
        # The real runner intentionally retains evidence; these are disposable fake logs.
        self.addCleanup(shutil.rmtree, report["logs"], True)
        return result, report

    def test_diagnostics_and_exit_codes_are_never_green(self):
        for mode in ["passed", "script_error", "warning", "exit_code", "timeout"]:
            with self.subTest(mode=mode):
                process, report = self.invoke(mode, timeout=0.15 if mode == "timeout" else 5)
                self.assertEqual(process.returncode, 0 if mode == "passed" else 1)
                self.assertEqual(report["results"][0]["category"], mode)
                self.assertTrue(report["complete"])
                self.assertIn("command", report["results"][0])

    def test_preflight_failure_marks_unrun_tests_as_skipped(self):
        process, report = self.invoke("script_error", ("content", "save_system"))
        self.assertEqual(process.returncode, 1)
        self.assertEqual(report["skipped"], ["save_system"])
        self.assertFalse(report["complete"])
        self.assertEqual(len(report["results"]), 1)

    def test_import_failure_stops_suite(self):
        (self.root / ".godot/global_script_class_cache.cfg").unlink()
        process, report = self.invoke("script_error")
        self.assertEqual(process.returncode, 1)
        self.assertEqual(report["results"][0]["name"], "import")
        self.assertEqual(report["skipped"], ["save_system"])

    def test_empty_gut_run_is_not_success(self):
        process, report = self.invoke(tests=("gut_domain",))
        self.assertEqual(process.returncode, 1)
        self.assertEqual(report["results"][0]["category"], "missing_test_result")

    def test_gut_xml_must_contain_executed_passing_cases(self):
        for mode in ["xml_pass", "xml_empty", "xml_fail", "xml_skip"]:
            with self.subTest(mode=mode):
                process, report = self.invoke(mode, ("gut_domain",))
                self.assertEqual(process.returncode, 0 if mode == "xml_pass" else 1)
                self.assertEqual(report["results"][0]["category"], "passed" if mode == "xml_pass" else "test_result")

    @unittest.skipIf(os.name == "nt", "POSIX fake executable fixture")
    def test_checkout_lock_rejects_competing_runner(self):
        original = runner.ROOT
        runner.ROOT = self.root
        self.addCleanup(setattr, runner, "ROOT", original)
        with runner.checkout_lock():
            process = subprocess.run([sys.executable, str(self.root / "tools/run_tests.py"),
                                      "--godot", str(self.engine), "--tests", "save_system"],
                                     capture_output=True, text=True, timeout=10)
        self.assertEqual(process.returncode, 2)
        self.assertIn("Another test runner", process.stdout)

    def test_inherited_input_probes_are_detected(self):
        original = runner.ROOT
        runner.ROOT = self.root
        self.addCleanup(setattr, runner, "ROOT", original)
        (self.root / "tests/support").mkdir(parents=True)
        (self.root / "tests/support/input_scene_probe.gd").write_text("extends SceneTree\n")
        (self.root / "tests/test_inherited.gd").write_text('extends "res://tests/support/input_scene_probe.gd"\n')
        (self.root / "tests/test_plain.gd").write_text("extends SceneTree\n")
        self.assertTrue(runner.input_probe("inherited"))
        self.assertFalse(runner.input_probe("plain"))


if __name__ == "__main__":
    unittest.main()
