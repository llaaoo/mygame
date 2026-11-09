class_name WorldObjectPresentation
extends Node2D
## Injected read-only state query; the visual has no reference to inventory mutations or callbacks.
signal state_changed(state: String)
@export var profile: WorldAnimationProfile
var query: Callable
var _snapshot: Dictionary={}
var snapshot: Dictionary:
	get: return _snapshot.duplicate(true)
var _age:=0.0
var _sample_clock:=1.0
var _state:=""
var _visual: Node2D
var _poses: AnimationPlayer
var _embers: CPUParticles2D
var _art: Node2D
var _light: PointLight2D
func _ready() -> void:
	if not profile: profile=WorldAnimationProfile.defaults()
	if not profile.validation_errors().is_empty(): set_process(false); return
	_visual=Node2D.new(); _visual.name="Visual"; add_child(_visual); _visual.draw.connect(_draw_visual)
	_poses=AnimationPlayer.new(); _poses.name="Poses"; _poses.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_poses)
	_embers=CPUParticles2D.new(); _embers.name="Embers"; _embers.emitting=false; _embers.one_shot=false
	_embers.use_fixed_seed=true; _embers.seed=7919
	_embers.amount=12; _embers.lifetime=.9; _embers.direction=Vector2.UP; _embers.spread=25
	_embers.initial_velocity_min=12; _embers.initial_velocity_max=24; _embers.gravity=Vector2(0,-8)
	_embers.scale_amount_min=1; _embers.scale_amount_max=2; _embers.color=profile.particle_color
	_visual.add_child(_embers)
	_light=PointLight2D.new(); _light.name="HearthLight"; _light.enabled=false
	_light.texture=preload("res://content/presentation/hearth_light.tres"); _light.texture_scale=1.5; _light.color=Color(1,.75,.45); _light.energy=.45
	_visual.add_child(_light)
	_apply_profile(profile)
	_process(0)
func _apply_profile(definition: WorldAnimationProfile) -> void:
	if not definition or not definition.validation_errors().is_empty(): return
	profile=definition
	if _poses.has_animation_library(""): _poses.remove_animation_library("")
	_poses.add_animation_library("",profile.poses)
	if is_instance_valid(_art): _art.queue_free()
	_art=PresentationScene.attach(_visual,profile.visual_scene) if profile.visual_scene else null
	_embers.color=profile.particle_color
	_state=""
func has_body_art() -> bool: return is_instance_valid(_art)
func _process(delta: float) -> void:
	_age+=maxf(0,delta); _sample_clock+=delta
	if _sample_clock>=.12:
		_sample_clock=0
		if query.is_valid(): _snapshot=query.call().duplicate(true)
		var definition:=_snapshot.get("profile") as WorldAnimationProfile
		if not definition: definition=WorldAnimationProfile.defaults()
		if definition!=profile: _apply_profile(definition)
		var state:=str(_snapshot.get("state","idle"))
		if state not in ["idle","active","depleted","complete"]: state="idle"
		if state!=_state:
			var first:=_state.is_empty(); _state=state; _age=1 if first and state=="complete" else 0
			_poses.play("RESET"); _poses.advance(0); _poses.play(state); _poses.advance(0); _poses.pause()
			state_changed.emit(state)
			if get_parent() is CanvasItem: get_parent().queue_redraw()
	var reduced:=bool(PresentationPreferences.value("reduced_motion"))
	var progress:=minf(1,_age/.35) if _state in ["complete","depleted"] else fposmod(_age,1) if not reduced else 0.0
	_poses.seek(progress*_poses.get_animation(_state).length,true,true)
	var camera:=get_viewport().get_camera_2d()
	var in_view:=not camera or global_position.distance_to(camera.get_screen_center_position())<1000
	visible=in_view
	_embers.position=_snapshot.get("offset",Vector2.ZERO)
	var amount: int=[6,12,18][int(PresentationPreferences.value("effects_quality"))]
	if _embers.amount!=amount: _embers.amount=amount
	_embers.emitting=in_view and _state=="active" and _snapshot.get("kind","")=="hearth" and not reduced
	_embers.speed_scale=0 if reduced else 1
	_light.position=_embers.position
	_light.enabled=in_view and _state=="active" and _snapshot.get("kind","")=="hearth"
	_light.energy=.45 if reduced else .45+sin(_age*4.5)*.025
	_visual.queue_redraw()
func _draw_visual() -> void:
	var color: Color=_snapshot.get("color",Color("dbbf7c"))
	var offset: Vector2=_snapshot.get("offset",Vector2.ZERO)
	var kind:=str(_snapshot.get("kind","note"))
	if kind=="hearth" and _state=="active":
		_visual.draw_circle(offset,27,Color(1,.62,.23,.09))
		_visual.draw_circle(offset+Vector2(0,-5),13,Color(1,.76,.35,.12))
	elif kind=="water":
		for i in range(2): _visual.draw_arc(Vector2(0,-6),9+i*6,PI*.1,PI*.9,20,Color("91bbc2",.5),1,true)
	elif kind=="forage" and _state!="depleted":
		for i in range(3):
			var p:=Vector2(-10+i*10,-18-abs(i-1)*3)
			_visual.draw_line(p+Vector2(0,12),p,Color("7b9c65"),1.5,true)
			_visual.draw_circle(p,3,Color("a5b781"))
	elif kind=="mechanism":
		_visual.draw_arc(Vector2(0,-5),16,0,TAU,32,Color(color,.55),1.5,true)
		if _state=="complete": _visual.draw_polyline(PackedVector2Array([Vector2(-7,-5),Vector2(-1,1),Vector2(10,-11)]),Color("9dc896"),2,true)
	elif bool(_snapshot.get("focused",false)):
		_visual.draw_arc(Vector2.ZERO,29,0,TAU,32,Color(color,.4),1,true)

