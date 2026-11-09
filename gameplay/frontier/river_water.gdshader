shader_type canvas_item;
varying vec2 world;
uniform float presentation_time = 0.0;
void vertex(){world=VERTEX;}
void fragment(){
 float wave=sin(world.x*.027+world.y*.012+presentation_time*.65)*sin(world.y*.037-presentation_time*.42);
 float glint=smoothstep(.80,1.0,wave)*.10;
 vec3 deep=vec3(.14,.26,.28);
 vec3 shallow=vec3(.24,.38,.37);
 float current=sin(world.x*.008+world.y*.006+presentation_time*.19)*.5+.5;
 COLOR=vec4(mix(deep,shallow,current)+glint,1.);
}
