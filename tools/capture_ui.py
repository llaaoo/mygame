#!/usr/bin/env python3
"""Capture actual Godot UI on isolated Linux Xorg; never uses the player's saves."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
TESTS = ("ui_vertical_input", "ui_prototype_input")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New evidence directory")
    parser.add_argument("--tests", nargs="+", choices=TESTS, default=list(TESTS))
    parser.add_argument("--display", type=int, default=95)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for binary in ("Xorg", "godot"):
        if not shutil.which(binary):
            parser.error(f"Required native program is missing: {binary}")
    socket = Path(f"/tmp/.X11-unix/X{args.display}")
    if socket.exists():
        parser.error(f"Display :{args.display} is already in use")
    conf = (ROOT / "tools/playtests/native_xorg_1152.conf").read_text()
    conf = conf.replace("Virtual 1152 648", "Virtual 1920 1080")
    (out / "xorg.conf").write_text(conf)
    results = []
    with (out / "xorg.log").open("w") as log:
        server = subprocess.Popen(["Xorg", f":{args.display}", "-config", str(out / "xorg.conf"),
                                   "-noreset", "-nolisten", "tcp"], stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 15
            while not socket.exists():
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Native Xorg failed; inspect xorg.log")
                time.sleep(.1)
            for name in args.tests:
                folder = out / name
                folder.mkdir()
                captures = folder / "captures"
                captures.mkdir()
                env = os.environ.copy()
                env.update(DISPLAY=f":{args.display}", CONTROLS_VISUAL_OUTPUT=str(captures),
                           XDG_DATA_HOME=str(folder / "data"), XDG_CONFIG_HOME=str(folder / "config"),
                           XDG_CACHE_HOME=str(folder / "cache"))
                command = ["godot", "--path", str(ROOT), "--rendering-method", "gl_compatibility",
                           "--audio-driver", "Dummy", "--resolution", "1152x648",
                           "--script", f"res://tests/test_{name}.gd"]
                with (folder / "runtime.log").open("w") as runtime:
                    try:
                        completed = subprocess.run(command, env=env, stdout=runtime,
                                                   stderr=subprocess.STDOUT, timeout=300)
                        code = completed.returncode
                    except subprocess.TimeoutExpired:
                        code = 124
                text = (folder / "runtime.log").read_text()
                errors = re.findall(r"^(?:ERROR:|SCRIPT ERROR:).*$", text, re.M)
                result = {"test": name, "exit_code": code, "errors": errors,
                          "command": command, "passed": code == 0 and not errors}
                results.append(result)
                print(json.dumps(result, ensure_ascii=False), flush=True)
        finally:
            server.terminate()
            server.wait(timeout=10)
    (out / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
