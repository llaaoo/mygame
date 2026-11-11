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
const WEAPON_HOLD_SECONDS := .32
const WEAPON_HOLD_LIMIT := 2.0
var _weapon_hold: Dictionary={}
var _weapon_reservation: Dictionary={}
var _gesture_serial := 0
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
var combo:=WeaponComboState.new()
var weapon_art:=WeaponArtState.new()
var _launched := false
var _ammo_uid := ""
var _coating_state: Dictionary={}
var _enchantment: WeaponEnchantment
var _release_technique: MartialTechnique
var _release_committed := false
var _current_technique := ""
func active() -> bool:
	return context and context.rules and context.rules.tactical_combat
func busy() -> bool: return mode!="idle"
func attack_moveset() -> WeaponMoveset:
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var weapon:=context.items.equipment_definition(uid)
	if weapon: return weapon.moveset
	return context.body_moveset
func next_attack_profile(heavy := false) -> AttackProfile:
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var weapon:=context.items.equipment_definition(uid)
	var candidate:=weapon.attack_profile if weapon and weapon.attack_profile else AttackProfile.new()
	var moveset:=attack_moveset()
	if moveset and not moveset.attacks.is_empty(): candidate=moveset.attacks[0 if heavy else combo.stage_for(uid,moveset)]
	return candidate.heavy() if heavy else candidate
func inventory_changed() -> void:
	if not context or not context.items: return
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	if not _weapon_hold.is_empty() and str(_weapon_hold.uid)!=uid: cancel_weapon_hold()
	if mode=="attack" and attack_weapon_uid!=uid: cancel("weapon_changed")
	elif not combo.weapon_uid.is_empty() and combo.weapon_uid!=uid or not weapon_art.weapon_uid.is_empty() and weapon_art.weapon_uid!=uid: _clear_sequences()
func _clear_sequences() -> void:
	cancel_weapon_hold(); _weapon_reservation.clear()
	combo.reset(); weapon_art.reset()
func combo_snapshot() -> Dictionary:
	var view:=combo.snapshot()
	if not view.is_empty() and combo.active:
		view["phase"]="起手" if elapsed<profile.windup else "挥出" if elapsed<profile.windup+profile.active else "收招"
	elif not view.is_empty():
		var next:=next_attack_profile()
		view["reason"]="体力不足" if stamina.current<attack_stamina_cost(next) else "口袋缺箭" if not next.ammo_id.is_empty() and context.items.ready_uid(context.id,next.ammo_id).is_empty() else ""
	return view
func attack_stamina_cost(strike: AttackProfile,is_art := false) -> float:
	var art: bool=is_art or strike in _art_profiles()
	return strike.stamina_cost*clampf(1+equipment_value("weapon_stamina_cost"),.5,1.5)*burden_cost()*activity_efficiency(SkillMastery.School.MELEE)*clampf(1+ActorProgression.modifier(context.actor,"stamina.art" if art else "stamina.attack"),.4,1.5)
func technique_view(id: String,force_base := false,release_enchantment := false) -> Dictionary:
	var data:=MartialArts.definition(id)
	if not data: return {}
	var recovering:=mode=="attack" and profile and elapsed>=profile.windup+profile.active
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var linked:=not force_base and uid==combo.weapon_uid and combo.permits_followup(data,recovering,weapon_art.confirmed(combo.family))
	var candidate:=data.followup_profile if linked else data.profile
	var cost:=attack_stamina_cost(candidate)
	var reason:=context.martial.reason(id,context)
	if reason.is_empty() and stamina.current<cost: reason="体力不足"
	if reason.is_empty() and not candidate.ammo_id.is_empty() and context.items.ready_uid(context.id,candidate.ammo_id).is_empty(): reason="口袋缺箭"
	if reason.is_empty() and release_enchantment:
		var coating:=context.items.coating(uid)
		if not coating or not coating.enchantment: reason="武器没有可释放的元素附魔"
	return {"profile":candidate,"linked":linked,"family":combo.family if linked else "","reason":reason,"cost":cost,"title":candidate.title if linked else data.title}
func capture_technique_intent(action: Action,force_base := false) -> Action:
	var captured:=action.copy_intent()
	var view:=technique_view(action.skill_id,force_base,bool(action.params.get("release_enchantment",false)))
	captured.params["followup_family"]=str(view.get("family",""))
	return captured
