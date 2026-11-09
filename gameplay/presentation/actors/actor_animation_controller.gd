class_name ActorAnimationController
extends Node2D
## Owns only this actor's presentation clock and native Godot players. No animation-finished gameplay gates.
signal cue_emitted(kind: String,token: String)
@export var profile: ActorAnimationProfile
var actor: CharacterBody2D
var preview: Dictionary={}
var _current: Dictionary={}
var current: Dictionary:
	get: return _current.duplicate()
var resolved_clip: ActorAnimationClip
var direction_index := 0
var aim_direction:=Vector2.DOWN
var _reaction := 0.0
var _death_age := 0.0
var _loop_clock := 0.0
var _distance := 0.0
var _last_position:=Vector2.INF
var _last_state := ""
var _release_token := ""
var _facts: GameplayFacts
var _context_id := ""
var _cast_age := 1.0
var _cast_serial := 0
var _cast_operation := -1
var _combat_bus: CombatEventBus
var _manager: SkillManager
@onready var rig: Node2D=$Reaction/Rig
@onready var body: AnimatedSprite2D=$Reaction/Rig/Body
@onready var sockets: Node2D=$Reaction/Rig/Sockets
@onready var main_hand: Marker2D=$Reaction/Rig/Sockets/MainHand
@onready var off_hand: Marker2D=$Reaction/Rig/Sockets/OffHand
@onready var poses: AnimationPlayer=$PosePlayer
func _ready() -> void:
	if not profile: profile=preload("res://content/animations/puny_body.tres")
	if not set_profile(profile): set_profile(preload("res://content/animations/puny_body.tres"))
	if is_instance_valid(actor):
		_last_position=actor.global_position
		_manager=actor.get_node_or_null("SkillManager") as SkillManager
		if _manager: _manager.cast_committed.connect(_cast_committed)
	render(0)
func set_profile(definition: ActorAnimationProfile) -> bool:
	if not definition or not definition.validation_errors().is_empty(): return false
	if is_instance_valid(actor) and (not definition.equipment_free or definition not in ActorAnimationCatalog.default_catalog().profiles): return false
	profile=definition
	if not is_instance_valid(body) or not is_instance_valid(poses): return true
	body.sprite_frames=profile.sprite_frames; body.scale=profile.body_scale; body.position=profile.body_offset
	if poses.has_animation_library(""): poses.remove_animation_library("")
	poses.add_animation_library("",profile.poses)
	poses.play("RESET"); poses.advance(0); poses.pause()
	_last_state=""
	return true
func _damage_applied(event: CombatEvent) -> void:
	if is_instance_valid(actor) and event.target==actor and int(event.data.get("damage",0))>0: _reaction=.18
func _cast_committed(_plan: CastPlan) -> void:
	_cast_age=0; _cast_serial+=1
	var context: ActorContext=actor.get("actor_context") if is_instance_valid(actor) and "actor_context" in actor else null
	_cast_operation=context.actions.operation_id if context and context.actions else -1
	cue_emitted.emit("cast_release","cast:"+str(_cast_serial))
func _bind_facts() -> void:
	var bus:=CombatEventBus.instance if is_instance_valid(actor) else null
	if bus!=_combat_bus:
		if is_instance_valid(_combat_bus): _combat_bus.unsubscribe(CombatEvent.Type.ON_DAMAGE,_damage_applied)
		_combat_bus=bus
		if _combat_bus: _combat_bus.subscribe(CombatEvent.Type.ON_DAMAGE,_damage_applied)
	var context: ActorContext=actor.get("actor_context") if is_instance_valid(actor) and "actor_context" in actor else null
	if context and context.actions and context.actions.operation_id!=_cast_operation: _cast_age=1.0
	var facts:=context.facts if context else null
	_context_id=context.id if context else ""
	if facts==_facts: return
	if _facts and _facts.committed.is_connected(_fact_committed): _facts.committed.disconnect(_fact_committed)
	_facts=facts
	if _facts: _facts.committed.connect(_fact_committed)
func _fact_committed(fact: Dictionary) -> void:
	if fact.source!=_context_id or fact.kind!="physical_action_released": return
	var token:=str(fact.data.get("family",""))
	if token==_release_token: return
	_release_token=token; cue_emitted.emit("weapon_release",token)
func _exit_tree() -> void:
	if is_instance_valid(_combat_bus): _combat_bus.unsubscribe(CombatEvent.Type.ON_DAMAGE,_damage_applied)
	if _facts and _facts.committed.is_connected(_fact_committed): _facts.committed.disconnect(_fact_committed)
