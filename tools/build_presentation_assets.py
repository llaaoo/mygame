#!/usr/bin/env python3
"""Offline native resource samples and original synthetic CC0 cue sounds (no downloads/RNG)."""
from pathlib import Path
import hashlib
import json
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content/presentation"
OUT.mkdir(parents=True, exist_ok=True)
SOUNDS = OUT / "sounds"
SOUNDS.mkdir(exist_ok=True)
manifest = []
for name, frequency, duration in [("tick", 440, .055), ("gather", 620, .15), ("chime", 780, .24), ("impact", 125, .08)]:
    path = SOUNDS / f"{name}.wav"
    rate = 22050
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        envelope = min(1, t * 300) * (1 - t / duration) ** 2
        value = .22 * envelope * (math.sin(math.tau * frequency * t) + .2 * math.sin(math.tau * frequency * 2.1 * t))
        samples.append(struct.pack("<h", int(value * 32767)))
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, rate, len(samples), "NONE", "not compressed"))
        output.writeframes(b"".join(samples))
    manifest.append({"path": str(path.relative_to(ROOT)), "license": "CC0-1.0", "source": "tools/build_presentation_assets.py; original deterministic synthesis, no sampled recordings", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
(SOUNDS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

rows = ['[gd_resource type="Resource" script_class="PresentationCatalog" load_steps=21 format=3]',
        '[ext_resource type="Script" path="res://gameplay/presentation/presentation_catalog.gd" id="catalog"]',
        '[ext_resource type="Script" path="res://gameplay/presentation/presentation_cue.gd" id="cue"]']
for name in ["tick", "gather", "chime", "impact"]:
    rows.append(f'[ext_resource type="AudioStream" path="res://content/presentation/sounds/{name}.wav" id="{name}"]')
ids = []
for name, sound, channel, radius, priority, color, volume in [
    ("craft", "chime", "world", 30, 1, "0.92, 0.73, 0.35", -12),
    ("harvest", "gather", "world", 24, 1, "0.60, 0.80, 0.45", -14),
    ("puzzle", "chime", "world", 38, 2, "0.45, 0.85, 0.73", -12),
    ("discovery", "chime", "world", 30, 1, "0.85, 0.77, 0.45", -14),
    ("item", "tick", "world", 18, 0, "0.74, 0.76, 0.69", -18),
    ("weapon", "tick", "world", 0, 0, "0.84, 0.76, 0.60", -23),
    ("cast", "chime", "world", 24, 0, "0.57, 0.76, 0.85", -21),
    ("impact", "impact", "world", 18, 1, "0.94, 0.65, 0.43", -17),
    ("defense", "impact", "world", 20, 1, "0.6, 0.8, 0.85", -18),
    ("spell_hit", "impact", "world", 0, 1, "0.94, 0.65, 0.43", -17),
    ("authored_impact", None, "world", 0, 1, "1, 1, 1", -17),
    ("footstep", "impact", "world", 0, 0, "0.8, 0.8, 0.8", -29),
    ("ui_open", "tick", "ui", 0, 0, "1, 1, 1", -22),
    ("ui_confirm", "gather", "ui", 0, 0, "1, 1, 1", -23),
]:
    ids.append(name)
    rows.extend([f'[sub_resource type="Resource" id="{name}"]', 'script = ExtResource("cue")', f'id = &"{name}"', f'channel = "{channel}"', f'tint = Color({color}, 1)', 'duration = 0.5', f'radius = {float(radius)}', f'priority = {priority}', f'volume_db = {float(volume)}'])
    if sound:
        rows.append(f'sound = ExtResource("{sound}")')
rows.extend(['[resource]', 'script = ExtResource("catalog")', 'cues = Array[ExtResource("cue")]([' + ', '.join(f'SubResource("{name}")' for name in ids) + '])'])
(OUT / "cues.tres").write_text("\n\n".join(rows) + "\n")

rows = ['[gd_resource type="AnimationLibrary" load_steps=6 format=3]']
for name, position, scale, color in [
    ("RESET", "Vector2(0, 0)", "Vector2(1, 1)", "Color(1, 1, 1, 1)"),
    ("idle", "Vector2(0, -1)", "Vector2(1, 1)", "Color(1, 1, 1, 1)"),
    ("active", "Vector2(0, -3)", "Vector2(1.05, 1.05)", "Color(1, 1, 1, 1)"),
    ("depleted", "Vector2(0, 1)", "Vector2(0.92, 0.92)", "Color(0.75, 0.75, 0.75, 0.35)"),
    ("complete", "Vector2(0, -1)", "Vector2(1, 1)", "Color(0.8, 1, 0.85, 1)"),
]:
    rows.append(f'[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = 1.0')
    for index, (prop, start, end) in enumerate([("position", "Vector2(0, 0)", position), ("scale", "Vector2(1, 1)", scale), ("modulate", "Color(1, 1, 1, 1)", color)]):
        loop = name in ["idle", "active"]
        times = "0, 0.5, 1" if loop else "0, 1"
        values = f"{start}, {end}, {start}" if loop else f"{start}, {end}"
        transitions = "1, 1, 1" if loop else "1, 1"
        rows.append(f'tracks/{index}/type = "value"\ntracks/{index}/path = NodePath("Visual:{prop}")\ntracks/{index}/interp = 1\ntracks/{index}/keys = {{"times": PackedFloat32Array({times}), "transitions": PackedFloat32Array({transitions}), "update": 0, "values": [{values}]}}')
rows.append('[resource]\n_data = { ' + ', '.join(f'&"{name}": SubResource("{name}")' for name in ["RESET", "idle", "active", "depleted", "complete"]) + ' }')
(OUT / "world_poses.tres").write_text("\n\n".join(rows) + "\n")
(OUT / "world_object.tres").write_text('[gd_resource type="Resource" script_class="WorldAnimationProfile" load_steps=3 format=3]\n[ext_resource type="Script" path="res://gameplay/presentation/world_animation_profile.gd" id="script"]\n[ext_resource type="AnimationLibrary" path="res://content/presentation/world_poses.tres" id="poses"]\n[resource]\nscript = ExtResource("script")\nposes = ExtResource("poses")\n')
for name, values in [("outdoors", ''), ("interior", 'daylight = Color(0.88, 0.89, 0.87, 1)\nnight = Color(0.78, 0.81, 0.85, 1)\nambient_color = Color(0.8, 0.75, 0.65, 0.13)\nmotes = 8\nwind = false\n')]:
    (OUT / f"{name}.tres").write_text('[gd_resource type="Resource" script_class="EnvironmentProfile" load_steps=2 format=3]\n[ext_resource type="Script" path="res://gameplay/presentation/environment_profile.gd" id="script"]\n[resource]\nscript = ExtResource("script")\nid = &"' + name + '"\n' + values)
print("Rebuilt world presentation profiles, native pose library and original cue sounds")