func weapon_art_view(release_enchantment := false) -> Dictionary:
	var recovering:=mode=="attack" and profile and elapsed>=profile.windup+profile.active and remaining<=RECOVERY_INPUT_BUFFER_SECONDS+TIME_EPSILON
	if busy() and not recovering: return {}
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	if uid.is_empty() or uid!=weapon_art.weapon_uid: return {}
	var choices: Array[Dictionary]=[]
	for id in context.martial.learned:
		var data:=MartialArts.definition(id)
		if not data: continue
		var weapon:=context.items.equipment_definition(uid)
		if not weapon or not weapon.moveset or data.weapon_type!=weapon.moveset.weapon_type: continue
		for route in data.art_routes:
			if not context.martial.route_equipped(id,route.id): continue
			var match_result:=weapon_art.match_route(route,recovering)
			if match_result.is_empty(): continue
			var candidate:=data.profile if route.form==MartialRoute.Form.BASE else data.followup_profile
			var reason:=context.martial.reason(id,context)
			var cost:=attack_stamina_cost(candidate)
			if reason.is_empty() and stamina.current<cost: reason="体力不足"
			if reason.is_empty() and not candidate.ammo_id.is_empty() and context.items.ready_uid(context.id,candidate.ammo_id).is_empty(): reason="口袋缺箭"
			if reason.is_empty() and release_enchantment:
				var coating:=context.items.coating(uid)
				if not coating or not coating.enchantment: reason="武器没有可释放的元素附魔"
			choices.append({"technique":id,"route":route.id,"form":route.form,"token":match_result.token,"remaining":match_result.remaining,"recovering":match_result.recovering,"title":data.title if route.form==MartialRoute.Form.BASE else candidate.title,"reason":reason,"cost":cost,"profile":candidate,"length":route.sequence.size(),"priority":route.priority})
	if choices.is_empty(): return {}
	choices.sort_custom(func(a: Dictionary,b: Dictionary):
		if a.length!=b.length: return a.length>b.length
		if a.priority!=b.priority: return a.priority>b.priority
		return str(a.technique)+str(a.route)<str(b.technique)+str(b.route))
	var group:=MartialArts.route_group(MartialArts.definition(choices[0].technique),MartialArts.definition(choices[0].technique).art_route(choices[0].route))
	choices=choices.filter(func(choice): return MartialArts.route_group(MartialArts.definition(choice.technique),MartialArts.definition(choice.technique).art_route(choice.route))==group)
	var order:=context.martial.route_slots(group)
	choices.sort_custom(func(a,b): return order.find(str(a.technique)+"/"+str(a.route))<order.find(str(b.technique)+"/"+str(b.route)))
	var references: Array=choices.map(func(choice): return str(choice.technique)+"/"+str(choice.route))
	var selected:=weapon_art.selected(str(choices[0].token),references)
	var result: Dictionary=choices[0]
	for choice in choices:
		if str(choice.technique)+"/"+str(choice.route)==selected: result=choice; break
	result=result.duplicate(); result["alternatives"]=choices.map(func(choice): return {"ref":str(choice.technique)+"/"+str(choice.route),"title":choice.title}); result["group"]=group
	return result
func cycle_weapon_art() -> OperationResult:
	if not _weapon_hold.is_empty(): return OperationResult.reject("正在准备武技")
	var view:=weapon_art_view()
	if view.is_empty(): return OperationResult.reject("没有可切换的连招窗口")
	var refs: Array=view.alternatives.map(func(choice): return choice.ref)
	return OperationResult.success() if weapon_art.cycle(view.token,refs) else OperationResult.reject("此连招仅装备一招")
func capture_weapon_art(direction: Vector2,release_enchantment := false) -> Action:
	var request:=Action.new(); request.action_type=Action.ActionType.TECHNIQUE; request.source=context.actor; request.direction=direction
	request.params={"weapon_art":true,"release_enchantment":release_enchantment}
	var view:=weapon_art_view(release_enchantment)
	if view.is_empty(): return request
	request.skill_id=view.technique
	request.params["art_route"]=view.route; request.params["art_token"]=view.token
	request.params["art_revision"]=context.martial.loadout_revision
	if release_enchantment:
		request.params["enchantment_weapon_uid"]=weapon_art.weapon_uid
		request.params["enchantment_state"]=context.items.coating_state(weapon_art.weapon_uid)
	return request
