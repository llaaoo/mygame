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
	if _clock>0 or actor.attack_preparation.busy() or actor.actor_context and actor.actor_context.actions.busy(): return result
	_clock = INTERVAL
	var controller := actor.skill_manager.combinations
	var dist := actor.global_position.distance_to(target.global_position)
	if actor.actor_context and actor.actor_context.actions.active():
		var actions:=actor.actor_context.actions
		var store:=actor.actor_context.items
		var owner_id:=actor.actor_context.id
		var weapon_uid:=str(store.equipped(owner_id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
		if dist>90 and not weapon_uid.is_empty() and not store.coating(weapon_uid) and store.can_pay(owner_id,{"poison_rag":1},true):
			var coat:=Action.new(); coat.action_type=Action.ActionType.USE_ITEM; coat.skill_id="poison_rag"; return [coat]
		if dist>140 and dist<320 and store.can_pay(owner_id,{"venom_bottle":1},true):
			if actor.actor_context.item_actions.begin("venom_bottle",false,actor.get_target_direction()): return result
		if dist<115 and not find_source("disperse").is_empty() and store.can_pay(owner_id,{"venom_sprayer":1},true):
			var spray:=cast("venom_mist",target)
			if spray: return [spray]
		if actions.stamina.current<24:
			if dist>actor.attack_range*2 and actions.item_request.is_valid() and actor.actor_context.items.can_pay(actor.actor_context.id,{"clean_water":1},true):
				var use:=Action.new(); use.action_type=Action.ActionType.USE_ITEM; use.skill_id="clean_water"; return [use]
			var guard:=Action.new(); guard.action_type=Action.ActionType.GUARD; guard.params["held"]=dist<actor.attack_range*1.7; guard.direction=actor.get_target_direction()
			return [guard,Action.move(-actor.get_target_direction()*.5,actor)]
		if dist>actor.attack_range and actor.actor_context.region.navigation:
			var route:=actor.actor_context.region.navigation.direction(actor.position,target.position)
			if route.length_squared()>.01 and not actor.surface_awareness.should_evade and actor.ai_role==Enemy.AIRole.MELEE: return [Action.move(route,actor)]
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
	if actor.ai_role==Enemy.AIRole.MELEE and not buffs.has_buff("focus"):
		var focus := cast("focus",target)
		if focus: return [focus]
	# No usable spell: approach for an ordinary weapon hit; never conjure resources.
	return [Action.move(actor.get_target_direction(),actor)]

func find_source(id: String) -> String:
	if actor.skill_manager.material_operations: id=SpellOperationCatalog.default_catalog().canonical(id)
	for source in ["left","right","slot_0","slot_1","slot_2","slot_3","slot_4","slot_5"]:
		var instance := actor.skill_manager.get_instance(source)
		if instance and instance.data.get_id()==id: return source
	return ""
func cast(id: String,target: Node2D,empower:=false,at_self:=false) -> Action:
	var source := find_source(id)
	if source.is_empty(): return null
	var skill := actor.skill_manager.get_instance(source).data
	if actor.skill_manager.material_operations and not skill.operation_id.is_empty():
		var payload: String={"fire_sigil":"ember","frost_sigil":"frost","storm_sigil":"storm","venom_mist":"venom","poison_cloud":"venom","oil_flask":"resin"}.get(id,"")
		if not payload.is_empty(): actor.skill_manager.combinations.supplies.select_payload(skill,payload,actor.skill_manager)
		if id=="focus":
			var sources:=actor.skill_manager.combinations.live_fields()
			var choice: String="basic"
			for field in sources:
				if field.is_available_to(actor): choice="attune_"+field.field_type; break
			actor.skill_manager.combinations.supplies.select_payload(skill,choice,actor.skill_manager)
	var context := CastContext.at_position(actor,actor.global_position if at_self else target.global_position,skill)
	context.target=target
	context.requires_live_target=true
	context.empower=empower
	if not actor.skill_manager.can_start(source,actor,context): return null
	var action := Action.cast(source,context.direction,actor)
	action.target=target
	action.cast_context=context
	return action
