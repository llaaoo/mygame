class_name ActorActionController
extends Node2D
## One physical action executor for every actor. Clocks are driven once in physics.
signal action_refused(reason: String)
var _feedback_cooldown := 0.0
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
const TIME_EPSILON := .000001
const INPUT_BUFFER_SECONDS := .15
const RECOVERY_INPUT_BUFFER_SECONDS := .35
const PARRY_WINDOW := .18
const PARRY_RETRY := .65
var guard_age := 99.0
var parry_retry := 0.0
var counter_remaining := 0.0
var counter_strike := false
var _parry_spent := true
var _push_remaining := 0.0
var _push_velocity:=Vector2.ZERO
var push_recovery := 0.0
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
var combo_index := 0
var combo_remaining := 0.0
var combo_weapon := ""
var _launched := false
var _ammo_uid := ""
var _coating_state: Dictionary={}
var _enchantment: WeaponEnchantment
var _release_technique: MartialTechnique
var _release_committed := false
func active() -> bool:
	return context and context.rules and context.rules.tactical_combat
func busy() -> bool: return mode!="idle"
func _physics_process(delta: float) -> void:
	if not active() or not is_instance_valid(context.actor): return
	if context.actor.process_mode==Node.PROCESS_MODE_DISABLED: return
	_feedback_cooldown=maxf(0,_feedback_cooldown-delta)
	input_suppressed=maxf(0,input_suppressed-delta)
	if "ui_blocked" in context.actor and context.actor.ui_blocked:
		clear_input()
		advance(delta)
		return
	if input_provider.is_valid() and input_suppressed==0:
		movement=Vector2.ZERO
		for action: Action in input_provider.call():
			var result:=try_action(action)
			_report_refusal(action,result)
	advance(delta)