func technique_status(include_cooldowns := true) -> String:
	if mode=="attack" and not _current_technique.is_empty():
		var data:=MartialArts.definition(_current_technique)
		var phase:="起手" if elapsed<profile.windup else "挥出" if elapsed<profile.windup+profile.active else "收招"
		return (profile.title if not profile.title.is_empty() else data.title)+" · "+phase
	if not include_cooldowns: return ""
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var weapon:=context.items.equipment_definition(uid)
	if not weapon or not weapon.moveset: return ""
	var entries:=PackedStringArray()
	for id in context.martial.learned:
		var data:=MartialArts.definition(id)
		var seconds:=maxf(0,float(context.martial.ready_at.get(id,0))-context.items.clock_seconds)
		if data and not data.art_routes.is_empty() and data.weapon_type==weapon.moveset.weapon_type and seconds>0: entries.append("%s %.1f秒"%[data.title,seconds])
	return "武技冷却 · "+" / ".join(entries) if not entries.is_empty() else ""
func confirm_weapon_hit(family: String,result: HitResult,target: Node2D) -> void:
	if is_instance_valid(target) and "actor_context" in target and target.get("actor_context")!=null and result.damage_accepted and result.damage_dealt>0 and not result.blocked:
		weapon_art.confirm_contact(family)
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
			request_action(action)
	advance(delta)
func request_action(action: Action) -> OperationResult:
	var result:=try_action(action)
	_report_refusal(action,result)
	return result
func report_action_feedback(reason: String) -> void:
	# Controllers also serve AI. Only the local player's outcomes reach this HUD.
	if not context or context.id!="player" or reason.is_empty() or reason in ["scope_left","dead","interface"] or _feedback_cooldown>0: return
	_feedback_cooldown=.8
	action_refused.emit(reason)
func _report_refusal(action: Action,result: OperationResult) -> void:
	if result.accepted or result.reason in ["buffered","unpaired_release"]: return
	if action.action_type not in [Action.ActionType.TECHNIQUE,Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.USE_ITEM,Action.ActionType.DODGE,Action.ActionType.CAST]: return
	report_action_feedback({"stamina":"体力不足","ammunition":"口袋中缺少箭矢","busy":"当前动作尚未结束","stale_binding":"快捷绑定已改变","controlled":"控制状态中","stagger":"失衡中","unavailable":"当前物品不可用"}.get(result.reason,result.reason))
