class_name EnemyCharacterBrain
extends RefCounted
## Chooses one base action at a time. No stored combo, free setup or resource grant.
const INTERVAL := 0.25
var actor: Enemy
var _clock := 0.0
var _reposition := 0.0
func _init(owner_actor: Enemy) -> void: actor = owner_actor
func tick(delta: float) -> void:
	_clock = maxf(0,_clock-delta)
	_reposition = maxf(0,_reposition-delta)
func refused() -> void: _reposition = 1.0
func choose(target: Node2D) -> Array[Action]:
	var result: Array[Action] = []
	if _clock>0 or actor.attack_preparation.busy(): return result
	_clock = INTERVAL
	var controller := actor.skill_manager.combinations
	var dist := actor.global_position.distance_to(target.global_position)
	if actor.surface_awareness.should_evade:
		controller.cancel("危险地面：移动中断准备")
		return [Action.move(actor.surface_awareness.direction,actor)]
	if controller.is_busy(): return result
	var buffs := actor.get_node("BuffManager") as BuffManager
	if buffs.has_buff("burning") or buffs.has_buff("poison"):
		var wash := cast("water_call",target,false,true)
		if wash: return [wash]
	if dist<=actor.attack_range:
		if actor.attack_ready and actor._attack_timer>=actor.attack_cooldown: return [Action.melee(actor)]
		return result
	if actor.ai_role in [Enemy.AIRole.RANGED,Enemy.AIRole.HYBRID] and _reposition<=0 and dist<=actor.ranged_preferred_range:
		var spark := find_source("ignite")
		if not spark.is_empty():
			var plan := controller.preview(actor.skill_manager.get_instance(spark).data,actor)
			if not plan.rule_id.is_empty():
				# A live field is a real opportunity. A boon costs its own charge and MP.
				if not buffs.has_buff("ember_focus"):
					var focus := cast("focus",target)
					if focus:
						var focus_plan:=controller.preview(actor.skill_manager.get_instance(focus.skill_source).data,actor)
						if actor.mana_component.mp>=plan.cost+focus_plan.cost: return [focus]
				var health := target.get_node_or_null("HealthComponent") as HealthComponent
				var release := health and health.hp<float(health.max_hp)*.4 and buffs.has_buff("ember_focus")
				var shot := cast("ignite",target,release)
				if not shot and release: shot=cast("ignite",target)
				if shot: return [shot]
				if actor.mana_component.mp<plan.cost: return [Action.move(actor.get_target_direction(),actor)]
				return result # Wait for cooldown while keeping position inside the field.
			var placement := cast("fire_sigil",target)
			if placement:
				var placement_plan:=controller.preview(actor.skill_manager.get_instance(placement.skill_source).data,actor)
				for rule in controller.rule_index.for_action("ignite"):
					if rule.required_field_type!="fire" or not controller.learned_rules.has(rule.id): continue
					var shot_cost:=actor.skill_manager.effective_mana_cost(rule.result_skill,actor,rule.mana_cost)
					if actor.mana_component.mp>=placement_plan.cost+shot_cost: return [placement]
	if actor.ai_role!=Enemy.AIRole.RANGED and not buffs.has_buff("focus"):
		var focus := cast("focus",target)
		if focus: return [focus]
	# No usable spell: approach for an ordinary weapon hit; never conjure resources.
	return [Action.move(actor.get_target_direction(),actor)]

func find_source(id: String) -> String:
	for source in ["left","right","slot_0","slot_1","slot_2","slot_3","slot_4","slot_5"]:
		var instance := actor.skill_manager.get_instance(source)
		if instance and instance.data.get_id()==id: return source
	return ""
func cast(id: String,target: Node2D,empower:=false,at_self:=false) -> Action:
	var source := find_source(id)
	if source.is_empty(): return null
	var skill := actor.skill_manager.get_instance(source).data
	var context := CastContext.at_position(actor,actor.global_position if at_self else target.global_position,skill)
	context.target=target
	context.requires_live_target=true
	context.empower=empower
	if not actor.skill_manager.can_start(source,actor,context): return null
	var action := Action.cast(source,context.direction,actor)
	action.target=target
	action.cast_context=context
	return action
