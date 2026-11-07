shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec2 p=UV*2.-1.;
 float edge=smoothstep(.35,1.45,length(p*vec2(.85,1.)));
 COLOR=vec4(.025,.055,.065,edge*.25);
}