func try_action(action: Action) -> OperationResult:
	var actor:=context.actor if context else null
	if not actor or actor.get_node("HealthComponent").is_dead: return OperationResult.reject("dead")
	if not active(): return OperationResult.success()
	var buffs:=actor.get_node_or_null("BuffManager") as BuffManager
	if buffs and buffs.prevents_actions(): return OperationResult.reject("controlled")
	if "ui_blocked" in actor and actor.ui_blocked: return OperationResult.reject("interface")
	if action.params.get("cycle_weapon_art",false): return cycle_weapon_art()
	if action.params.has("weapon_gesture"): return _weapon_gesture(action)
	if action.action_type not in [Action.ActionType.MOVE,Action.ActionType.SPRINT,Action.ActionType.GUARD]: cancel_weapon_hold()
	# Keep the input adapter lossless. Only execution discards an unmatched UI release.
	if action.action_type==Action.ActionType.CAST and action.params.get("release",false) and "casting" in actor:
		var casting: PlayerCastingController=actor.casting
		if not casting.aiming_sources.has(action.skill_source) and casting._channeling_source!=action.skill_source and not casting._charge_source_matches(action.skill_source): return OperationResult.reject("unpaired_release")
	if mode=="spray" and action.action_type in [Action.ActionType.DODGE,Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK]: context.spray.stop()
	if mode=="item" and (action.action_type in [Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.TECHNIQUE,Action.ActionType.DODGE,Action.ActionType.CAST] or action.action_type==Action.ActionType.MOVE and action.direction.length_squared()>.01):
		context.item_actions.cancel("移动中断使用" if action.action_type==Action.ActionType.MOVE else "")
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
				cancel_weapon_hold()
				_cancel_work()
				_cancel_cast()
				if context.spray: context.spray.stop()
			var next_guard:=bool(action.params.get("held",false)) and not busy() and can_guard()
			if next_guard and not guarding:
				_clear_sequences()
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
			_clear_sequences()
			return OperationResult.success() if pack_request.call() else OperationResult.reject("unavailable")
		Action.ActionType.CAST:
			if busy(): return _queue(action)
			_clear_sequences()
			guarding=false
			if legacy_request.is_valid(): legacy_request.call(action)
			return OperationResult.success()
		Action.ActionType.INTERACT:
			if mode=="stagger": return OperationResult.reject("stagger")
			_clear_sequences()
			if legacy_request.is_valid(): legacy_request.call(action)
			return OperationResult.success()
		Action.ActionType.USE_ITEM:
			if not item_request.is_valid(): return OperationResult.reject("unavailable")
			if not action.params.get("release",false) and (busy() or "field_work" in actor and actor.field_work and actor.field_work.is_busy()): return OperationResult.reject("busy")
			var item_result: Variant=item_request.call(action)
			if item_result is OperationResult:
				if not item_result.accepted: return item_result
			elif not item_result: return OperationResult.reject("unavailable")
			_clear_sequences()
			if not ("field_work" in actor and actor.field_work) and not context.item_actions.busy() and SurvivalCatalog.FOODS.has(action.skill_id):
				mode="item"; elapsed=0; remaining=SurvivalCatalog.FOODS[action.skill_id].seconds; movement=Vector2.ZERO
			return OperationResult.success()
		Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.TECHNIQUE:
			if action.params.get("weapon_art",false) and action.skill_id.is_empty(): return OperationResult.reject("武技未发动：先完成对应连招，K查看条件")
			if busy(): return _queue(action)
			var weapon_uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
			if action.params.has("gesture_weapon_uid") and str(action.params.gesture_weapon_uid)!=weapon_uid: return OperationResult.reject("所选武器已改变")
			var weapon:=context.items.equipment_definition(weapon_uid)
			var reserved:=int(action.params.get("gesture_id",-1))==int(_weapon_reservation.get("id",-2)) and weapon_art.clock<=float(_weapon_reservation.get("until",0)) and weapon_uid==str(_weapon_reservation.get("uid",""))
			var reserved_stage:=int(_weapon_reservation.get("stage",-1)) if reserved and action.action_type==Action.ActionType.MELEE else -1
			var candidate:=next_attack_profile(action.action_type==Action.ActionType.HEAVY_ATTACK)
			if reserved_stage>=0 and weapon and weapon.moveset: candidate=weapon.moveset.attacks[reserved_stage]
			var linked_technique:=false
			if action.action_type==Action.ActionType.TECHNIQUE:
				if not action.skill_source.is_empty():
					var manager:=actor.get_node("SkillManager") as SkillManager
					if manager.shortcuts.revision(action.skill_source)!=int(action.params.get("binding_revision",-1)) or manager.shortcuts.binding(action.skill_source).get("technique_id","")!=action.skill_id: return OperationResult.reject("stale_binding")
				var reason:=context.martial.reason(action.skill_id,context)
				if not reason.is_empty(): return OperationResult.reject(reason)
				var data:=MartialArts.definition(action.skill_id)
				var requested_family:=str(action.params.get("followup_family",""))
				if action.params.get("weapon_art",false):
					var route:=data.art_route(str(action.params.get("art_route","")))
					if not context.martial.route_equipped(action.skill_id,str(action.params.get("art_route",""))) or int(action.params.get("art_revision",-1))!=context.martial.loadout_revision: return OperationResult.reject("连招武技配置已改变")
					var grace:=float(_weapon_reservation.get("grace",0)) if reserved else 0.0
					var match_result:=weapon_art.match_route(route,false,grace) if route and weapon_art.weapon_uid==weapon_uid else {}
					if match_result.is_empty() or str(match_result.token)!=str(action.params.get("art_token","")): return OperationResult.reject("武技窗口已失效")
					linked_technique=route.form==MartialRoute.Form.FOLLOWUP
				elif not requested_family.is_empty():
					if requested_family!=combo.family or not combo.permits_followup(data,false,weapon_art.confirmed(combo.family)): return OperationResult.reject("接势窗口已失效")
					linked_technique=true
				candidate=data.attack_form(linked_technique,bool(action.params.get("charged",false)))
				if not candidate: return OperationResult.reject("此武技没有蓄力形式")
			if reserved and bool(action.params.get("charged",false)) and float(action.params.get("charge_credit",0))>0:
				candidate=candidate.duplicate(true) as AttackProfile
				candidate.windup=maxf(.08,candidate.windup-minf(WEAPON_HOLD_SECONDS,float(action.params.charge_credit)))
			if not is_zero_approx(equipment_value("impact_bonus")):
				candidate=candidate.duplicate(true) as AttackProfile;candidate.impact+=equipment_value("impact_bonus")
			if not is_zero_approx(ActorProgression.modifier(context.actor,"combat.impact")):
				candidate=candidate.duplicate(true) as AttackProfile; candidate.impact*=1+ActorProgression.modifier(context.actor,"combat.impact")
			var cost:=attack_stamina_cost(candidate,action.action_type==Action.ActionType.TECHNIQUE)
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
				candidate.damage_multiplier*=1.25+ActorProgression.modifier(context.actor,"combat.counter_damage"); candidate.impact*=1.4
				counter_remaining=0
			if not input_provider.is_valid(): movement=Vector2.ZERO
			profile=candidate; attack_weapon_uid=weapon_uid; _launched=false; _ammo_uid=ammo_uid
			_current_technique=action.skill_id if action.action_type==Action.ActionType.TECHNIQUE else ""
			_coating_state=context.items.coating_state(weapon_uid)
			_enchantment=coating.enchantment if coating else null
			_release_technique=MartialArts.definition(action.skill_id) if release else null
			_release_committed=false
			if action.action_type==Action.ActionType.TECHNIQUE: context.martial.accepted(action.skill_id,context.items.clock_seconds)
			_cancel_work(); _cancel_cast()
			_attack_sequence+=1
			_family="weapon.%s.%d"%[context.id,_attack_sequence]
			if action.action_type==Action.ActionType.MELEE: combo.begin(weapon_uid,attack_moveset(),_family,reserved_stage)
			else: combo.reset()
			if action.action_type in [Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK]: weapon_art.begin(weapon_uid,"light" if action.action_type==Action.ActionType.MELEE else "heavy",_family,weapon.moveset.chain_window if weapon and weapon.moveset else .65,float(_weapon_reservation.get("grace",0)) if reserved and bool(_weapon_reservation.get("history",false)) else 0.0)
			else: weapon_art.reset()
			_weapon_reservation.clear()
			needs.exert(.2,context.actor.get_node("StatsComponent").effective_stat("endurance"))
			mode="attack"; elapsed=0; remaining=profile.windup+profile.active+profile.recovery
			facing=action.direction.normalized() if action.direction.length_squared()>.01 else facing
			_hit_targets={}
			guarding=false
			if context.facts: context.facts.publish("physical_action_started",context.id,{"family":_family,"technique":action.skill_id if action.action_type==Action.ActionType.TECHNIQUE else "","weapon_uid":attack_weapon_uid,"stamina":cost,"counter":counter_strike,"stroke_index":combo.current_index,"stroke_title":profile.title,"stroke_count":combo.moveset.attacks.size() if combo.active else 0,"followup":linked_technique,"art_route":str(action.params.get("art_route","")),"weapon_art":bool(action.params.get("weapon_art",false)),"charged":bool(action.params.get("charged",false))})
			return OperationResult.success()
		Action.ActionType.DODGE:
			if busy() and mode!="attack": return OperationResult.reject("busy")
			if mode=="attack" and elapsed<profile.windup+profile.active: return OperationResult.reject("committed_attack")
			if not stamina.spend(20*burden_cost()*clampf(1+equipment_value("dodge_cost"),.6,1.5)*float(ActorProgression.values(context.actor).dodge_multiplier)): return OperationResult.reject("stamina")
			_clear_sequences(); _buffer=null; _buffer_time=0
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
func cancel_weapon_hold() -> void:
	_weapon_hold.clear()
