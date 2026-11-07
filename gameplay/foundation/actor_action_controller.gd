class_name ActorActionController
extends Node2D
## One physical action executor for every actor. Clocks are driven once in physics.
var context: ActorContext
var stamina: StaminaComponent
var stability: StabilityComponent
var input_provider: Callable
var legacy_request: Callable
var pack_request: Callable
var item_request: Callable
var mode := "idle"
var elapsed := 0.0
var remaining := 0.0
var facing := Vector2.DOWN
var movement := Vector2.ZERO
var guarding := false
var sprinting := false
var profile: AttackProfile
var _hit_targets: Dictionary={}
var _family := ""
var _attack_sequence := 0
var _move_age := 0.0
var _buffer: Action
var _buffer_time := 0.0
var needs:=SurvivalNeeds.new()
var input_suppressed := 0.0
var operation_id := 0
var attack_weapon_uid := ""
func active() -> bool:
	return context and context.rules and context.rules.tactical_combat
func busy() -> bool: return mode!="idle"
func _physics_process(delta: float) -> void:
	if not active() or not is_instance_valid(context.actor): return
	if context.actor.process_mode==Node.PROCESS_MODE_DISABLED: return
	if "ui_blocked" in context.actor and context.actor.ui_blocked:
		clear_input()
		return
	input_suppressed=maxf(0,input_suppressed-delta)
	if input_provider.is_valid() and input_suppressed==0:
		movement=Vector2.ZERO
		for action: Action in input_provider.call(): try_action(action)
	advance(delta)
func try_action(action: Action) -> OperationResult:
	var actor:=context.actor if context else null
	if not actor or actor.get_node("HealthComponent").is_dead: return OperationResult.reject("dead")
	if not active(): return OperationResult.success()
	var buffs:=actor.get_node_or_null("BuffManager") as BuffManager
	if buffs and buffs.prevents_actions(): return OperationResult.reject("controlled")
	if "ui_blocked" in actor and actor.ui_blocked: return OperationResult.reject("interface")
	# Keep the input adapter lossless. Only execution discards an unmatched UI release.
	if action.action_type==Action.ActionType.CAST and action.params.get("release",false) and "casting" in actor:
		var casting: PlayerCastingController=actor.casting
		if not casting.aiming_sources.has(action.skill_source) and casting._channeling_source!=action.skill_source and not casting._charge_source_matches(action.skill_source): return OperationResult.reject("unpaired_release")
	if mode=="spray" and action.action_type in [Action.ActionType.DODGE,Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK]: context.spray.stop()
	if mode=="item" and (action.action_type in [Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.DODGE,Action.ActionType.CAST] or action.action_type==Action.ActionType.MOVE and action.direction.length_squared()>.01): cancel("other_action")
	match action.action_type:
		Action.ActionType.MOVE:
			movement=action.direction.limit_length(1)
			_move_age=0
			if movement.length_squared()>.01:
				_cancel_work()
				if actor.get_node("SkillManager").combinations.is_busy(): actor.get_node("SkillManager").combinations.cancel("移动中断准备")
			return OperationResult.success()
		Action.ActionType.GUARD:
			guarding=bool(action.params.get("held",false)) and not busy() and can_guard()
			if guarding and action.direction.length_squared()>.01: facing=action.direction.normalized()
			return OperationResult.success()
		Action.ActionType.SPRINT:
			sprinting=bool(action.params.get("held",false))
			return OperationResult.success()
		Action.ActionType.DROP_PACK:
			if busy() or not pack_request.is_valid(): return OperationResult.reject("busy")
			return OperationResult.success() if pack_request.call() else OperationResult.reject("unavailable")
		Action.ActionType.CAST:
			if busy(): return _queue(action)
			guarding=false
			action.params["authorized"]=true
			if legacy_request.is_valid(): legacy_request.call(action)
			return OperationResult.success()
		Action.ActionType.INTERACT:
			if mode=="stagger": return OperationResult.reject("stagger")
			if legacy_request.is_valid(): legacy_request.call(action)
			return OperationResult.success()
		Action.ActionType.USE_ITEM:
			if busy() or not item_request.is_valid(): return OperationResult.reject("busy")
			if not item_request.call(action.skill_id): return OperationResult.reject("unavailable")
			if not context.item_actions.busy() and SurvivalCatalog.FOODS.has(action.skill_id):
				mode="item"; elapsed=0; remaining=SurvivalCatalog.FOODS[action.skill_id].seconds; movement=Vector2.ZERO
			return OperationResult.success()
		Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK:
			if busy(): return _queue(action)
			var equipment:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
			var weapon:=equipment.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if equipment else null
			profile=weapon.attack_profile if weapon and weapon.attack_profile else AttackProfile.new()
			attack_weapon_uid=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
			if action.action_type==Action.ActionType.HEAVY_ATTACK: profile=profile.heavy()
			if not stamina.spend(profile.stamina_cost*burden_cost()*activity_efficiency(SkillMastery.School.MELEE)): return OperationResult.reject("stamina")
			_cancel_work(); _cancel_cast()
			needs.exert(.2,context.actor.get_node("StatsComponent").effective_stat("endurance"))
			mode="attack"; elapsed=0; remaining=profile.windup+profile.active+profile.recovery
			facing=action.direction.normalized() if action.direction.length_squared()>.01 else facing
			_hit_targets.clear()
			_attack_sequence+=1
			_family="weapon.%s.%d"%[context.id,_attack_sequence]
			guarding=false
			return OperationResult.success()
		Action.ActionType.DODGE:
			if busy() and mode!="attack": return OperationResult.reject("busy")
			if mode=="attack" and elapsed<profile.windup+profile.active: return OperationResult.reject("committed_attack")
			if not stamina.spend(20*burden_cost()): return OperationResult.reject("stamina")
			_cancel_work(); _cancel_cast()
			needs.exert(.5,context.actor.get_node("StatsComponent").effective_stat("endurance"))
			mode="dodge"; elapsed=0; remaining=.35
			facing=action.direction.normalized() if action.direction.length_squared()>.01 else facing
			guarding=false
			return OperationResult.success()
	return OperationResult.reject("unsupported_action")
