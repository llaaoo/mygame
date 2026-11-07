shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec4 base=COLOR;
 float value=dot(base.rgb,vec3(.299,.587,.114));
 COLOR=vec4(mix(vec3(value),base.rgb,.43)*vec3(1.01,1.0,.97),base.a);
}