func _weapon_gesture(edge: Action) -> OperationResult:
	var phase:=str(edge.params.weapon_gesture)
	if phase=="cancel": cancel_weapon_hold(); return OperationResult.success()
	if phase=="aim":
		if _weapon_hold.is_empty(): return OperationResult.reject("unpaired_release")
		_weapon_hold.request.direction=edge.direction
		return OperationResult.success()
	if phase=="begin":
		if mode=="spray": context.spray.stop()
		if mode=="item": context.item_actions.cancel()
		cancel_weapon_hold(); _weapon_reservation.clear(); _buffer=null; _buffer_time=0
		var recovering:=mode=="attack" and profile and elapsed>=profile.windup+profile.active and remaining<=RECOVERY_INPUT_BUFFER_SECONDS+TIME_EPSILON
		if busy() and not recovering: return OperationResult.reject("busy")
		var request:=capture_weapon_art(edge.direction,bool(edge.params.get("release_enchantment",false))) if bool(edge.params.get("art",false)) else Action.melee(context.actor)
		if request.params.get("weapon_art",false) and request.skill_id.is_empty(): return OperationResult.reject("武技未发动：先完成对应连招，K查看条件")
		request.direction=edge.direction
		_gesture_serial+=1
		var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
		request.params["gesture_weapon_uid"]=uid; request.params["gesture_id"]=_gesture_serial
		var weapon:=context.items.equipment_definition(uid)
		var stage:=combo.stage_for(uid,weapon.moveset) if weapon and weapon.moveset else -1
		if recovering and combo.active: stage=(combo.current_index+1)%combo.moveset.attacks.size()
		_weapon_hold={"request":request,"uid":uid,"age":0.0,"ready_age":0.0,"stage":stage,"history":weapon_art.can_continue(recovering)}
		_cancel_work(); _cancel_cast(); guarding=false
		return OperationResult.success()
	if phase!="release" or _weapon_hold.is_empty(): return OperationResult.reject("unpaired_release")
	var request: Action=_weapon_hold.request
	var age:=float(_weapon_hold.age)
	_weapon_reservation={"id":request.params.gesture_id,"uid":_weapon_hold.uid,"stage":_weapon_hold.stage,"history":_weapon_hold.history,"grace":age,"until":weapon_art.clock+RECOVERY_INPUT_BUFFER_SECONDS}
	request.params["charge_credit"]=minf(WEAPON_HOLD_SECONDS,float(_weapon_hold.ready_age))
	cancel_weapon_hold()
	request.direction=edge.direction
	request.params["charged"]=age+TIME_EPSILON>=WEAPON_HOLD_SECONDS
	if request.action_type==Action.ActionType.MELEE and request.params.charged: request.action_type=Action.ActionType.HEAVY_ATTACK
	return try_action(request)