func _queue(action: Action) -> OperationResult:
	if mode=="stagger": return OperationResult.reject("stagger")
	_buffer=action
	_buffer_time=.15
	return OperationResult.reject("buffered")
func advance(delta: float) -> void:
	if not active() or not is_instance_valid(context.actor): return
	var actor:=context.actor
	if actor.get_node("HealthComponent").is_dead:
		cancel("dead"); return
	_move_age+=delta
	if _move_age>.3 and not input_provider.is_valid(): movement=Vector2.ZERO
	_buffer_time=maxf(0,_buffer_time-delta)
	if _buffer_time==0: _buffer=null
	var status:=actor.get_node_or_null("BuffManager") as BuffManager
	if status and status.prevents_actions(): cancel("controlled")
	var stats:=actor.get_node_or_null("StatsComponent") as StatsComponent
	var multiplier:=1.0
	var bonus:=0.0
	if not ("survival" in actor and actor.survival):
		needs.tick(delta,stats.effective_stat("endurance") if stats else 10,context.rules.is_base(context.region.id,actor.position))
		NeedsRecovery.apply(actor,needs)
	multiplier=(.35 if needs.hydration<=20 else 1.0)*(.5 if needs.fatigue>=85 else .75 if needs.fatigue>=60 else 1.0)
	bonus=(2.0 if needs.water_remaining>0 else 0.0)+(2.0 if needs.meal_remaining>0 else 0.0)
	stamina.configure(stats.effective_stat("endurance") if stats else 10,multiplier,bonus)
	stamina.advance(delta,guarding)
	stability.advance(delta)
	var old_elapsed:=elapsed
	if busy():
		elapsed+=delta
		remaining=maxf(0,remaining-delta)
		if mode=="attack" and elapsed>=profile.windup and old_elapsed<profile.windup+profile.active:
			var after:=elapsed
			elapsed=minf(elapsed,profile.windup+profile.active)
			_scan_contacts()
			elapsed=after
		if remaining==0 and mode not in ["aim_item","spray"] and not (mode=="item" and context.item_actions.busy()):
			if mode=="stagger": stability.recovered()
			mode="idle"
			if _buffer and _buffer_time>0:
				var queued:=_buffer
				_buffer=null
				try_action(queued)
	var speed:=float(actor.get("move_speed"))
	var factor:=burden_speed()
	if guarding: factor*=.4
	if mode=="attack": factor*=profile.movement_multiplier
	if mode=="spray": factor*=.45
	if mode in ["stagger","item"]: factor=0
	var direction:=movement
	if mode=="dodge": direction=facing; speed=600; factor=burden_speed()
	elif sprinting and not busy() and not guarding and movement.length_squared()>.01:
		if stamina.spend(8*delta*burden_cost()): factor*=1.35
	if actor.get_node("SkillManager").combinations.is_busy(): factor=0
	actor.velocity=direction*speed*factor
	if direction.length_squared()>.01:
		actor.move_and_slide()
		if not busy() and not guarding: facing=direction.normalized()
	if "facing_direction" in actor: actor.facing_direction=facing
	queue_redraw()
