shader_type canvas_item;
render_mode unshaded;
varying vec2 world;
void vertex(){world=VERTEX;}
void fragment(){
 float wave=sin(world.x*.027+world.y*.012+TIME*.65)*sin(world.y*.037-TIME*.42);
 float glint=smoothstep(.80,1.0,wave)*.10;
 vec3 deep=vec3(.14,.26,.28);
 vec3 shallow=vec3(.24,.38,.37);
 float current=sin(world.x*.008+world.y*.006+TIME*.19)*.5+.5;
 COLOR=vec4(mix(deep,shallow,current)+glint,1.);
}
