class_name ActorMagicState
extends SaveRecord
## Permanent capability and the exact paid sacrifice. Resource/attribute bonuses
## never grant this qualification. Defaults preserve pre-awakening-version saves.
@export_storage var schema := 1
@export_storage var awakened := true
@export_storage var aptitude := true
@export_storage var hp_cost := 0
@export_storage var stamina_cost := 0.0
@export_storage var mana_base := 60
@export_storage var source_id := "legacy"
@export_storage var legacy_exempt := true

static func fresh(has_aptitude: bool,starts_awakened: bool) -> ActorMagicState:
	var state:=ActorMagicState.new()
	state.aptitude=has_aptitude
	state.awakened=starts_awakened and has_aptitude
	state.source_id="innate" if state.awakened else ""
	state.legacy_exempt=false
	return state

static func valid_state(data: Variant) -> bool:
	if not data is Dictionary:return false
	for field in ["schema","awakened","aptitude","hp_cost","stamina_cost","mana_base","source_id","legacy_exempt"]:
		if not data.has(field):return false
	var state:=ActorMagicState.new()
	if not SaveFields.valid(state,data):return false
	SaveFields.restore(state,data)
	if state.schema!=1:return false
	if state.hp_cost<0 or state.hp_cost>100000 or not is_finite(state.stamina_cost) or state.stamina_cost<0 or state.stamina_cost>100000:return false
	if state.mana_base<1 or state.mana_base>100000 or state.source_id.length()>256:return false
	if not state.awakened and (state.hp_cost!=0 or state.stamina_cost!=0 or not state.source_id.is_empty() or state.legacy_exempt):return false
	if state.awakened and (not state.aptitude or state.source_id.is_empty()):return false
	if state.legacy_exempt and (state.hp_cost!=0 or state.stamina_cost!=0):return false
	return true

func validate_save_data(data: Variant) -> bool:return valid_state(data)
func deserialize_save_data(data: Dictionary) -> void:
	if valid_state(data):_unknown_save_fields=SaveFields.restore(self,data)

func awakening_reason(actor: Node,hp_sacrifice := 10,stamina_sacrifice := 10.0,base_mana := 60) -> String:
	if awakened:return "已经觉醒，不能重复支付代价"
	if not aptitude:return "没有与魔力共鸣的适性"
	if not is_instance_valid(actor) or not "actor_context" in actor or not actor.actor_context or actor.actor_context.magic!=self:return "觉醒者已不可用"
	var health:=actor.get_node_or_null("HealthComponent") as HealthComponent
	var mana:=actor.get_node_or_null("ManaComponent") as ManaComponent
	var stats:=actor.get_node_or_null("StatsComponent") as StatsComponent
	if not health or health.is_dead or not mana or not stats:return "当前无法承受觉醒"
	if mana.transaction_active():return "资源事务处理中，不能觉醒"
	if hp_sacrifice<0 or hp_sacrifice>=health.max_hp or hp_sacrifice>=50+stats.endurance*5:return "永久生命代价无法承受"
	var actions: ActorActionController=actor.actor_context.actions
	if not actions or not is_finite(stamina_sacrifice) or stamina_sacrifice<0 or stamina_sacrifice>=actions.stamina.maximum or stamina_sacrifice>=80+stats.endurance*2:return "永久体力代价无法承受"
	if base_mana<1 or base_mana>100000:return "觉醒魔力基准无效"
	return ""

func awaken(actor: Node,source: String,hp_sacrifice := 10,stamina_sacrifice := 10.0,base_mana := 60) -> OperationResult:
	var reason:=awakening_reason(actor,hp_sacrifice,stamina_sacrifice,base_mana)
	if not reason.is_empty():return OperationResult.reject(reason)
	if source.is_empty() or source.length()>256:return OperationResult.reject("觉醒来源无效")
	var health:=actor.get_node("HealthComponent") as HealthComponent
	var mana:=actor.get_node("ManaComponent") as ManaComponent
	var stamina: StaminaComponent=actor.actor_context.actions.stamina
	var old_hp:=health.hp;var old_mp:=mana.mp;var old_stamina:=stamina.current
	# All durable fields are committed together before any derived-value observer.
	awakened=true;hp_cost=hp_sacrifice;stamina_cost=stamina_sacrifice;mana_base=base_mana;source_id=source;legacy_exempt=false
	ActorCombatModel.rebuild(actor)
	health.hp=mini(old_hp,health.max_hp);mana.mp=mini(old_mp,mana.max_mp);stamina.current=minf(old_stamina,stamina.maximum)
	health.health_changed.emit(health.hp,health.max_hp);mana.notify_changed()
	if actor.actor_context.facts:actor.actor_context.facts.publish("magic_awakened",actor.actor_context.id,{"source":source,"hp_cost":hp_cost,"stamina_cost":stamina_cost,"mana_base":mana_base})
	return OperationResult.success()
