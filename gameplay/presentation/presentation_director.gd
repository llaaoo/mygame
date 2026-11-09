class_name PresentationDirector
extends Node2D
## Scene-owned composition. Observes committed facts; never publishes commands or persists effects.
var catalog: PresentationCatalog
var actor: CharacterBody2D
var actor_query: Callable
var hour_query: Callable
var environment: EnvironmentPresentation
var camera_feedback: CameraFeedback
var audio: PresentationAudio
var scope: Node2D
var generation:=0
var emitted:=0
var dropped:=0
var _effects: Array[TransientVisual]=[]
var _recent: Dictionary={}
var _facts: GameplayFacts
var _bus: CombatEventBus
var _executor: CombatExecutor
var _observers: Array[SkillManager]=[]
var _rigs: Array[ActorAnimationController]=[]
var _transition: ColorRect
var _fade: Tween
static func for_node(node: Node) -> PresentationDirector:
	if not is_instance_valid(node) or not node.is_inside_tree(): return null
	var ancestor:=node
	while is_instance_valid(ancestor):
		var director:=ancestor.get_node_or_null("Presentation") as PresentationDirector
		if director and director.is_inside_tree(): return director
		ancestor=ancestor.get_parent()
	return null
func _ready() -> void:
	PresentationPreferences.load_preferences()
	if not catalog: catalog=PresentationCatalog.defaults()
	audio=PresentationAudio.new(); add_child(audio)
	var overlay:=CanvasLayer.new(); overlay.layer=2; add_child(overlay)
	_transition=ColorRect.new(); _transition.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _transition.color=Color(.07,.10,.12,0)
	overlay.add_child(_transition)
func configure(player: CharacterBody2D,facts: GameplayFacts,lookup: Callable,clock: Callable) -> void:
	_unbind()
	actor=player; actor_query=lookup; hour_query=clock; _facts=facts
	_facts.committed.connect(_fact)
	_bus=CombatEventBus.instance
	if _bus:
		_bus.subscribe(CombatEvent.Type.ON_DAMAGE,_damage)
		_bus.subscribe(CombatEvent.Type.ON_HIT,_hit)
	_executor=CombatExecutor.instance
	if _executor: _executor.defense_resolved.connect(_defense)
	camera_feedback=CameraFeedback.new(); camera_feedback.camera=actor.get_node_or_null("Camera2D") as Camera2D
	add_child(camera_feedback)
func leave_region() -> void:
	generation+=1
	_clear_observers()
	for effect in _effects:
		if is_instance_valid(effect): effect.queue_free()
	_effects.clear(); _recent.clear()
	if audio: audio.clear()
	if camera_feedback: camera_feedback.clear()
	if is_instance_valid(environment): environment.queue_free()
	environment=null; scope=null
	if _fade and _fade.is_valid(): _fade.kill()
	if _transition: _transition.color.a=0
func enter_region(root: Node2D,profile: EnvironmentProfile) -> void:
	leave_region(); scope=root
	environment=EnvironmentPresentation.new(); environment.profile=profile; environment.hour_query=hour_query
	root.add_child(environment)
	for group in ["player","enemy","npc"]:
		for node in get_tree().get_nodes_in_group(group): _observe(node)
	if not PresentationPreferences.value("reduced_motion"):
		_transition.color.a=.18
		_fade=create_tween(); _fade.tween_property(_transition,"color:a",0.0,.24)
func emit_cue(id: StringName,point: Vector2,token: String="",sound_override: AudioStream=null,visual_override: PackedScene=null) -> bool:
	if not is_inside_tree(): return false
	var definition:=catalog.cue(id)
	if not definition or not point.is_finite(): return false
	if visual_override and not PresentationScene.validation_errors(visual_override).is_empty(): return false
	if not token.is_empty() and _recent.has(token): return false
	if definition.channel=="world":
		if not is_instance_valid(scope) or scope.is_queued_for_deletion(): return false
		var camera:=get_viewport().get_camera_2d()
		if camera and camera.get_screen_center_position().distance_to(point)>1100: dropped+=1; return false
		_prune()
		if (definition.radius>0 or definition.frames or definition.visual_scene or visual_override) and _effects.size()>=PresentationPreferences.effect_limit():
			var victim: TransientVisual
			for effect in _effects:
				if effect.definition.priority<definition.priority: victim=effect; break
			if not victim: dropped+=1; return false
			_effects.erase(victim); victim.queue_free()
		if definition.radius>0 or definition.frames or definition.visual_scene or visual_override:
			var visual:=TransientVisual.new(); visual.definition=definition; visual.visual_override=visual_override
			scope.add_child(visual); visual.global_position=point; _effects.append(visual)
	if not token.is_empty():
		_recent[token]=true
		if _recent.size()>128: _recent.erase(_recent.keys()[0])
	audio.play(definition,point,sound_override); emitted+=1
	return true
