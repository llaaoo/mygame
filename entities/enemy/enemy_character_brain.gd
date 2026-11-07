class_name EnemyCharacterBrain
extends RefCounted
## Chooses one base action at a time. No stored combo, free setup or resource grant.
const INTERVAL := 0.1
var actor: Enemy
var _clock := 0.0
var _reposition := 0.0
var _defense_cooldown := 0.0
var _guard_remaining := 0.0
var _offense_cooldown := 0.0
var _observed_target := 0
var _observed_serial := -1
var _observation_age := 0.0
var _own_serial := -1
var _tempo:=CombatTemperament.new()
func _init(owner_actor: Enemy) -> void:
	actor = owner_actor
	if actor.character_definition and actor.character_definition.temperament: _tempo=actor.character_definition.temperament
func tick(delta: float) -> void:
	_clock = maxf(0,_clock-delta)
	_reposition = maxf(0,_reposition-delta)
	_defense_cooldown=maxf(0,_defense_cooldown-delta)
	_guard_remaining=maxf(0,_guard_remaining-delta)
	_offense_cooldown=maxf(0,_offense_cooldown-delta)
	_observation_age+=delta
	if actor.actor_context:
		var observation:=actor.actor_context.actions.attack_observation()
		if not observation.is_empty() and int(observation.serial)!=_own_serial:
			_own_serial=int(observation.serial)
			var strike:=actor.actor_context.actions.profile
			_offense_cooldown=strike.windup+strike.active+strike.recovery+_tempo.attack_pause
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
		if actor.surface_awareness.should_evade:
			controller.cancel("危险地面：移动中断准备")
			return [Action.move(actor.surface_awareness.direction,actor)]
		# Observation of visible windup and guard, never the target's pending input.
		var target_context:=target.get("actor_context") as ActorContext
		var visible:=actor.can_see(target)
		if visible: actor._last_seen_position=target.global_position
		if not visible:
			actions.guarding=false
			if actor.actor_context.region.navigation: return [Action.move(actor.actor_context.region.navigation.direction(actor.position,actor._last_seen_position if actor._last_seen_position.is_finite() else actor.position),actor)]
			return result
		var observation:=target_context.actions.attack_observation() if target_context else {}
		if observation.is_empty(): _observed_serial=-1
		elif target.get_instance_id()!=_observed_target or int(observation.serial)!=_observed_serial:
			_observed_target=target.get_instance_id(); _observed_serial=int(observation.serial); _observation_age=0
		var threatened:=_threatens(observation,target)
		if threatened and float(observation.windup)>0 and _observation_age<_tempo.reaction_delay:
			actions.movement=Vector2.ZERO
			return result
		if _guard_remaining>0 and actions.can_guard() and actions.stamina.current>20:
			return [_guard(target)]
		if threatened and _observation_age>=_tempo.reaction_delay and _defense_cooldown<=0 and float(observation.windup)>0 and actions.stamina.current>28:
			_defense_cooldown=_tempo.defense_interval
			if observation.heavy:
				var side:=_safe_side(target)
				if not side.is_zero_approx(): return [Action.dodge(side,actor)]
			if actions.can_guard():
				_guard_remaining=_tempo.guard_duration
				return [_guard(target)]
		actions.guarding=false
		if actions.stamina.current<actions.stamina.maximum*_tempo.retreat_fraction:
			if dist>actor.attack_range*2 and actions.needs.water_remaining<=0 and store.can_pay(owner_id,{"clean_water":1},true):
				var drink:=Action.new(); drink.action_type=Action.ActionType.USE_ITEM; drink.skill_id="clean_water"; return [drink]
			return [Action.move(-actor.get_target_direction()*.65,actor)]
		var weapon:=store.equipment_definition(weapon_uid)
		var reach:=weapon.moveset.attacks[0].reach if weapon and weapon.moveset and not weapon.moveset.attacks.is_empty() else actor.attack_range
		if weapon and weapon.moveset and weapon.moveset.weapon_type=="bow" and store.can_pay(owner_id,{"arrow":1},true):
			if dist<140: return [Action.move(-actor.get_target_direction(),actor)]
			if dist<=reach and _offense_cooldown<=0:
				if not shot_lane_clear(target): return _reposition_for_shot(target)
				var shot:=Action.melee(actor); shot.direction=actor.get_target_direction(); return [shot]
		if dist<=reach and (_offense_cooldown>0 or _ally_striking(target)):
			var backstep:=clampf((reach*_tempo.preferred_reach-dist)/maxf(1,reach),.2,.7)
			return [Action.move(actor.get_target_direction().orthogonal()*.35-actor.get_target_direction()*backstep,actor)]
		if dist<=reach and weapon and weapon.world_shape in ["blade","spear","staff"]:
			if _crowded(target): return _reposition_for_shot(target)
			if target_context and target_context.actions.guarding and actions.stamina.current>40:
				var heavy:=Action.new(); heavy.action_type=Action.ActionType.HEAVY_ATTACK; heavy.direction=actor.get_target_direction(); return [heavy]
			if actions.stamina.current>=16: return [Action.melee(actor)]
		# A visible preparation in striking distance invites pressure, not free setup.
		if target_context and target_context.actor.get_node("SkillManager").combinations.is_busy() and dist<180 and actions.stamina.current>24:
			return [Action.move(actor.get_target_direction(),actor)]

		if dist>90 and not weapon_uid.is_empty() and not store.coating(weapon_uid) and store.can_pay(owner_id,{"poison_rag":1},true):
			var coat:=Action.new(); coat.action_type=Action.ActionType.USE_ITEM; coat.skill_id="poison_rag"; return [coat]
		if dist>140 and dist<320 and store.can_pay(owner_id,{"venom_bottle":1},true):
			if actor.actor_context.item_actions.begin("venom_bottle",false,actor.get_target_direction()): return result
		if dist<115 and not find_source("disperse").is_empty() and store.can_pay(owner_id,{"venom_sprayer":1},true):
			var spray:=cast("venom_mist",target)
			if spray: return [spray]
		if actor.ai_role==Enemy.AIRole.RANGED and dist<actor.ranged_preferred_range*.45:
			return [Action.move(-actor.get_target_direction()*.65,actor)]
		if dist>reach and actor.actor_context.region.navigation:
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
				if shot:
					if not shot_lane_clear(target): return _reposition_for_shot(target)
					return [shot]
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
	for source in QuickslotLoadout.SOURCES:
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

