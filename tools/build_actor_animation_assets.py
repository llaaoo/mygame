#!/usr/bin/env python3
"""Rebuild native SpriteFrames/AnimationLibrary definitions from pinned, unchanged CC0 sheets. No network needed."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content/animations'
DIRECTIONS=['s','sw','w','nw','n','ne','e','se']
# Only equipment-free columns are allowed in the live profile. The gallery also shows the original baked weapons.
SAFE={'idle':[0,1],'walk':[2,3],'gesture':[16,17,0,1],'hurt':[18,20,18],'death':[21,22,23]}
# Equipment-free arm/stance cells, sampled against the authoritative .4/.65
# windup/active markers. Durations keep anticipation, release and recovery
# readable even when the physical profiles have different lengths.
WEAPON_FRAMES={
 'slash':[0,16,17,3,0], 'slash_reverse':[1,17,16,2,1],
 'slash_heavy':[2,16,17,3,0], 'thrust':[1,17,16,0,1],
 'thrust_heavy':[3,17,16,2,0], 'sweep':[2,16,17,1,0], 'sweep_reverse':[1,17,16,0,2],
 'sweep_heavy':[3,16,17,2,1], 'shot':[0,16,17,1,0],
 'shot_heavy':[1,16,17,0,1],
}
for key,cols in WEAPON_FRAMES.items():SAFE[key]=list(zip(cols,[.12,.28,.25,.18,.17]))
SAFE.update({'guard':[(16,1.0)],'charge':[(0,.12),(16,.88)]})
REFERENCE={'idle':[0,1],'walk':[2,3],'slash':[4,5,6,7],'shot':[8,9,10,11],'cast':[12,13,14,15],'throw':[15,16,17,0],'hurt':[18,20,18],'death':[21,22,23]}
def cell(value):return value[0] if isinstance(value,tuple) else value
def duration(value):return value[1] if isinstance(value,tuple) else 1.0
def frames(name,sheet,clips):
 text='[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://content/art/third_party/puny/'+sheet+'" id="sheet"]\n'
 cells=sorted({(row,cell(col)) for row in range(8) for cols in clips.values() for col in cols})
 for row,col in cells:text+=f'[sub_resource type="AtlasTexture" id="f_{row}_{col}"]\natlas = ExtResource("sheet")\nregion = Rect2({col*32}, {row*32}, 32, 32)\n'
 text+='[resource]\nanimations = ['
 parts=[]
 for clip,cols in clips.items():
  for row,direction in enumerate(DIRECTIONS):
   fs=', '.join('{"duration": %s, "texture": SubResource("f_%d_%d")}'%(duration(col),row,cell(col)) for col in cols)
   parts.append('{"name": &"%s_%s", "speed": %s, "loop": %s, "frames": [%s]}'%(clip,direction,4 if clip=='idle' else 8,'true' if clip in ['idle','walk'] else 'false',fs))
 text+=',\n'.join(parts)+']\n';(OUT/(name+'.tres')).write_text(text)
def pose_library():
 # Editable native tracks; one normalized second. Actual action timing comes from gameplay, never from these curves.
 poses={
 'RESET':[(0,0),(0,0),[12,0],[-12,0]],
 'idle':[(0,0),(0,0),[12,0],[-12,0]],
 'walk':[(0,-1),(0,.02),[12,-1],[-12,1]],
 'slash':[(0,-2),(0,-.09),[9,-5],[-10,2]],
 'slash_reverse':[(0,-2),(0,.09),[9,5],[-10,-2]],
 'slash_heavy':[(0,-3),(0,-.15),[7,-8],[-9,3]],
 'thrust':[(0,-1),(0,.03),[18,0],[-10,0]],
 'thrust_heavy':[(0,-3),(0,.05),[22,0],[-10,0]],
 'sweep':[(0,-2),(0,.13),[12,-7],[-9,4]],
 'sweep_reverse':[(0,-2),(0,-.13),[12,7],[-9,-4]],
 'sweep_heavy':[(0,-3),(0,.2),[15,-9],[-9,4]],
 'shot':[(0,-1),(0,-.03),[6,0],[16,0]],
 'shot_heavy':[(0,-2),(0,-.06),[3,0],[18,0]],
 'cast':[(0,-2),(0,.02),[18,-2],[-16,-2]],
 'work_gather':[(0,4),(0,.10),[15,6],[-9,4]],
 'work_craft':[(0,1),(0,-.05),[12,-6],[-12,2]],
 'work_rest':[(0,6),(0,.04),[9,5],[-9,5]],
 'guard':[(0,0),(0,-.04),[9,-7],[-12,0]],
 'charge':[(0,1),(0,-.07),[7,-5],[-10,2]],
 'dodge':[(0,-4),(0,.13),[8,0],[-8,0]],
 'hurt':[(0,1),(0,-.07),[9,0],[-9,0]],
 'death':[(0,3),(0,-.04),[9,0],[-9,0]],
 }
 # Facing-relative root offsets are visual only. Keys at .4/.65 correspond
 # to the clip markers, so release poses cannot drift into windup/recovery.
 weapon_poses={
 'slash': [[(0,0),(-2,-3),(3,5),(1,2),(0,0)], [0,-.12,.10,.04,0], [(12,0),(13,-7),(7,11),(10,4),(12,0)], [(-12,0),(-9,2),(-12,-2),(-12,-1),(-12,0)]],
 'slash_reverse': [[(0,0),(2,-3),(-3,5),(-1,2),(0,0)], [0,.12,-.10,-.04,0], [(12,0),(7,8),(14,-9),(12,-3),(12,0)], [(-12,0),(-10,-2),(-9,3),(-11,1),(-12,0)]],
 'slash_heavy': [[(0,0),(-3,-6),(4,8),(2,3),(0,0)], [0,-.20,.17,.08,0], [(12,0),(9,-12),(5,15),(9,6),(12,0)], [(-12,0),(-6,-3),(-10,7),(-11,3),(-12,0)]],
 'thrust': [[(0,0),(0,-3),(0,7),(0,2),(0,0)], [0,-.03,.04,.02,0], [(12,0),(7,-8),(7,18),(10,6),(12,0)], [(-12,0),(-5,-4),(-5,7),(-9,2),(-12,0)]],
 'thrust_heavy': [[(0,0),(0,-6),(0,10),(0,4),(0,0)], [0,-.06,.07,.03,0], [(12,0),(5,-12),(5,23),(9,9),(12,0)], [(-12,0),(-4,-7),(-4,10),(-8,3),(-12,0)]],
 'sweep': [[(0,0),(3,-3),(-3,5),(-1,2),(0,0)], [0,-.16,.18,.06,0], [(12,0),(12,-10),(9,12),(11,5),(12,0)], [(-12,0),(-5,-5),(-6,8),(-9,3),(-12,0)]],
 'sweep_reverse': [[(0,0),(-3,-3),(3,5),(1,2),(0,0)], [0,.16,-.18,-.06,0], [(12,0),(9,10),(13,-12),(12,-5),(12,0)], [(-12,0),(-6,5),(-5,-8),(-9,-3),(-12,0)]],
 'sweep_heavy': [[(0,0),(4,-6),(-4,8),(-2,3),(0,0)], [0,-.25,.28,.10,0], [(12,0),(10,-15),(7,17),(10,7),(12,0)], [(-12,0),(-3,-9),(-4,13),(-8,5),(-12,0)]],
 'shot': [[(0,0),(0,-2),(0,-1),(0,-3),(0,0)], [0,-.05,-.03,.02,0], [(12,0),(7,11),(7,12),(9,7),(12,0)], [(-12,0),(-4,-10),(-11,2),(-12,1),(-12,0)]],
 'shot_heavy': [[(0,0),(0,-4),(0,-2),(0,-5),(0,0)], [0,-.08,-.04,.04,0], [(12,0),(5,13),(5,15),(8,8),(12,0)], [(-12,0),(-2,-15),(-12,4),(-12,2),(-12,0)]],
 }
 poses['guard']=[(0,1),(0,-.04),[5,9],[-8,11]]
 poses['charge']=[(0,-2),(0,-.10),[7,-7],[-8,3]]
 text='[gd_resource type="AnimationLibrary" format=3]\n'
 for name,(position,rotation,right,left) in poses.items():
  text+=f'[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = 1.0\n'
  for i,(path,v,is_rotation) in enumerate([('Rig:position',position,False),('Rig:rotation',rotation,True),('Rig/Sockets/MainHand:position',right,False),('Rig/Sockets/OffHand:position',left,False)]):
   # RESET and held poses stay constant. Action curves return to their neutral value.
   fmt=lambda p: str(p[1]) if is_rotation else f'Vector2({p[0]}, {p[1]})'
   neutral=(0,0) if i<2 else (12,0) if i==2 else (-12,0)
   values=[fmt(v)]*3 if name in ['RESET','idle','guard','charge'] else [fmt(neutral),fmt(v),fmt(neutral)]
   if name=='death':
    values=['0.0','-0.6','-1.5'] if is_rotation else ['Vector2(0,0)','Vector2(0,2)','Vector2(0,4)'] if i==0 else [fmt(v)]*3
   times='0, 0.5, 1'
   transitions='1,1,1'
   if name=='walk':
    times='0, 0.25, 0.5, 0.75, 1'; transitions='1,1,1,1,1'
    values=['0.0','0.02','0.0','-0.02','0.0'] if is_rotation else ['Vector2(0,0)','Vector2(0,-1)','Vector2(0,0)','Vector2(0,-1)','Vector2(0,0)'] if i==0 else [fmt(neutral),fmt(v),fmt(neutral),f'Vector2({neutral[0]}, {-v[1]})',fmt(neutral)]
   if name in weapon_poses:
    times='0, 0.4, 0.65, 0.85, 1';transitions='1,1,1,1,1'
    values=[str(value) if is_rotation else f'Vector2({value[0]}, {value[1]})' for value in weapon_poses[name][i]]
   text+=f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("{path}")\ntracks/{i}/interp = 1\ntracks/{i}/enabled = true\ntracks/{i}/keys = {{"times": PackedFloat32Array({times}), "transitions": PackedFloat32Array({transitions}), "update": 0, "values": [{", ".join(values)}]}}\n'
 text+='[resource]\n_data = {'+', '.join(f'&"{name}": SubResource("{name}")' for name in poses)+'}\n';(OUT/'actor_poses.tres').write_text(text)
def profile(name,title,frames_name,reference=False):
 mapping={k:(k,k) for k in REFERENCE} if reference else {'idle':('idle','idle'),'walk':('walk','walk'),**{key:(key,key) for key in WEAPON_FRAMES},'cast':('gesture','cast'),'throw':('gesture','cast'),'use':('gesture','cast'),'guard':('guard','guard'),'charge':('charge','charge'),'dodge':('walk','dodge'),'hurt':('hurt','hurt'),'death':('death','death')}
 # Original reference throw uses the cast pose; source frames retain their original appearance.
 if reference:mapping['throw']=('throw','cast')
 else:mapping.update({key:('gesture' if key!='work_rest' else 'idle',key) for key in ['work_gather','work_craft','work_rest']})
 t='[gd_resource type="Resource" script_class="ActorAnimationProfile" format=3]\n[ext_resource type="Script" path="res://gameplay/presentation/actors/actor_animation_profile.gd" id="profile"]\n[ext_resource type="Script" path="res://gameplay/presentation/actors/actor_animation_clip.gd" id="clip"]\n[ext_resource type="SpriteFrames" path="res://content/animations/'+frames_name+'.tres" id="frames"]\n[ext_resource type="AnimationLibrary" path="res://content/animations/actor_poses.tres" id="poses"]\n'
 for key,(frames_id,pose_id) in mapping.items():
  t+=f'[sub_resource type="Resource" id="{key}"]\nscript = ExtResource("clip")\nid = &"{key}"\nframes = &"{frames_id}"\npose = &"{pose_id}"\n'
 fallbacks={'spray':'cast','channel':'cast','aim':'charge','item':'use','stagger':'hurt','sprint':'walk'} if not reference else {}
 if 'walk' in mapping:
  t=t.replace('id = &"walk"\n', 'id = &"walk"\nfootsteps = PackedFloat32Array(0, 0.5)\n')
 t+='[resource]\nscript = ExtResource("profile")\nid = &"'+name+'"\ntitle = "'+title+'"\nsprite_frames = ExtResource("frames")\nposes = ExtResource("poses")\nclips = Array[ExtResource("clip")](['+', '.join(f'SubResource("{key}")' for key in mapping)+'])\nfallback = '+json.dumps(fallbacks)+'\n'
 if reference: t+='equipment_free = false\n'
 else:t+='facing_relative_poses = Array[StringName](['+', '.join('&"'+key+'"' for key in [*WEAPON_FRAMES,'guard','charge'])+'])\n'
 (OUT/(name+'.tres')).write_text(t)
OUT.mkdir(parents=True,exist_ok=True)
frames('puny_body_frames','Human-Worker-Cyan.png',SAFE)
frames('puny_reference_frames','Character-Base.png',REFERENCE)
frames('puny_mage_frames','Mage-Cyan.png',REFERENCE)
pose_library();profile('puny_body','行路者 · 分层实物装备','puny_body_frames');profile('puny_reference','原素材 · 身体基准（含绘制武器）','puny_reference_frames',True);profile('puny_mage','原素材 · 法师（含绘制服饰）','puny_mage_frames',True)
print('Rebuilt native animation assets')