func _scan_contacts() -> void:
	var actor:=context.actor
	var shape:=CircleShape2D.new()
	shape.radius=profile.reach
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,actor.global_position)
	query.collision_mask=2|8
	query.collide_with_areas=true
	query.exclude=[actor.get_rid()]
	for hit in actor.get_world_2d().direct_space_state.intersect_shape(query,64):
		var target:=hit.collider as Node2D
		if target and not target.has_method("take_damage"):
			target=target.owner as Node2D if target.owner and target.owner.has_method("take_damage") else null
		if target: contact(target)
func contact(target: Node2D) -> HitResult:
	var rejected:=HitResult.new()
	if mode!="attack" or elapsed<profile.windup or elapsed>profile.windup+profile.active or not is_instance_valid(target) or target==context.actor: return rejected
	var offset:=target.global_position-context.actor.global_position
	if offset.length()>profile.reach or not offset.is_zero_approx() and facing.dot(offset.normalized())<cos(deg_to_rad(profile.angle_degrees*.5)): return rejected
	var ray:=PhysicsRayQueryParameters2D.create(context.actor.global_position,target.global_position,1,[context.actor.get_rid()])
	if not context.actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return rejected
	var id:=target.get_instance_id()
	if _hit_targets.has(id): return rejected
	_hit_targets[id]=true
	var tags: Array[String]=["melee","physical"]
	var buffs:=context.actor.get_node_or_null("BuffManager") as BuffManager
	if buffs:
		var imbued:=buffs.get_attack_tags()
		tags.append_array(imbued)
		if not imbued.is_empty(): ActorCombatModel.apply_melee_surface(target,tags)
	var skill:=SkillData.new()
	skill.id="weapon_contact"
	var weapon_uid: String=context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),"")
	var coating:=context.items.coating(weapon_uid) if weapon_uid==attack_weapon_uid else null
	if coating:
		tags.append_array(coating.payload.tags)
		skill.contact_statuses=coating.payload.statuses.duplicate()
		ActorCombatModel.apply_melee_surface(target,tags)
	skill.tags=tags
	var damage:=roundi(float(context.actor.get("attack_damage") if "attack_damage" in context.actor else context.actor.combat_component.attack_damage)*profile.damage_multiplier)
	var result:=CombatExecutor.report_hit(context.actor,target,damage,target.global_position,skill,tags,_family,profile.impact)
	if result.damage_dealt>0 and context.reward_eligible and context.facts and (not "rewards_enabled" in target or target.rewards_enabled): context.facts.publish("melee_hit",context.id,{"target":str(id),"damage":result.damage_dealt,"family":_family})
	return result