func weapon_hold_view() -> Dictionary:
	if _weapon_hold.is_empty(): return {}
	var request: Action=_weapon_hold.request
	var charged:=float(_weapon_hold.age)+TIME_EPSILON>=WEAPON_HOLD_SECONDS
	var candidate:=next_attack_profile(charged)
	var weapon:=context.items.equipment_definition(str(_weapon_hold.uid))
	if not charged and int(_weapon_hold.stage)>=0 and weapon and weapon.moveset: candidate=weapon.moveset.attacks[int(_weapon_hold.stage)]
	if request.action_type==Action.ActionType.TECHNIQUE:
		var data:=MartialArts.definition(request.skill_id)
		var route:=data.art_route(str(request.params.get("art_route","")))
		candidate=data.attack_form(route.form==MartialRoute.Form.FOLLOWUP,charged)
	if not candidate: return {"title":"无法重发","charged":charged,"progress":1.0,"cost":0.0,"reason":"此武技没有蓄力形式","remaining":0.0,"release_enchantment":false}
	var cost:=attack_stamina_cost(candidate)
	var reason:=context.martial.reason(request.skill_id,context) if request.action_type==Action.ActionType.TECHNIQUE else ""
	if reason.is_empty() and stamina.current<cost: reason="体力不足"
	if reason.is_empty() and not candidate.ammo_id.is_empty() and context.items.ready_uid(context.id,candidate.ammo_id).is_empty(): reason="口袋缺箭"
	if reason.is_empty() and request.params.get("release_enchantment",false) and context.items.coating_state(str(_weapon_hold.uid))!=request.params.get("enchantment_state",{}): reason="所选附魔已改变"
	if reason.is_empty() and request.params.get("release_enchantment",false) and not context.items.coating(str(_weapon_hold.uid)): reason="武器没有可释放的元素附魔"
	var title:=candidate.title
	if title.is_empty(): title="武器重击" if charged else "武器轻击"
	return {"title":title,"charged":charged,"progress":minf(1,float(_weapon_hold.age)/WEAPON_HOLD_SECONDS),"cost":cost,"reason":reason,"remaining":maxf(0,WEAPON_HOLD_LIMIT-float(_weapon_hold.age)),"release_enchantment":bool(request.params.get("release_enchantment",false))}
func buffered_action_label() -> String:
	if not _buffer or _buffer_time<=0: return ""
	return {Action.ActionType.MELEE:"攻击已输入",Action.ActionType.HEAVY_ATTACK:"重击已输入",Action.ActionType.TECHNIQUE:"武技已输入",Action.ActionType.CAST:"施法已输入"}.get(_buffer.action_type,"")