func _guard(_target: Node2D) -> Action:
	var defend:=Action.new(); defend.action_type=Action.ActionType.GUARD; defend.params["held"]=true; defend.direction=actor.get_target_direction()
	return defend
func _ally_striking(target: Node2D) -> bool:
	var context:=actor.actor_context
	if not context.nearby_allies.is_valid(): return false
	for ally: Node2D in context.nearby_allies.call(180.0):
		if not actor.can_see(ally): continue
		var other:=ally.get("actor_context") as ActorContext
		if not other or not other.actions.active() or other.actions.mode!="attack" or other.actions.profile.projectile_speed>0: continue
		var toward:=target.global_position-ally.global_position
		if toward.length()<=other.actions.profile.reach+24 and (toward.is_zero_approx() or other.actions.facing.dot(toward.normalized())>.5): return true
	return false

func _threatens(observation: Dictionary,target: Node2D) -> bool:
	if observation.is_empty(): return false
	var offset:=actor.global_position-target.global_position
	if offset.length()>float(observation.reach)+24: return false
	var direction: Vector2=observation.direction
	var tolerance:=atan2(18,maxf(1,offset.length()))
	return offset.is_zero_approx() or direction.dot(offset.normalized())>=cos(minf(PI,deg_to_rad(float(observation.angle)*.5)+tolerance))

## Same collision mask and owner resolution as a real arrow; queries spend nothing.
func shot_lane_clear(target: Node2D,origin:=Vector2.INF) -> bool:
	var start:=actor.global_position if not origin.is_finite() else origin
	var query:=PhysicsRayQueryParameters2D.create(start,target.global_position,11,[actor.get_rid()])
	query.collide_with_areas=true
	var hit:=actor.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	var body:=hit.collider as Node2D
	if body and not body.has_method("take_damage"): body=body.owner as Node2D
	return body==target

func _safe_side(target: Node2D,seek_lane:=false) -> Vector2:
	var toward:=actor.global_position.direction_to(target.global_position)
	var surfaces:=SurfaceManager.instance
	var best:=INF
	var selected:=Vector2.ZERO
	# Stable per-body preference makes allies choose different shoulders, not RNG.
	var sign_side:=1.0 if actor.get_instance_id()%2==0 else -1.0
	for sign_value in [sign_side,-sign_side]:
		var side: Vector2=toward.orthogonal()*float(sign_value)
		if actor.test_move(actor.global_transform,side*64): continue
		var point:=actor.global_position+side*64
		var danger:=surfaces.danger_at(point,actor) if surfaces else 0.0
		var score:=danger*6+(0 if not seek_lane or shot_lane_clear(target,point) else 2)
		if score<best: best=score; selected=side
	return selected

func _reposition_for_shot(target: Node2D) -> Array[Action]:
	var side:=_safe_side(target,true)
	var result: Array[Action]=[Action.move(side*.65,actor)]
	return result

func _crowded(target: Node2D) -> bool:
	var context:=actor.actor_context
	if not context.nearby_allies.is_valid(): return false
	var toward:=target.global_position-actor.global_position
	for ally: Node2D in context.nearby_allies.call(100.0):
		if not actor.can_see(ally): continue
		var offset:=ally.global_position-actor.global_position
		if offset.length()<38 and offset.dot(toward)>0 and ally.global_position.distance_to(target.global_position)<toward.length(): return true
	return false
