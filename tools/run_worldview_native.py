#!/usr/bin/env python3
"""Launch one native probe phase with shared isolated saves and retained evidence.

Send actual input separately through tools/first30_commands.py. This runner never
copies a seed, edits game state, imports assets, or executes a gameplay route.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def live_engine_pids(engine):
    result = []
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            if (proc / 'exe').resolve(strict=True) == engine:
                result.append(int(proc.name))
        except (OSError, RuntimeError):
            pass
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--evidence-root', type=Path, required=True)
    parser.add_argument('--phase', required=True, help='New output directory, e.g. mundane, accept, resume')
    parser.add_argument('--display', default=':93')
    parser.add_argument('--fresh', action='store_true', help='Refuse existing XDG state; never delete it')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--timeout', type=float, default=3600)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.phase) or not re.fullmatch(r':\d+', args.display):
        parser.error('Use a simple phase directory and an explicit X11 display number')
    if args.timeout <= 0:
        parser.error('timeout must be positive')
    source = args.source.resolve()
    base = args.evidence_root.resolve()
    engine_path = shutil.which(args.godot)
    if not engine_path or not shutil.which('Xorg'):
        parser.error('Godot and Xorg must already be installed')
    engine = Path(engine_path).resolve()
    active = live_engine_pids(engine)
    if active:
        parser.error(f'Another Godot process is running: {active}; wait for the coordinated GUI slot')
    number = args.display[1:]
    if Path('/tmp/.X11-unix/X' + number).exists() or Path('/tmp/.X' + number + '-lock').exists():
        parser.error('Display socket/lock already exists; inspect it or choose a free display')
    storage = {kind: base / kind for kind in ['data', 'config', 'cache']}
    before = {kind: path.exists() for kind, path in storage.items()}
    if args.fresh and any(before.values()):
        parser.error(f'Fresh journey requires absent XDG directories, found {before}')
    base.mkdir(parents=True, exist_ok=True)
    out = base / args.phase
    out.mkdir()  # Never overwrite prior failures, ready.json, logs or screenshots.
    config = source / 'tools/playtests/native_xorg_1152.conf'
    if not config.is_file() or not (source / 'tools/first30_probe.gd').is_file():
        parser.error('Source is missing the native Xorg configuration or input probe')
    game_command = [str(engine), '--path', str(source), '--rendering-method', 'gl_compatibility',
                    '--audio-driver', 'Dummy', '--resolution', '1152x648',
                    '--script', 'res://tools/first30_probe.gd']
    xorg_command = ['Xorg', args.display, '-config', str(config), '-noreset', '-nolisten', 'tcp']
    env = os.environ.copy()
    env.update(DISPLAY=args.display, GRAYRIVER_FIRST30_OUTPUT=str(out),
               XDG_DATA_HOME=str(storage['data']), XDG_CONFIG_HOME=str(storage['config']),
               XDG_CACHE_HOME=str(storage['cache']))
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=source, capture_output=True, text=True)
    dirty = subprocess.run(['git', 'status', '--short'], cwd=source, capture_output=True, text=True)
    manifest = {'schema': 1, 'started_utc': utc_now(), 'source': str(source),
                'revision': revision.stdout.strip(), 'dirty_files': dirty.stdout.splitlines(),
                'phase': args.phase, 'output': str(out), 'display': args.display,
                'xdg_before': before, 'fresh_requested': args.fresh, 'seed_copied': False,
                'game_command': game_command, 'xorg_command': xorg_command,
                'audio': 'Dummy: auditory experience unverified', 'timeout_seconds': args.timeout}
    manifest_path = out / 'launch.json'

    def save_manifest():
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')

    save_manifest()
    native = None
    server = None
    try:
        with (out / 'xorg.log').open('x') as xlog:
            server = subprocess.Popen(xorg_command, stdout=xlog, stderr=subprocess.STDOUT)
            manifest['xorg_pid'] = server.pid
            save_manifest()
            deadline = time.monotonic() + 10
            while not Path('/tmp/.X11-unix/X' + number).exists():
                if server.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError('Xorg did not create a usable socket; inspect xorg.log')
                time.sleep(.1)
            with (out / 'runtime.log').open('x') as log:
                native = subprocess.Popen(game_command, cwd=source, env=env, stdout=log,
                                          stderr=subprocess.STDOUT)
                manifest['godot_pid'] = native.pid
                save_manifest()
                print(f'Native probe: {out}; PID {native.pid}', flush=True)
                manifest['native_exit_code'] = native.wait(timeout=args.timeout)
    except (OSError, RuntimeError, subprocess.TimeoutExpired, KeyboardInterrupt) as error:
        manifest['driver_error'] = str(error) or type(error).__name__
    finally:
        if native is not None and native.poll() is None:
            native.terminate()
            try:
                native.wait(timeout=10)
            except subprocess.TimeoutExpired:
                native.kill()
                native.wait()
            manifest['native_exit_code'] = native.returncode
        if server is not None:
            if server.poll() is None:
                server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
            manifest['xorg_exit_code'] = server.returncode
        manifest['ended_utc'] = utc_now()
        save_manifest()
    print(json.dumps({'output': str(out), 'native_exit_code': manifest.get('native_exit_code'),
                      'driver_error': manifest.get('driver_error')}, ensure_ascii=False), flush=True)
    return 0 if manifest.get('native_exit_code') == 0 and 'driver_error' not in manifest else 1


if __name__ == '__main__':
    raise SystemExit(main())