func defend(hit: HitContext,result: HitResult,impact: float) -> void:
	if not active() or hit.periodic or "environment" in hit.tags: return
	if mode=="dodge" and elapsed>=.08 and elapsed<=.22:
		result.accepted=false; result.damage_accepted=false; result.status_accepted=false; result.rejection="dodge"
		return
	var physical: bool="melee" in hit.tags or "physical" in hit.tags
	if guarding and physical and is_instance_valid(hit.source):
		var direction: Vector2=hit.source.global_position-context.actor.global_position
		if direction.is_zero_approx() or facing.dot(direction.normalized())>=cos(deg_to_rad(60)):
			var manager:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
			var shield:=manager and manager.get_all_equipped().any(func(item): return item.world_shape=="shield")
			var cost:=maxf(1,impact)*(.4 if shield else .6)*activity_efficiency(SkillMastery.School.DEFENSE)
			if stamina.spend(cost):
				result.blocked=true
				hit.damage=roundi(hit.damage*(0.0 if shield else .4))
				if shield: result.status_accepted=false
				impact*=.5 if shield else .8
				if context.reward_eligible and context.facts: context.facts.publish("hit_blocked",context.id,{"impact":impact,"family":hit.family_id})
			else:
				stamina.current=0
				result.guard_broken=true
				interrupt(.8)
	if impact>0:
		result.impact_applied=impact
		var duration:=stability.receive(impact)
		if duration>0: interrupt(duration)
func interrupt(seconds: float) -> void:
	if context.item_actions: context.item_actions.cancel()
	if context.spray: context.spray.stop()
	_cancel_work(); _cancel_cast()
	clear_input()
	var duration:=maxf(seconds,remaining if mode=="stagger" else 0.0)
	mode="stagger"; elapsed=0; remaining=duration
func cancel(_reason := "cancelled") -> void:
	operation_id+=1
	mode="idle"; remaining=0; elapsed=0
	_hit_targets.clear()
	clear_input()
func clear_input() -> void:
	movement=Vector2.ZERO; guarding=false; sprinting=false
	_buffer=null; _buffer_time=0
func burden_cost() -> float:
	return maxf(1,context.items.weight(context.id)/context.rules.carry_limit) if context.items else 1.0
func burden_speed() -> float:
	return clampf(1.0/burden_cost(),.35,1)
func _cancel_cast() -> void:
	var manager:=context.actor.get_node_or_null("SkillManager") as SkillManager
	if manager and manager.combinations: manager.combinations.cancel("动作中断准备")
	if "casting" in context.actor and context.actor.casting: context.actor.casting.cancel_all()
func _cancel_work() -> void:
	if "field_work" in context.actor and context.actor.field_work:
		context.actor.field_work.cancel("开始其他动作")
		context.actor.field_work.close_panel()
func _draw() -> void:
	if not active(): return
	if mode=="attack" and elapsed<profile.windup:
		var angle:=facing.angle()
		draw_arc(Vector2.ZERO,profile.reach,angle-deg_to_rad(profile.angle_degrees*.5),angle+deg_to_rad(profile.angle_degrees*.5),20,Color(1,.7,.3,.6),2,true)
	if guarding: draw_arc(Vector2.ZERO,30,facing.angle()-PI/3,facing.angle()+PI/3,16,Color(.5,.8,1),3,true)

func activity_efficiency(school: SkillMastery.School) -> float:
	var actor:=context.actor
	return actor.mastery_manager.activity_efficiency(school) if "mastery_manager" in actor and actor.mastery_manager else 1.0

func can_guard() -> bool:
	var manager:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
	return manager and manager.get_all_equipped().any(func(item): return item.world_shape in ["shield","blade","spear","staff"])
