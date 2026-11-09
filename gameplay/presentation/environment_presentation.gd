class_name EnvironmentPresentation
extends Node2D
## Cosmetic lighting and camera-bounded motes, reading the authoritative world hour.
var profile: EnvironmentProfile
var hour_query: Callable
var preview_hour := -1.0 # Used only by the isolated presentation lab, never writes WorldTime.
var phase:=0.0
var lighting: CanvasModulate
func _ready() -> void:
	z_index=50
	lighting=CanvasModulate.new(); lighting.name="Daylight"; add_child(lighting)
func _process(delta: float) -> void:
	var motion:=PresentationPreferences.motion_scale()
	phase+=maxf(0,delta)*motion
	var hour:=preview_hour if preview_hour>=0 else float(hour_query.call()) if hour_query.is_valid() else 12.0
	var sun:=smoothstep(5,8,hour)*(1-smoothstep(17,21,hour))
	lighting.color=profile.night.lerp(profile.daylight,sun)
	queue_redraw()
func _draw() -> void:
	if not profile or PresentationPreferences.value("reduced_motion"): return
	var camera:=get_viewport().get_camera_2d()
	if not camera: return
	var rect:=Rect2(camera.get_screen_center_position()-get_viewport_rect().size/camera.zoom*.5,get_viewport_rect().size/camera.zoom)
	var count:=mini(profile.motes,4+int(PresentationPreferences.value("effects_quality"))*8)
	for i in range(count):
		var p:=rect.position+Vector2(fposmod(i*137.1+phase*(5 if profile.wind else 1),rect.size.x),fposmod(i*79.7-phase*3,rect.size.y))
		draw_line(p,p+Vector2(3,1) if profile.wind else p+Vector2(0,2),profile.ambient_color,1,true)