func advance(delta: float) -> void:
	if not active() or not is_instance_valid(context.actor): return
	var actor:=context.actor
	if actor.get_node("HealthComponent").is_dead:
		cancel("dead"); return
	if not _weapon_hold.is_empty():
		_weapon_hold.age=float(_weapon_hold.age)+delta
		if not busy(): _weapon_hold.ready_age=float(_weapon_hold.ready_age)+delta
		var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
		if float(_weapon_hold.age)>WEAPON_HOLD_LIMIT or uid!=str(_weapon_hold.uid) or not context.region.available(): cancel_weapon_hold()
	guard_age=guard_age+delta if guarding else 99.0
	parry_retry=maxf(0,parry_retry-delta)
	counter_remaining=maxf(0,counter_remaining-delta)
	push_recovery=maxf(0,push_recovery-delta)
	combo.advance(delta,str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),"")))
	weapon_art.advance(delta,str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),"")))
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
	ActorProgression.refresh_stamina(actor)
	stamina.advance(delta,guarding,ActorProgression.modifier(actor,"stamina.guarding_regen"))
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
			if mode=="attack" and _release_committed:
				combo.complete(); weapon_art.complete(maxf(0,delta-completion_offset))
			mode="idle"
			# Compare the expiry with the completion inside this physics step,
			# before aging it. Exact-boundary presses must not be discarded.
			if _buffer and _buffer_time+TIME_EPSILON>=completion_offset:
				var queued:=_buffer
				_buffer=null; _buffer_time=0
				_report_refusal(queued,try_action(queued))
			combo.advance(maxf(0,delta-completion_offset),str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),"")))
	_buffer_time=maxf(0,_buffer_time-delta)
	if _buffer_time==0: _buffer=null
	var speed:=float(actor.get("move_speed"))
	var factor:=burden_speed()
	if not _weapon_hold.is_empty(): factor*=.5
	if guarding: factor*=.4
	if mode=="attack": factor*=profile.movement_factor(elapsed)
	if mode=="spray": factor*=.45
	if mode in ["stagger","item"]: factor=0
	var direction:=movement
	if mode=="dodge": direction=facing; speed=600; factor=burden_speed()
	elif sprinting and not busy() and not guarding and movement.length_squared()>.01:
		if stamina.spend(8*delta*burden_cost()*clampf(1+ActorProgression.modifier(context.actor,"stamina.sprint"),.4,1.5)): factor*=1.35
	if actor.get_node("SkillManager").combinations.is_busy(): factor=0
	actor.velocity=direction*speed*factor
	if direction.length_squared()>.01:
		actor.move_and_slide()
		if not busy() and not guarding: facing=direction.normalized()
	if "facing_direction" in actor: actor.facing_direction=facing
	queue_redraw()
func _launch_arrow() -> void:
	var arrow:=WeaponArrow.new(); arrow.context=context; arrow.profile=profile; arrow.direction=facing; arrow.family=_family
	arrow.damage=ActorCombatModel.weapon_damage(context.actor,profile)
	arrow.enchantment=_enchantment; arrow.release_technique=_release_technique
	if _enchantment: arrow.tags.append_array(_enchantment.tags)
	context.region.root.add_child(arrow); arrow.global_position=context.actor.global_position

func _commit_weapon_release() -> bool:
	if _release_committed: return true
	if not context.region.available() or not context.items.commit_weapon_release(context.id,attack_weapon_uid,_ammo_uid,_coating_state,_release_technique!=null,profile.ammo_id): return false
	_release_committed=true; _ammo_uid=""
	weapon_art.released(_family)
	if context.facts: context.facts.publish("physical_action_released",context.id,{"family":_family,"weapon_uid":attack_weapon_uid,"motion":profile.motion})
	if _release_technique and profile.projectile_speed==0:
		var wave:=EnchantmentWave.new(); wave.context=context; wave.enchantment=_enchantment; wave.technique=_release_technique
		wave.direction=facing; wave.family=_family
		wave.hit_targets=_hit_targets
		context.region.root.add_child(wave); wave.global_position=context.actor.global_position
	return true
func equipment_value(key: String) -> float:
	var equipment:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
	return equipment.get_modifier_value(key) if equipment else 0.0
