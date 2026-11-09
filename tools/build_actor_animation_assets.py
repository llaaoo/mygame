#!/usr/bin/env python3
"""Rebuild native SpriteFrames/AnimationLibrary definitions from pinned, unchanged CC0 sheets. No network needed."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content/animations'
DIRECTIONS=['s','sw','w','nw','n','ne','e','se']
# Only equipment-free columns are allowed in the live profile. The gallery also shows the original baked weapons.
SAFE={'idle':[0,1],'walk':[2,3],'gesture':[16,17,0,1],'hurt':[18,20,18],'death':[21,22,23]}
REFERENCE={'idle':[0,1],'walk':[2,3],'slash':[4,5,6,7],'shot':[8,9,10,11],'cast':[12,13,14,15],'throw':[15,16,17,0],'hurt':[18,20,18],'death':[21,22,23]}
def frames(name,sheet,clips):
 text='[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://content/art/third_party/puny/'+sheet+'" id="sheet"]\n'
 cells=sorted({(row,col) for row in range(8) for cols in clips.values() for col in cols})
 for row,col in cells:text+=f'[sub_resource type="AtlasTexture" id="f_{row}_{col}"]\natlas = ExtResource("sheet")\nregion = Rect2({col*32}, {row*32}, 32, 32)\n'
 text+='[resource]\nanimations = ['
 parts=[]
 for clip,cols in clips.items():
  for row,direction in enumerate(DIRECTIONS):
   fs=', '.join('{"duration": 1.0, "texture": SubResource("f_%d_%d")}'%(row,col) for col in cols)
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
   text+=f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("{path}")\ntracks/{i}/interp = 1\ntracks/{i}/enabled = true\ntracks/{i}/keys = {{"times": PackedFloat32Array({times}), "transitions": PackedFloat32Array({transitions}), "update": 0, "values": [{", ".join(values)}]}}\n'
 text+='[resource]\n_data = {'+', '.join(f'&"{name}": SubResource("{name}")' for name in poses)+'}\n';(OUT/'actor_poses.tres').write_text(text)
def profile(name,title,frames_name,reference=False):
 mapping={k:(k,k) for k in REFERENCE} if reference else {'idle':('idle','idle'),'walk':('walk','walk'),'slash':('gesture','slash'),'slash_reverse':('gesture','slash_reverse'),'slash_heavy':('gesture','slash_heavy'),'thrust':('gesture','thrust'),'thrust_heavy':('gesture','thrust_heavy'),'sweep':('gesture','sweep'),'sweep_heavy':('gesture','sweep_heavy'),'shot':('gesture','shot'),'shot_heavy':('gesture','shot_heavy'),'cast':('gesture','cast'),'throw':('gesture','cast'),'use':('gesture','cast'),'guard':('gesture','guard'),'charge':('gesture','charge'),'dodge':('walk','dodge'),'hurt':('hurt','hurt'),'death':('death','death')}
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
 (OUT/(name+'.tres')).write_text(t)
OUT.mkdir(parents=True,exist_ok=True)
frames('puny_body_frames','Human-Worker-Cyan.png',SAFE)
frames('puny_reference_frames','Character-Base.png',REFERENCE)
frames('puny_mage_frames','Mage-Cyan.png',REFERENCE)
pose_library();profile('puny_body','行路者 · 分层实物装备','puny_body_frames');profile('puny_reference','原素材 · 身体基准（含绘制武器）','puny_reference_frames',True);profile('puny_mage','原素材 · 法师（含绘制服饰）','puny_mage_frames',True)
print('Rebuilt native animation assets')