func _report_refusal(action: Action,result: OperationResult) -> void:
	if result.accepted or result.reason in ["buffered","unpaired_release"] or _feedback_cooldown>0: return
	if action.action_type not in [Action.ActionType.TECHNIQUE,Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK]: return
	_feedback_cooldown=.8
	action_refused.emit({"stamina":"体力不足","ammunition":"口袋中缺少箭矢","busy":"当前动作尚未结束","stale_binding":"快捷绑定已改变","controlled":"控制状态中","stagger":"失衡中"}.get(result.reason,result.reason))
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
	if mode=="item" and (action.action_type in [Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.TECHNIQUE,Action.ActionType.DODGE,Action.ActionType.CAST] or action.action_type==Action.ActionType.MOVE and action.direction.length_squared()>.01): cancel("other_action")
	match action.action_type:
		Action.ActionType.MOVE:
			movement=action.direction.limit_length(1)
			_move_age=0
			if movement.length_squared()>.01:
				_cancel_work()
				if actor.get_node("SkillManager").combinations.is_busy(): actor.get_node("SkillManager").combinations.cancel("移动中断准备")
			return OperationResult.success()
		Action.ActionType.GUARD:
			if bool(action.params.get("held",false)):
				_cancel_work()
				_cancel_cast()
				if context.spray: context.spray.stop()
			var next_guard:=bool(action.params.get("held",false)) and not busy() and can_guard()
			if next_guard and not guarding:
				guard_age=0
				_parry_spent=parry_retry>0
				parry_retry=PARRY_RETRY
			guarding=next_guard
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
			if legacy_request.is_valid(): legacy_request.call(action)
			return OperationResult.success()
		Action.ActionType.INTERACT:
			if mode=="stagger": return OperationResult.reject("stagger")
			if legacy_request.is_valid(): legacy_request.call(action)
			return OperationResult.success()
		Action.ActionType.USE_ITEM:
			if not item_request.is_valid(): return OperationResult.reject("unavailable")
			if not action.params.get("release",false) and (busy() or "field_work" in actor and actor.field_work and actor.field_work.is_busy()): return OperationResult.reject("busy")
			if not item_request.call(action): return OperationResult.reject("unavailable")
			if not ("field_work" in actor and actor.field_work) and not context.item_actions.busy() and SurvivalCatalog.FOODS.has(action.skill_id):
				mode="item"; elapsed=0; remaining=SurvivalCatalog.FOODS[action.skill_id].seconds; movement=Vector2.ZERO
			return OperationResult.success()
		Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.TECHNIQUE:
			if busy(): return _queue(action)
			var equipment:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
			var weapon:=equipment.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if equipment else null
			var weapon_uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
			var next_combo:=0 if combo_remaining<=0 or combo_weapon!=weapon_uid else combo_index
			var candidate:=weapon.attack_profile if weapon and weapon.attack_profile else AttackProfile.new()
			if weapon and weapon.moveset and not weapon.moveset.attacks.is_empty(): candidate=weapon.moveset.attacks[next_combo%weapon.moveset.attacks.size()]
			if action.action_type==Action.ActionType.TECHNIQUE:
				if not action.skill_source.is_empty():
					var manager:=actor.get_node("SkillManager") as SkillManager
					if manager.shortcuts.revision(action.skill_source)!=int(action.params.get("binding_revision",-1)) or manager.shortcuts.binding(action.skill_source).get("technique_id","")!=action.skill_id: return OperationResult.reject("stale_binding")
				var reason:=context.martial.reason(action.skill_id,context)
				if not reason.is_empty(): return OperationResult.reject(reason)
				candidate=MartialArts.definition(action.skill_id).profile
			elif action.action_type==Action.ActionType.HEAVY_ATTACK: candidate=candidate.heavy()
			var cost:=candidate.stamina_cost*burden_cost()*activity_efficiency(SkillMastery.School.MELEE)
			if stamina.current<cost: return OperationResult.reject("stamina")
			var ammo_uid:=context.items.ready_uid(context.id,candidate.ammo_id) if not candidate.ammo_id.is_empty() else ""
			if not candidate.ammo_id.is_empty() and ammo_uid.is_empty(): return OperationResult.reject("ammunition")
			var coating:=context.items.coating(weapon_uid)
			var release:=action.action_type==Action.ActionType.TECHNIQUE and bool(action.params.get("release_enchantment",false))
			if release and (not coating or not coating.enchantment): return OperationResult.reject("武器没有可释放的元素附魔")
			if release and action.params.has("enchantment_state") and (str(action.params.get("enchantment_weapon_uid",""))!=weapon_uid or action.params.enchantment_state!=context.items.coating_state(weapon_uid)): return OperationResult.reject("所选附魔已改变")
			stamina.spend(cost)
			counter_strike=counter_remaining>0 and candidate.projectile_speed==0
			if counter_strike:
				candidate=candidate.duplicate(true) as AttackProfile
				candidate.damage_multiplier*=1.25; candidate.impact*=1.4
				counter_remaining=0
			if not input_provider.is_valid(): movement=Vector2.ZERO
			profile=candidate; attack_weapon_uid=weapon_uid; _launched=false; _ammo_uid=ammo_uid
			_coating_state=context.items.coating_state(weapon_uid)
			_enchantment=coating.enchantment if coating else null
			_release_technique=MartialArts.definition(action.skill_id) if release else null
			_release_committed=false
			combo_weapon=weapon_uid
			combo_index=(next_combo+1)%weapon.moveset.attacks.size() if weapon and weapon.moveset and action.action_type==Action.ActionType.MELEE else 0
			combo_remaining=remaining+profile.windup+profile.active+profile.recovery+(weapon.moveset.chain_window if weapon and weapon.moveset else 0.0)
			if action.action_type==Action.ActionType.TECHNIQUE: context.martial.accepted(action.skill_id,context.items.clock_seconds)
			_cancel_work(); _cancel_cast()
			needs.exert(.2,context.actor.get_node("StatsComponent").effective_stat("endurance"))
			mode="attack"; elapsed=0; remaining=profile.windup+profile.active+profile.recovery
			facing=action.direction.normalized() if action.direction.length_squared()>.01 else facing
			_hit_targets={}
			_attack_sequence+=1
			_family="weapon.%s.%d"%[context.id,_attack_sequence]
			guarding=false
			if context.facts: context.facts.publish("physical_action_started",context.id,{"family":_family,"technique":action.skill_id if action.action_type==Action.ActionType.TECHNIQUE else "","weapon_uid":attack_weapon_uid,"stamina":cost,"counter":counter_strike})
			return OperationResult.success()
		Action.ActionType.DODGE:
			if busy() and mode!="attack": return OperationResult.reject("busy")
			if mode=="attack" and elapsed<profile.windup+profile.active: return OperationResult.reject("committed_attack")
			if not stamina.spend(20*burden_cost()*clampf(1+equipment_value("dodge_cost"),.6,1.5)): return OperationResult.reject("stamina")
			_cancel_work(); _cancel_cast()
			needs.exert(.5,context.actor.get_node("StatsComponent").effective_stat("endurance"))
			mode="dodge"; elapsed=0; remaining=.35
			facing=action.direction.normalized() if action.direction.length_squared()>.01 else facing
			guarding=false
			return OperationResult.success()
	return OperationResult.reject("unsupported_action")