func _prune() -> void:
	_effects=_effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
func snapshot() -> Dictionary:
	_prune()
	return {"generation":generation,"effects":_effects.size(),"emitted":emitted,"dropped":dropped,"voices":audio._voices.size() if audio else 0}
func _process(_delta: float) -> void:
	_prune()
	while _effects.size()>PresentationPreferences.effect_limit():
		var effect: TransientVisual=_effects.pop_front(); effect.queue_free()
	if PresentationPreferences.value("reduced_motion") and _transition:
		if _fade and _fade.is_valid(): _fade.kill()
		_transition.color.a=0
func _fact(fact: Dictionary) -> void:
	var id: String={"recipe_crafted":"craft","production_completed":"craft","field_work_completed":"harvest","item_action_committed":"item","item_used":"item","technique_learned":"discovery","pack_dropped":"item","pack_recovered":"item","physical_action_released":"weapon"}.get(str(fact.kind),"")
	if fact.kind=="field_work_completed": id="craft" if fact.data.get("kind")=="cook" else "harvest" if fact.data.get("kind") in ["harvest","fill"] else "item"
	if id.is_empty() or not actor_query.is_valid(): return
	var source:=actor_query.call(str(fact.source)) as Node2D
	if not is_instance_valid(source): return
	emit_cue(StringName(id),source.global_position,"fact:"+str(fact.sequence))
func _cast(plan: CastPlan) -> void:
	var caster:=plan.actor if is_instance_valid(plan.actor) else actor
	if not is_instance_valid(caster) or not plan.skill: return
	var sound:=plan.skill.visual.sound_cast if plan.skill.visual else null
	if not sound and plan.skill.aoe_visual: sound=plan.skill.aoe_visual.sound_cast
	emit_cue(&"cast",caster.global_position,"cast:"+str(caster.get_instance_id())+":"+str(plan.execution_id),sound)
func _damage(event: CombatEvent) -> void:
	if not is_instance_valid(event.target) or not event.target is Node2D or int(event.data.get("damage",0))<=0: return
	if event.target==actor and camera_feedback: camera_feedback.kick(2.0+minf(3,float(event.data.damage)*.08))
func _hit(event: CombatEvent) -> void:
	if not is_instance_valid(event.target) or not event.target is Node2D or "dot" in event.data.get("tags",[]): return
	var skill:=event.skill
	var sound:=skill.visual.sound_hit if skill and skill.visual else null
	emit_cue(&"spell_hit" if skill else &"impact",event.target.global_position,"",sound)
func _defense(target: Node2D,outcome: Dictionary) -> void:
	if is_instance_valid(target) and (outcome.get("blocked",false) or outcome.get("parried",false)): emit_cue(&"defense",target.global_position)
func _unbind() -> void:
	_clear_observers()
	if _facts and _facts.committed.is_connected(_fact): _facts.committed.disconnect(_fact)
	if is_instance_valid(_bus):
		_bus.unsubscribe(CombatEvent.Type.ON_DAMAGE,_damage)
		_bus.unsubscribe(CombatEvent.Type.ON_HIT,_hit)
	if is_instance_valid(_executor) and _executor.defense_resolved.is_connected(_defense): _executor.defense_resolved.disconnect(_defense)
	if is_instance_valid(camera_feedback): camera_feedback.queue_free()
	_facts=null; _bus=null; _executor=null
func _observe(node: Node) -> void:
	var manager:=node.get_node_or_null("SkillManager") as SkillManager
	if manager and manager not in _observers:
		_observers.append(manager); manager.cast_committed.connect(_cast)
	var visual:=node.get_node_or_null("EquipmentVisual") as ActorEquipmentVisual
	if visual and visual.animator and visual.animator not in _rigs:
		_rigs.append(visual.animator); visual.animator.cue_emitted.connect(_rig_cue.bind(weakref(node)))
func _rig_cue(kind: String,token: String,source: WeakRef) -> void:
	var node:=source.get_ref() as Node2D
	if kind=="footstep" and is_instance_valid(node): emit_cue(&"footstep",node.global_position,"step:"+token)
func _clear_observers() -> void:
	for manager in _observers:
		if is_instance_valid(manager) and manager.cast_committed.is_connected(_cast): manager.cast_committed.disconnect(_cast)
	for rig in _rigs:
		if not is_instance_valid(rig): continue
		for connection in rig.cue_emitted.get_connections():
			var callback: Callable=connection.callable
			if callback.get_object()==self: rig.cue_emitted.disconnect(callback)
	_observers.clear(); _rigs.clear()
func _exit_tree() -> void:
	_unbind()
	if _fade and _fade.is_valid(): _fade.kill()

