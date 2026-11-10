#!/usr/bin/env python3
"""Original quadruped placeholders, eight directions; reproducible, no downloads.
Each frame projects a small 3D silhouette onto an isometric sprite plane.
These drawings contain no equipment and use the shared, presentation-only rig.
"""
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
DIRECTIONS=['s','sw','w','nw','n','ne','e','se']
for species in ['hound','crawler']:
    shapes=[]
    for row in range(8):
        angle=math.pi/2+row*math.pi/4
        forward=(math.cos(angle),math.sin(angle))
        side=(-forward[1],forward[0])
        for col in range(10):
            dead=col==9
            walk=col in range(2,6)
            bite=col in [6,7]
            def project(x,y,z=0):
                return (col*48+24+forward[0]*x+side[0]*y, row*48+26+(forward[1]*x+side[1]*y)*.60-z)
            def poly(points,color):
                shapes.append('<polygon points="'+' '.join('%g,%g'%project(*p) for p in points)+'" fill="'+color+'"/>')
            # Four distinct grounded feet; death remains a collapsed animal.
            stride=[0,2,0,-2][(col-2)%4] if walk else 0
            height=3 if dead else 9
            for x,y in [(-9,-5),(8,-5),(-9,5),(8,5)]:
                dx=stride if (x*y)>0 else -stride
                poly([(x,y,0),(x+4,y,0),(x+2+dx,y,height),(x-1+dx,y,height)],'#37423d' if species=='hound' else '#343d2c')
            if species=='hound':
                body='#68786e' if col!=8 else '#b77662'
                poly([(-13,-5,height),(-8,-8,height+3),(9,-6,height+4),(13,0,height+4),(8,7,height+3),(-13,5,height)],body)
                poly([(-12,2,height),(-23,4,height+4),(-18,0,height+5),(-9,-2,height)],'#879086')
                head=16+(3 if bite else 0)
                poly([(8,-5,height+1),(head,-5,height+7),(head+5,-3,height+3),(head+5,3,height+3),(head,5,height+7),(8,5,height+1)],'#8e998b')
                poly([(10,-5,height+5),(11,-5,height+13),(16,-4,height+7)],'#47534c')
                poly([(10,4,height+5),(11,5,height+13),(16,4,height+7)],'#47534c')
                for y in [-4,4]: poly([(head,y,height+5),(head+2,y,height+5),(head+2,y,height+3),(head,y,height+3)],'#e9c578')
                if bite: poly([(head+1,-3,height+1),(head+6,0,height),(head+1,3,height+1)],'#deceb2')
            else:
                shell='#697850' if col!=8 else '#bd7652'
                poly([(-16,-6,height),(-10,-10,height+5),(8,-10,height+6),(16,-4,height+4),(16,5,height),(8,10,height),(-10,10,height)],shell)
                poly([(-10,-7,height+7),(0,-8,height+9),(10,-4,height+7),(7,6,height+6),(-7,7,height+5)],'#919166')
                for x in [-7,1,8]: poly([(x,-7,height+7),(x+3,-8,height+8),(x+4,6,height+6),(x+1,7,height+5)],'#414f38')
                head=20+(2 if bite else 0)
                poly([(11,-5,height),(head,-4,height+3),(head+3,0,height+2),(head,5,height+3),(11,6,height)],'#9b9a70')
                for y in [-4,4]:poly([(head-1,y,height+3),(head+1,y,height+3),(head+1,y,height+1),(head-1,y,height+1)],'#efd293')
                poly([(-15,-3,height),(-25,-1,height+1),(-18,3,height+1)],'#68734d')
    art=ROOT/'content/art/original';art.mkdir(parents=True,exist_ok=True)
    (art/(species+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="480" height="384" viewBox="0 0 480 384">'+''.join(shapes)+'</svg>\n')
    clips={'idle':[0,1],'walk':[2,3,4,5],'bite':[6,7],'hurt':[8],'death':[9]}
    cells=sorted({(r,c) for r in range(8) for cols in clips.values() for c in cols})
    s='[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://content/art/original/'+species+'.svg" id="sheet"]\n'
    for row,col in cells:s+=f'[sub_resource type="AtlasTexture" id="f{row}_{col}"]\natlas = ExtResource("sheet")\nregion = Rect2({col*48}, {row*48}, 48, 48)\n'
    s+='[resource]\nanimations = ['+',\n'.join('{"name": &"%s_%s", "speed": 7.0, "loop": %s, "frames": [%s]}'%(clip,direction,'true' if clip in ['idle','walk'] else 'false',', '.join('{"duration": 1.0, "texture": SubResource("f%d_%d")}'%(row,col) for col in cols)) for clip,cols in clips.items() for row,direction in enumerate(DIRECTIONS))+']\n'
    (ROOT/f'content/animations/{species}_frames.tres').write_text(s)
    s=(ROOT/'content/animations/puny_body.tres').read_text().replace('puny_body_frames.tres',species+'_frames.tres').replace('id = &"puny_body"','id = &"'+species+'"').replace('行路者 · 分层实物装备','芦苇猎犬' if species=='hound' else '沼甲兽').replace('frames = &"gesture"','frames = &"bite"')
    s+='body_scale = Vector2(1.8, 1.8)\nbody_offset = Vector2(0, -6)\n'
    (ROOT/f'content/animations/{species}.tres').write_text(s)
print('Built original quadruped frames/profiles')