func presentation_snapshot() -> Dictionary:
	# Animation observes the executor clock. No AnimationPlayer callback may commit gameplay.
	if mode=="attack" and profile:
		var phase:="windup" if elapsed<profile.windup else "active" if elapsed<profile.windup+profile.active else "recovery"
		var progress:=elapsed/maxf(.001,profile.windup) if phase=="windup" else (elapsed-profile.windup)/profile.active if phase=="active" else (elapsed-profile.windup-profile.active)/maxf(.001,profile.recovery)
		var key:=str(profile.animation_id) if not profile.animation_id.is_empty() else profile.motion+"_reverse" if profile.swing_direction<0 else profile.motion
		return {"state":key,"phase":phase,"progress":clampf(progress,0,1),"direction":facing,"token":_family,"weapon_uid":attack_weapon_uid}
	if mode in ["dodge","stagger"]: return {"state":mode,"phase":"whole","progress":elapsed/maxf(.001,elapsed+remaining),"direction":facing,"token":mode+":"+str(operation_id)}
	if not _weapon_hold.is_empty(): return {"state":"charge","phase":"windup","progress":clampf(float(_weapon_hold.age)/WEAPON_HOLD_SECONDS,0,1),"direction":_weapon_hold.request.direction,"token":"hold:"+str(_gesture_serial)}
	return {}
func attack_observation() -> Dictionary:
	if mode!="attack" or not profile: return {}
	return {"serial":_attack_sequence,"windup":maxf(0,profile.windup-elapsed),"reach":maxf(profile.reach+profile.step_distance,_release_technique.release_reach if _release_technique else 0),"direction":facing,"angle":maxf(profile.angle_degrees,_release_technique.release_angle if _release_technique else 0),"heavy":profile.guard_pressure>1 or profile.windup>=.35 or _release_technique!=null}
func is_preparing() -> bool:
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	var preparing:=not _weapon_hold.is_empty() or manager.combinations.is_busy() or mode in ["item","aim_item","spray"] or mode=="attack" and profile and profile.projectile_speed>0 and elapsed<profile.windup
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
	var damage:=ActorCombatModel.weapon_damage(context.actor,profile)
	var result:=CombatExecutor.report_hit(context.actor,target,damage,target.global_position,skill,tags,_family,profile.impact,profile)
	confirm_weapon_hit(_family,result,target)
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
			var cost:=maxf(1,impact)*(.4 if shield else .6)*activity_efficiency(SkillMastery.School.DEFENSE)*(hit.strike.guard_pressure if hit.strike else 1.0)*clampf(1+ActorProgression.modifier(context.actor,"stamina.guard"),.4,1.5)
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
	_clear_sequences(); _ammo_uid=""
	counter_remaining=0; counter_strike=false; _push_remaining=0
	if context.item_actions: context.item_actions.cancel("失衡中断使用")
	if context.spray: context.spray.stop("失衡中断喷洒")
	_cancel_work(); _cancel_cast()
	clear_input()
	mode="stagger"; elapsed=0; remaining=seconds
func cancel(_reason := "cancelled") -> void:
	if _reason in ["dead","scope_left","rest_time"]: push_recovery=0
	_clear_sequences(); _ammo_uid=""
	counter_remaining=0; counter_strike=false; _push_remaining=0
	operation_id+=1
	mode="idle"; remaining=0; elapsed=0
	_hit_targets={}
	clear_input()
func clear_input() -> void:
	_clear_sequences()
	movement=Vector2.ZERO; guarding=false; sprinting=false
	_buffer=null; _buffer_time=0
func burden_cost() -> float:
	return maxf(1,context.items.weight(context.id)/maxf(1,context.rules.carry_limit+float(ActorProgression.values(context.actor).carry_bonus))) if context.items else 1.0
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
	if counter_remaining>0: draw_arc(Vector2.ZERO,34,0,TAU*counter_remaining/.85,24,Color("e0bf70"),2,true)
	if guarding: draw_arc(Vector2.ZERO,30,facing.angle()-PI/3,facing.angle()+PI/3,16,Color(.5,.8,1),3,true)

func activity_efficiency(school: SkillMastery.School) -> float:
	var actor:=context.actor
	return actor.mastery_manager.activity_efficiency(school) if "mastery_manager" in actor and actor.mastery_manager else 1.0

func can_guard() -> bool:
	if not context.guard_allowed: return false
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

func _art_profiles() -> Array[AttackProfile]:
	var result: Array[AttackProfile]=[]
	for id in context.martial.learned:
		var data:=MartialArts.definition(id)
		if not data: continue
		for strike in [data.profile,data.followup_profile,data.charged_profile,data.charged_followup_profile]:
			if strike: result.append(strike)
	return result