func _queue(action: Action) -> OperationResult:
	if mode=="stagger": return OperationResult.reject("stagger")
	_buffer=action.copy_intent()
	_buffer_time=RECOVERY_INPUT_BUFFER_SECONDS if mode=="attack" and profile and elapsed>=profile.windup+profile.active else INPUT_BUFFER_SECONDS
	return OperationResult.reject("buffered")
func buffered_action_label() -> String:
	if not _buffer or _buffer_time<=0: return ""
	return {Action.ActionType.MELEE:"攻击已输入",Action.ActionType.HEAVY_ATTACK:"重击已输入",Action.ActionType.TECHNIQUE:"武技已输入",Action.ActionType.CAST:"施法已输入"}.get(_buffer.action_type,"")
func advance(delta: float) -> void:
	if not active() or not is_instance_valid(context.actor): return
	var actor:=context.actor
	if actor.get_node("HealthComponent").is_dead:
		cancel("dead"); return
	guard_age=guard_age+delta if guarding else 99.0
	parry_retry=maxf(0,parry_retry-delta)
	counter_remaining=maxf(0,counter_remaining-delta)
	push_recovery=maxf(0,push_recovery-delta)
	combo_remaining=maxf(0,combo_remaining-delta)
	_move_age+=delta
	if _move_age>.3 and not input_provider.is_valid(): movement=Vector2.ZERO
	var status:=actor.get_node_or_null("BuffManager") as BuffManager
	if status and status.prevents_actions(): cancel("controlled")
	var stats:=actor.get_node_or_null("StatsComponent") as StatsComponent
	var multiplier:=1.0
	var bonus:=0.0
	if not ("survival" in actor and actor.survival):
		needs.tick(delta,stats.effective_stat("endurance") if stats else 10,context.rules.is_base(context.region.id,actor.position))
		NeedsRecovery.apply(actor,needs)
	multiplier=(.35 if needs.hydration<=20 else 1.0)*(.5 if needs.fatigue>=85 else .75 if needs.fatigue>=60 else 1.0)
	bonus=float(needs.recovery().stamina_bonus)+equipment_value("stamina_recovery")
	stamina.configure(stats.effective_stat("endurance") if stats else 10,multiplier,bonus)
	stamina.advance(delta,guarding)
	stability.advance(delta)
	if _push_remaining>0:
		var pushed:=minf(delta,_push_remaining)
		actor.move_and_collide(_push_velocity*pushed)
		_push_remaining=maxf(0,_push_remaining-delta)
	if mode=="attack" and str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))!=attack_weapon_uid: cancel("weapon_changed")
	var old_elapsed:=elapsed
	if busy():
		var completion_offset:=remaining
		elapsed+=delta
		remaining=maxf(0,remaining-delta)
		if remaining<=TIME_EPSILON: remaining=0
		if mode=="attack" and elapsed>=profile.windup and old_elapsed<profile.windup+profile.active:
			if not _commit_weapon_release(): cancel("source_changed"); action_refused.emit("武器、附魔或箭矢来源已改变，攻击取消。"); return
			var active_delta:=maxf(0,minf(elapsed,profile.windup+profile.active)-maxf(old_elapsed,profile.windup))
			if profile.step_distance>0: actor.move_and_collide(facing*profile.step_distance*active_delta/profile.active)
			var after:=elapsed
			elapsed=minf(elapsed,profile.windup+profile.active)
			if profile.projectile_speed>0:
				if not _launched:
					_launched=true
					_launch_arrow()
			else: _scan_contacts()
			elapsed=after
		if remaining==0 and mode not in ["aim_item","spray"] and not (mode=="item" and context.item_actions.busy()):
			if mode=="stagger": stability.recovered()
			mode="idle"
			# Compare the expiry with the completion inside this physics step,
			# before aging it. Exact-boundary presses must not be discarded.
			if _buffer and _buffer_time+TIME_EPSILON>=completion_offset:
				var queued:=_buffer
				_buffer=null; _buffer_time=0
				_report_refusal(queued,try_action(queued))
	_buffer_time=maxf(0,_buffer_time-delta)
	if _buffer_time==0: _buffer=null
	var speed:=float(actor.get("move_speed"))
	var factor:=burden_speed()
	if guarding: factor*=.4
	if mode=="attack": factor*=profile.movement_factor(elapsed)
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
func _launch_arrow() -> void:
	var arrow:=WeaponArrow.new(); arrow.context=context; arrow.profile=profile; arrow.direction=facing; arrow.family=_family
	arrow.damage=roundi(float(context.actor.get("attack_damage") if "attack_damage" in context.actor else context.actor.combat_component.attack_damage)*profile.damage_multiplier)
	arrow.enchantment=_enchantment; arrow.release_technique=_release_technique
	if _enchantment: arrow.tags.append_array(_enchantment.tags)
	context.region.root.add_child(arrow); arrow.global_position=context.actor.global_position

