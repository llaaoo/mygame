#!/usr/bin/env python3
"""Build local desktop ZIPs from the current verified source; never publishes."""
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist"


def main():
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
    if dirty:
        raise SystemExit("Commit verified source before exporting, so the manifest identifies the exact tree.")
    OUT.mkdir(exist_ok=True)
    version = subprocess.check_output(["godot", "--version"], text=True).strip()
    # Export a clean tracked tree; ignored editor examples and local saves never enter it.
    # Editor plugins are build tools, not game behavior. Disable them only in this copy.
    with tempfile.TemporaryDirectory(prefix="mygame-desktop-source-") as directory:
        source = Path(directory)
        for name in subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0"):
            if not name:
                continue
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        project = source / "project.godot"
        project.write_text(re.sub(r"(?ms)^\[editor_plugins\]\n.*?(?=^\[|\Z)", "[editor_plugins]\nenabled=PackedStringArray()\n\n", project.read_text()))
        import_log = OUT / "export-import.log"
        with import_log.open("w") as stream:
            result = subprocess.run(["godot", "--headless", "--path", str(source), "--editor", "--import", "--recovery-mode"], cwd=source, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode or "ERROR:" in import_log.read_text():
            raise SystemExit(f"Clean import failed: {import_log}")
        manifest = {"source_revision": revision, "godot": version, "build_overrides": {"editor_plugins.enabled": []}, "packages": {}}
        for preset, platform, executable in [("Linux", "linux", "EmberPrison.x86_64"), ("Windows", "windows", "EmberPrison.exe")]:
            folder = OUT / platform
            if folder.exists():
                shutil.rmtree(folder)
            folder.mkdir()
            log = OUT / f"export-{platform}.log"
            with log.open("w") as stream:
                result = subprocess.run(["godot", "--headless", "--path", str(source), "--export-release", preset, str(folder / executable)], cwd=source, stdout=stream, stderr=subprocess.STDOUT)
            if result.returncode or "SCRIPT ERROR:" in log.read_text() or "ERROR:" in log.read_text():
                raise SystemExit(f"Export failed: {log}")
            binary = folder / executable
            if not binary.exists() or not (folder / "EmberPrison.pck").exists():
                raise SystemExit(f"Export missing binary/PCK: {folder}")
            signature = b"\x7fELF" if platform == "linux" else b"MZ"
            with binary.open("rb") as stream:
                if stream.read(len(signature)) != signature:
                    raise SystemExit(f"Invalid binary format: {binary}")
            if platform == "linux":
                binary.chmod(0o755)
                env = os.environ.copy()
                for key in ["DATA", "CONFIG", "CACHE"]:
                    env[f"XDG_{key}_HOME"] = str(OUT / "smoke" / key.lower())
                with (OUT / "linux-smoke.log").open("w") as stream:
                    result = subprocess.run([str(binary), "--headless", "--quit-after", "60"], cwd=folder, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=60)
                if result.returncode or "ERROR:" in (OUT / "linux-smoke.log").read_text():
                    raise SystemExit("Linux exported runtime smoke failed")
            shutil.copy2(ROOT / "docs/LOCAL_PLAYTEST.md", folder / "README.md")
            shutil.copy2(ROOT / "docs/FIELD_CHAPTER_PLAYTEST.md", folder / "PLAYTEST.md")
            shutil.copytree(ROOT / "docs/validation", folder / "validation")
            (folder / "SOURCE.json").write_text(json.dumps({"source_revision": revision, "godot": version, "platform": platform, "build_overrides": {"editor_plugins.enabled": []}, "validation": "Linux headless startup passed" if platform == "linux" else "PE/PCK checked; Windows interactive run still required"}, indent=2) + "\n")
            archive = OUT / f"EmberPrison-{platform}-{revision[:8]}.zip"
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
                for path in sorted(folder.rglob("*")):
                    if path.is_file():
                        bundle.write(path, Path(f"EmberPrison-{platform}") / path.relative_to(folder))
            with zipfile.ZipFile(archive) as bundle:
                if bundle.testzip() is not None:
                    raise SystemExit(f"ZIP integrity failure: {archive}")
            with archive.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            manifest["packages"][archive.name] = {"bytes": archive.stat().st_size, "sha256": digest}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