func _process(delta: float) -> void: render(delta)
func render(delta: float) -> void:
	if not is_node_ready() or not profile or not body.sprite_frames: return
	_bind_facts()
	_loop_clock+=maxf(0,delta)*PresentationPreferences.motion_scale(); _cast_age+=maxf(0,delta)
	_reaction=maxf(0,_reaction-delta)
	var snapshot: Dictionary=preview.duplicate() if not preview.is_empty() else ActorPresentationSnapshot.capture(actor) if is_instance_valid(actor) else {"state":"idle","phase":"loop","direction":Vector2.DOWN,"token":"idle"}
	var state:=str(snapshot.get("state","idle"))
	var token:=str(snapshot.get("token",state))
	if state=="death":
		_death_age+=maxf(0,delta)
		snapshot["progress"]=float(snapshot.get("progress",minf(1,_death_age/.55)))
	else: _death_age=0
	# Minor damage overlays an existing action. Stagger/death replace it; healing never causes flinches.
	if state in ["idle","walk","sprint"] and _reaction>0: state="hurt"; snapshot={"state":state,"phase":"whole","progress":1-_reaction/.18,"direction":snapshot.get("direction",Vector2.DOWN),"token":"hurt"}
	elif state in ["idle","walk","sprint"] and _cast_age<.24: state="cast"; snapshot={"state":state,"phase":"recovery","progress":_cast_age/.24,"direction":snapshot.get("direction",Vector2.DOWN),"token":"cast:"+str(_cast_serial)}
	resolved_clip=profile.resolve(StringName(state))
	if not resolved_clip: body.visible=false; return
	body.visible=true
	var direction: Vector2=snapshot.get("direction",Vector2.DOWN)
	aim_direction=direction.normalized() if direction.is_finite() and direction.length_squared()>.001 else Vector2.DOWN
	direction_index=ActorAnimationProfile.direction_index(aim_direction)
	var key:=StringName(str(resolved_clip.frames)+"_"+ActorAnimationProfile.DIRECTIONS[direction_index])
	if not body.sprite_frames.has_animation(key): return
	var phase:=str(snapshot.get("phase","whole"))
	var progress:=clampf(float(snapshot.get("progress",0)),0,1)
	var normalized:=resolved_clip.sample(phase,progress)
	var previous_cycle:=_distance/profile.stride_distance
	if phase=="loop":
		if is_instance_valid(actor) and state in ["walk","sprint"]:
			if _last_position!=Vector2.INF:
				var moved:=actor.global_position.distance_to(_last_position)
				if moved<100: _distance+=moved # Teleports do not generate footsteps.
			normalized=fposmod(_distance/profile.stride_distance,1)
		else: normalized=fposmod(_loop_clock*(.6 if state=="idle" else 1.5),1)
	if is_instance_valid(actor): _last_position=actor.global_position
	body.animation=key; body.pause()
	var total:=0.0
	for index in body.sprite_frames.get_frame_count(key): total+=body.sprite_frames.get_frame_duration(key,index)
	var sample:=minf(normalized*total,maxf(0,total-.000001))
	for index in body.sprite_frames.get_frame_count(key):
		var duration:=body.sprite_frames.get_frame_duration(key,index)
		if sample<duration or index==body.sprite_frames.get_frame_count(key)-1:
			body.set_frame_and_progress(index,clampf(sample/duration,0,1)); break
		sample-=duration
	if str(poses.assigned_animation)!=str(resolved_clip.pose):
		poses.play("RESET"); poses.advance(0)
		poses.play(resolved_clip.pose); poses.advance(0); poses.pause()
	poses.seek(normalized*poses.get_animation(resolved_clip.pose).length,true,true)
	sockets.rotation=aim_direction.angle()-PI*.5
	$Reaction.position=Vector2(sin(_reaction*95)*_reaction*6*PresentationPreferences.motion_scale(),0) if _reaction>0 else Vector2.ZERO
	if is_instance_valid(actor) and state in ["walk","sprint"] and _last_state in ["walk","sprint"]:
		var cycle:=_distance/profile.stride_distance
		for marker in resolved_clip.footsteps:
			if floorf(previous_cycle-marker)<floorf(cycle-marker): cue_emitted.emit("footstep","walk:"+_context_id+":"+str(floori(cycle))+":"+str(marker))
	_last_state=state
	_current={"state":state,"resolved":str(resolved_clip.id),"phase":phase,"progress":progress,"normalized":normalized,"direction":direction_index,"frame":body.frame,"token":token}
func socket_position(key: StringName) -> Vector2:
	return to_local((off_hand if key==&"off_hand" else main_hand).global_position)