func _commit_weapon_release() -> bool:
	if _release_committed: return true
	if not context.region.available() or not context.items.commit_weapon_release(context.id,attack_weapon_uid,_ammo_uid,_coating_state,_release_technique!=null,profile.ammo_id): return false
	_release_committed=true; _ammo_uid=""
	if _release_technique and profile.projectile_speed==0:
		var wave:=EnchantmentWave.new(); wave.context=context; wave.enchantment=_enchantment; wave.technique=_release_technique
		wave.direction=facing; wave.family=_family
		wave.hit_targets=_hit_targets
		context.region.root.add_child(wave); wave.global_position=context.actor.global_position
	return true
func equipment_value(key: String) -> float:
	var equipment:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
	return equipment.get_modifier_value(key) if equipment else 0.0
func attack_observation() -> Dictionary:
	if mode!="attack" or not profile: return {}
	return {"serial":_attack_sequence,"windup":maxf(0,profile.windup-elapsed),"reach":maxf(profile.reach+profile.step_distance,_release_technique.release_reach if _release_technique else 0),"direction":facing,"angle":maxf(profile.angle_degrees,_release_technique.release_angle if _release_technique else 0),"heavy":profile.guard_pressure>1 or profile.windup>=.35 or _release_technique!=null}
func is_preparing() -> bool:
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	var preparing:=manager.combinations.is_busy() or mode in ["item","aim_item","spray"] or mode=="attack" and profile and profile.projectile_speed>0 and elapsed<profile.windup
	if "casting" in context.actor and context.actor.casting:
		var casting: PlayerCastingController=context.actor.casting
		preparing=preparing or not casting._charging_source.is_empty() or not casting._channeling_source.is_empty()
	return preparing or context.preparation_query.is_valid() and bool(context.preparation_query.call())
func resolve_strike(hit: HitContext,result: HitResult) -> void:
	if not hit.strike or result.blocked or not result.damage_accepted or result.damage_dealt<=0: return
	if hit.strike.interrupts_preparation and hit.was_preparing and not hit.control_protected:
		interrupt(.35); result.interrupted=true
	if hit.strike.push_distance>0 and push_recovery<=0 and is_instance_valid(hit.source):
		var direction: Vector2=context.actor.global_position-hit.origin
		if direction.is_zero_approx(): direction=-facing
		_push_remaining=.18; _push_velocity=direction.normalized()*hit.strike.push_distance/.18
		push_recovery=.9
		result.pushed=true
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
	if str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))!=attack_weapon_uid: return rejected
	var offset:=target.global_position-context.actor.global_position
	if offset.length()>profile.reach or not offset.is_zero_approx() and facing.dot(offset.normalized())<cos(deg_to_rad(profile.angle_degrees*.5)): return rejected
	var ray:=PhysicsRayQueryParameters2D.create(context.actor.global_position,target.global_position,1,[context.actor.get_rid()])
	if not context.actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return rejected
	var id:=target.get_instance_id()
	if _hit_targets.has(id): return rejected
	if not _commit_weapon_release(): return rejected
	_hit_targets[id]=true
	var tags: Array[String]=["melee","physical"]
	var buffs:=context.actor.get_node_or_null("BuffManager") as BuffManager
	if buffs:
		var imbued:=buffs.get_attack_tags()
		tags.append_array(imbued)
	var skill:=SkillData.new()
	skill.id="weapon_contact"
	if _enchantment:
		tags.append_array(_enchantment.tags)
		skill.weapon_enchantment=_enchantment
		skill.enchantment_bonus=_enchantment.release_damage if _release_technique else _enchantment.bonus_damage
		skill.enchantment_buildup=_enchantment.release_buildup if _release_technique else _enchantment.buildup
	skill.tags=tags
	var damage:=roundi(float(context.actor.get("attack_damage") if "attack_damage" in context.actor else context.actor.combat_component.attack_damage)*profile.damage_multiplier)
	var result:=CombatExecutor.report_hit(context.actor,target,damage,target.global_position,skill,tags,_family,profile.impact,profile)
	if result.damage_dealt>0 and not result.blocked: ActorCombatModel.apply_melee_surface(target,tags)
	if result.damage_dealt>0 and context.reward_eligible and context.facts and (not "rewards_enabled" in target or target.rewards_enabled): context.facts.publish("melee_hit",context.id,{"target":str(id),"damage":result.damage_dealt,"family":_family})
	return result
func defend(hit: HitContext,result: HitResult,impact: float) -> void:
	if not active() or hit.periodic or "environment" in hit.tags: return
	if mode=="dodge" and elapsed>=.08 and elapsed<=.22:
		result.accepted=false; result.damage_accepted=false; result.status_accepted=false; result.rejection="dodge"
		return
	impact*=1-clampf(equipment_value("impact_resistance"),0,.4)
	var physical: bool="melee" in hit.tags or "physical" in hit.tags
	if guarding and physical and is_instance_valid(hit.source):
		var direction: Vector2=hit.origin-context.actor.global_position
		if direction.is_zero_approx() or facing.dot(direction.normalized())>=cos(deg_to_rad(60)):
			var manager:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
			var shield:=manager and manager.get_all_equipped().any(func(item): return item.world_shape=="shield")
			var cost:=maxf(1,impact)*(.4 if shield else .6)*activity_efficiency(SkillMastery.School.DEFENSE)*(hit.strike.guard_pressure if hit.strike else 1.0)
			if stamina.spend(cost):
				result.blocked=true
				result.parried=guard_age<=PARRY_WINDOW and not _parry_spent and (not hit.strike or hit.strike.guard_pressure<=1.0)
				if result.parried:
					_parry_spent=true; counter_remaining=.85
				hit.damage=roundi(hit.damage*(0.0 if shield else .4))
				if shield: result.status_accepted=false
				impact=0 if result.parried else impact*(.5 if shield else .8)
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
	# Repeated impact may drain stability, but cannot renew a committed stagger.
	if mode=="stagger": return
	combo_remaining=0; combo_index=0; _ammo_uid=""
	counter_remaining=0; counter_strike=false; _push_remaining=0
	if context.item_actions: context.item_actions.cancel()
	if context.spray: context.spray.stop()
	_cancel_work(); _cancel_cast()
	clear_input()
	mode="stagger"; elapsed=0; remaining=seconds
func cancel(_reason := "cancelled") -> void:
	if _reason in ["dead","scope_left","rest_time"]: push_recovery=0
	combo_remaining=0; combo_index=0; _ammo_uid=""
	counter_remaining=0; counter_strike=false; _push_remaining=0
	operation_id+=1
	mode="idle"; remaining=0; elapsed=0
	_hit_targets={}
	clear_input()
func clear_input() -> void:
	movement=Vector2.ZERO; guarding=false; sprinting=false
	_buffer=null; _buffer_time=0
func burden_cost() -> float:
	return maxf(1,context.items.weight(context.id)/context.rules.carry_limit) if context.items else 1.0
func burden_speed() -> float:
	return clampf(1.0/burden_cost(),.35,1)
func _cancel_cast() -> void:
	if context.cancel_preparation.is_valid(): context.cancel_preparation.call()
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
		if _release_technique:
			var half:=deg_to_rad(_release_technique.release_angle*.5)
			draw_arc(Vector2.ZERO,_release_technique.release_reach,angle-half,angle+half,36,Color(_enchantment.color,.5),2,true)
		draw_arc(Vector2.ZERO,profile.reach,angle-deg_to_rad(profile.angle_degrees*.5),angle+deg_to_rad(profile.angle_degrees*.5),20,Color(1,.35,.18,.65) if profile.guard_pressure>1 or profile.windup>=.35 else Color(1,.7,.3,.6),2,true)
		if profile.guard_pressure>1:
			var marker:=facing*32
			draw_polyline(PackedVector2Array([marker+Vector2(0,-6),marker+Vector2(6,0),marker+Vector2(0,6),marker+Vector2(-6,0),marker+Vector2(0,-6)]),Color("ff7855"),2,true)
		if profile.projectile_speed>0: draw_dashed_line(facing*28,facing*minf(profile.reach,180),Color(1,.7,.3,.5),1,8)
		if profile.step_distance>0: draw_line(Vector2.ZERO,facing*profile.step_distance,Color("dacb93"),3,true)
	if mode=="attack" and elapsed>=profile.windup+profile.active:
		var fraction:=clampf(remaining/maxf(.001,profile.recovery),0,1)
		draw_arc(Vector2.ZERO,26,-PI/2,-PI/2+TAU*fraction,20,Color(.75,.8,.9,.45),1.5,true)
	if mode=="attack": _draw_weapon_motion()
	if counter_remaining>0: draw_arc(Vector2.ZERO,34,0,TAU*counter_remaining/.85,24,Color("e0bf70"),2,true)
	if guarding: draw_arc(Vector2.ZERO,30,facing.angle()-PI/3,facing.angle()+PI/3,16,Color(.5,.8,1),3,true)

func activity_efficiency(school: SkillMastery.School) -> float:
	var actor:=context.actor
	return actor.mastery_manager.activity_efficiency(school) if "mastery_manager" in actor and actor.mastery_manager else 1.0

func can_guard() -> bool:
	var manager:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var weapon:=manager.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if manager else null
	if weapon and weapon.moveset and weapon.moveset.weapon_type=="bow": return false
	return manager and manager.get_all_equipped().any(func(item): return item.world_shape in ["shield","blade","spear","staff"])

## A time jump advances recovery but never moves a physics body by hours of delta.
func rest_elapsed(seconds: float) -> void:
	if context.item_actions: context.item_actions.cancel()
	if context.spray: context.spray.stop()
	_cancel_cast()
	cancel("rest_time")
	stamina.advance(seconds)
	stability.advance(seconds)

func _draw_weapon_motion() -> void:
	var manager:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var weapon:=manager.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if manager else null
	var color:=weapon.world_color if weapon else Color("c6a17e")
	var coating:=context.items.coating(attack_weapon_uid)
	if coating: color=color.lerp(coating.payload.color,.8)
	if counter_strike: color=color.lerp(Color("f3d58a"),.55)
	var before:=elapsed<profile.windup
	var active_phase:=elapsed>=profile.windup and elapsed<profile.windup+profile.active
	var progress:=clampf(elapsed/maxf(.001,profile.windup),0,1) if before else clampf((elapsed-profile.windup)/profile.active,0,1) if active_phase else 1-clampf((elapsed-profile.windup-profile.active)/maxf(.001,profile.recovery),0,1)
	var angle:=facing.angle()
	var length:=profile.reach*(.42+.2*progress if before else 1.0 if active_phase else .4+.6*progress)
	if profile.motion in ["slash","sweep"]:
		var span:=deg_to_rad(profile.angle_degrees*.5)
		angle+=(-span*(.4+.6*progress)) if before else lerpf(-span,span,progress) if active_phase else span*progress
	var direction:=Vector2.from_angle(angle)
	if profile.motion=="shot":
		draw_set_transform(Vector2.ZERO,facing.angle())
		draw_arc(Vector2(12,0),18,-PI/2,PI/2,16,color,3,true)
		var string_point:=Vector2(10-9*progress,0)
		draw_polyline(PackedVector2Array([Vector2(12,-18),string_point,Vector2(12,18)]),Color("dacead"),1,true)
		draw_line(string_point,string_point+Vector2(25,0),Color("ded1a7"),2,true)
		draw_set_transform(Vector2.ZERO)
		return
	if active_phase:
		draw_arc(Vector2.ZERO,profile.reach,facing.angle()-deg_to_rad(profile.angle_degrees*.5),facing.angle()+deg_to_rad(profile.angle_degrees*.5),24,Color(color,.13),2,true)
		if profile.motion in ["slash","sweep"]: draw_arc(Vector2.ZERO,profile.reach,facing.angle()-deg_to_rad(profile.angle_degrees*.5),angle,18,Color(color,.24),5,true)
		else: draw_line(direction*12,direction*profile.reach,Color(color,.25),7,true)
	var start:=direction*10
	var tip:=direction*length
	if not weapon: draw_circle(tip,5,color); return
	draw_line(start,tip,Color("302d27"),6,true)
	draw_line(start,tip,color,3 if weapon.world_shape!="staff" else 5,true)
	if weapon.world_shape=="staff": draw_circle(tip,5,color.lightened(.25))
	elif weapon.world_shape=="spear": draw_colored_polygon(PackedVector2Array([tip+direction*2,tip-direction*10+direction.orthogonal()*4,tip-direction*10-direction.orthogonal()*4]),color.lightened(.25))
	else: draw_line(start+direction*6-direction.orthogonal()*5,start+direction*6+direction.orthogonal()*5,Color("aa894b"),3,true)
