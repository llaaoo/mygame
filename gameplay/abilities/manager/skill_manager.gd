class_name SkillManager
extends Node
## 技能管理器 — 纯运行态，描述"怎么装备"
## Knowledge/cooldowns/execution; QuickslotLoadout owns mixed shortcuts.
## 执行逻辑委托给 SkillExecutor

## ── 信号 ──
signal binding_changed(source: String)
signal hand_changed(hand: String)          ## "left" / "right"
signal slot_changed(slot_index: int)
signal cooldown_changed(source: String, remaining: float, total: float)
signal skill_used(source: String, skill: SkillData)
signal cast_committed(plan: CastPlan)
signal skill_upgraded(source: String, skill: SkillData, upgrade_id: String, rank: int)

const MAX_SLOTS := 6

## ── 核心依赖 ──
var pool: SkillPool = null                 ## 技能池（ID索引）
var executor: SkillExecutor = null         ## 执行器（计算+执行）
var combinations: ConditionalCastController
var material_operations := false
var restrict_actions := false
var known_actions: Dictionary = {}
var shortcuts:=QuickslotLoadout.new()
var left_hand: SkillInstance:
	get: return shortcuts.instance("left")
var right_hand: SkillInstance:
	get: return shortcuts.instance("right")
var _cooldowns: Dictionary = {}
var _executing := false


func knows_action(skill: SkillData) -> bool:
	if not skill:
		return false
	var id := skill.get_id()
	if material_operations:
		var registry := SpellOperationCatalog.default_catalog()
		if registry.canonical(id) != id:
			return false
		for previous in registry.LEGACY_ACTIONS:
			if registry.LEGACY_ACTIONS[previous]==id and known_actions.has(previous): return true
		var operation := registry.operation(skill.operation_id)
		if operation:
			if not restrict_actions or known_actions.has(id):
				return true
			for alias in operation.aliases + operation.knowledge_actions:
				if known_actions.has(alias):
					return true
			return false
	return not restrict_actions or known_actions.has(id)


func canonical_action(skill: SkillData) -> SkillData:
	if not material_operations or not skill or not pool:
		return skill
	var original_id := skill.get_id()
	var id := SpellOperationCatalog.default_catalog().canonical(original_id)
	var candidate := pool.get_skill(id)
	if candidate and (id != original_id or not candidate.operation_id.is_empty()):
		return candidate
	return skill


func enable_material_operations() -> void:
	if material_operations:
		return
	material_operations = true
	if not pool:
		pool = SkillPool.new()
	# Skill pools are per actor. Definitions remain shared and immutable.
	var catalog := SpellOperationCatalog.default_catalog()
	for operation in catalog.operations:
		pool.remove_skill(operation.action.get_id())
		pool.add_skill(operation.action)
	if left_hand:
		equip_hand("left", left_hand.data)
	if right_hand:
		equip_hand("right", right_hand.data)
	var seen: Dictionary = {}
	for i in range(MAX_SLOTS):
		if not get_slot(i):
			continue
		var next := canonical_action(get_slot(i).data)
		var id := next.get_id()
		if not next.operation_id.is_empty() and seen.has(id):
			shortcuts.clear("slot_%d"%i)
		else:
			seen[id] = true
			equip_slot(i, next)
	# A material-free rune still needs an explicit triggering action.
	for rule in catalog.rules:
		combinations.rules.append(rule)
		combinations.learned_rules[rule.id] = true
	combinations.rule_index.rebuild(combinations.rules)


func _ready() -> void:
	shortcuts.changed.connect(_binding_changed)
	# 自动创建 executor（如果未从外部注入）
	if not executor:
		executor = SkillExecutor.new()
		executor.name = "SkillExecutor"
		add_child(executor)
	combinations = ConditionalCastController.new()
	combinations.name = "ConditionalCasting"
	combinations.setup(self, get_parent() as Node2D)
	add_child(combinations)
	# 禁用独立 _process，改为 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_register_with_simulation")


## 注册到 SimulationRuntime（统一 tick）
func _register_with_simulation() -> void:
	RuntimeRegistration.register_ticker(self)


## 统一 tick 入口（由 SimulationRuntime 驱动，替代独立 _process）
func tick(delta: float) -> void:
	# 更新所有 SkillInstance 冷却
	for source in QuickslotLoadout.SOURCES: _tick_instance(shortcuts.instance(source),delta)

	# 更新 _cooldowns 并发射信号通知 UI
	for key in _cooldowns:
		var cd: float = _cooldowns[key]
		if cd > 0.0:
			cd = maxf(0.0, cd - delta)
			_cooldowns[key] = cd
			cooldown_changed.emit(key, cd, _get_cooldown_total(key))


func _tick_instance(inst: SkillInstance, delta: float) -> void:
	if inst:
		inst.tick(delta)


## ── Loadout 应用（推荐入口） ──

func apply_loadout(loadout: SkillLoadout) -> void:
	if not loadout:
		return
	if loadout.left_hand and pool:
		equip_hand("left", pool.get_skill(loadout.left_hand))
	if loadout.right_hand and pool:
		equip_hand("right", pool.get_skill(loadout.right_hand))
	for i in range(mini(loadout.slots.size(), MAX_SLOTS)):
		var sid := loadout.slots[i]
		if sid and pool:
			equip_slot(i, pool.get_skill(sid))


## ── 装备管理 ──

func _binding_changed(source: String) -> void:
	if combinations and not combinations.pending.is_empty() and combinations.pending.source==source: combinations.cancel("快捷槽已更换")
	binding_changed.emit(source)
	if source in ["left","right"]: hand_changed.emit(source)
	elif source.begins_with("slot_"): slot_changed.emit(source.trim_prefix("slot_").to_int())

func equip_source(source: String,skill: SkillData,selection: Dictionary={}) -> bool:
	skill=canonical_action(skill)
	if skill and (not knows_action(skill) or skill.combination_only): return false
	return shortcuts.equip_skill(source,skill,selection)

func equip_hand(hand: String,skill: SkillData) -> void:
	if hand in ["left","right"]: equip_source(hand,skill)
func unequip_hand(hand: String) -> SkillData:
	var old:=get_instance(hand)
	if hand in ["left","right"]: shortcuts.clear(hand)
	return old.data if old else null
func equip_slot(idx: int,skill: SkillData) -> void:
	if idx>=0 and idx<MAX_SLOTS: equip_source("slot_%d"%idx,skill)
func unequip_slot(idx: int) -> SkillData:
	var old:=get_slot(idx)
	if idx>=0 and idx<MAX_SLOTS: shortcuts.clear("slot_%d"%idx)
	return old.data if old else null

## ── 查询 ──

func get_slot(idx: int) -> SkillInstance:
	if idx < 0 or idx >= MAX_SLOTS:
		return null
	return shortcuts.instance("slot_%d"%idx)


func get_instance(source: String) -> SkillInstance:
	return _find_instance(source)


func get_upgrade_options(source: String) -> Array[Resource]:
	var inst := _find_instance(source)
	return inst.get_available_upgrades() if inst else []


func upgrade_source(source: String, upgrade_id: String) -> bool:
	var inst := _find_instance(source)
	if not inst or not inst.apply_upgrade(upgrade_id):
		return false
	_cooldowns[source] = inst.current_cooldown
	skill_upgraded.emit(source, inst.data, upgrade_id, inst.get_upgrade_rank(upgrade_id))
	return true


func serialize_skill_state() -> Dictionary:
	return shortcuts.snapshot()

func restore_skill_state(saved_state: Dictionary) -> void:
	if not pool: return
	for source in saved_state:
		if source not in QuickslotLoadout.SOURCES: continue
		var entry: Variant=saved_state[source]
		if not QuickslotLoadout.valid_entry(entry): continue
		if entry.get("kind","")=="technique":
			shortcuts.bind_technique(source,entry.technique_id); continue
		if entry.get("kind","")=="item":
			shortcuts.bind_item(source,entry.item_id,str(entry.get("uid",""))); continue
		var skill:=pool.get_skill(str(entry.get("skill_id","")))
		if not skill or not equip_source(source,skill,entry.get("selection",{})): continue
		var inst:=get_instance(source)
		if inst: inst.restore_upgrades(entry.get("upgrades",{}))
	if material_operations: normalize_operation_loadout(saved_state)


func has_left_spell() -> bool:
	return left_hand != null


func has_right_spell() -> bool:
	return right_hand != null


func can_use(source: String) -> bool:
	var inst := _find_instance(source)
	if combinations and inst and combinations.handles(inst.data):
		return get_cooldown(source) <= 0.0
	return _cooldowns.get(source, 0.0) <= 0.0


func preview_source(source: String,empower := false) -> CastPlan:
	var inst:=get_instance(source)
	return combinations.preview(inst.data,get_parent(),empower,shortcuts.selection(source)) if inst else CastPlan.new()

func get_cooldown_state(source: String, plan: CastPlan = null) -> Dictionary:
	var inst := _find_instance(source)
	if combinations and inst and combinations.handles(inst.data):
		if not plan:
			plan = preview_source(source)
		return combinations.cooldown_state(plan, inst.data.get_id())
	return {"remaining": float(_cooldowns.get(source, 0.0)), "duration": inst.total_cooldown if inst else 1.0}

func get_cooldown(source: String) -> float:
	return get_cooldown_state(source).remaining

func get_cooldown_total(source: String) -> float:
	return get_cooldown_state(source).duration

## Validate the same explicit request that execution will accept.
func can_start(source: String, caster: Node2D, context: CastContext) -> bool:
	if not can_act(caster): return false
	var inst := _find_instance(source)
	if context and context.binding_revision>=0 and shortcuts.revision(source)!=context.binding_revision: return false
	var selection: Dictionary=context.selection if context and not context.selection.is_empty() else shortcuts.selection(source)
	if not context or not context.has_valid_target() or _executing or not inst or not knows_action(inst.data) or inst.data.combination_only:
		return false
	if combinations and combinations.handles(inst.data):
		return combinations.preview(inst.data, caster, context.empower,selection).ready
	if combinations and combinations.is_busy():
		return false
	var mana := caster.get_node_or_null("ManaComponent") as ManaComponent
	var plan := combinations.build_plan(inst.data, caster, context.empower,selection) if combinations else null
	var cost := plan.cost if plan else _get_effective_mana_cost(inst.data, caster)
	return inst.is_ready() and (not mana or mana.mp >= cost) and (not plan or combinations.supplies.can_pay_combat(plan.material_costs))

func use_source(source: String, caster: Node2D, context: CastContext) -> bool:
	var inst := _find_instance(source)
	return _execute_with_context(inst.data, source, caster, context) if inst else false


## Channel pulses share ordinary material/status transactions; rate costs replace base MP.
func use_channel_tick(source: String, caster: Node2D, context: CastContext, mana_cost: int) -> bool:
	var inst := _find_instance(source)
	if not inst or inst.data.cast_type != "channel" or inst.data.conditional_cast:
		return false
	return _execute_with_context(inst.data, source, caster, context, mana_cost)

## ── 释放（委托给 SkillExecutor） ──

func use_hand(hand: String, caster: Node2D, direction: Vector2) -> bool:
	var inst: SkillInstance = left_hand if hand == "left" else right_hand
	if not inst or not inst.data:
		return false
	return _execute(inst.data, hand, caster, direction)


func use_slot(idx: int, caster: Node2D, direction: Vector2) -> bool:
	if idx < 0 or idx >= MAX_SLOTS:
		return false
	var inst := get_slot(idx)
	if not inst or not inst.data:
		return false
	return _execute(inst.data, "slot_%d" % idx, caster, direction)


## 使用预构建 CastContext（蓄力等自定义参数）
func use_hand_with_context(hand: String, caster: Node2D, ctx: CastContext) -> bool:
	var inst: SkillInstance = left_hand if hand == "left" else right_hand
	if not inst or not inst.data:
		return false
	return _execute_with_context(inst.data, hand, caster, ctx)


func use_slot_with_context(idx: int, caster: Node2D, ctx: CastContext) -> bool:
	if idx < 0 or idx >= MAX_SLOTS:
		return false
	var inst := get_slot(idx)
	if not inst or not inst.data:
		return false
	return _execute_with_context(inst.data, "slot_%d" % idx, caster, ctx)


## ── 内部执行（委托给 SkillExecutor） ──

func _execute(skill: SkillData, source: String, caster: Node2D, direction: Vector2) -> bool:
	# Compatibility input adapter; explicit contexts never resample the keyboard.
	var context := CastContext.simple(caster, direction, skill)
	context.empower = Input.is_key_pressed(KEY_SHIFT)
	return _execute_with_context(skill, source, caster, context)


func _execute_with_context(skill: SkillData, source: String, caster: Node2D, ctx: CastContext, channel_cost: int = -1) -> bool:
	if not can_act(caster): return false
	if not ctx or not ctx.has_valid_target() or _executing or not knows_action(skill):
		return false
	if ctx.binding_revision>=0 and shortcuts.revision(source)!=ctx.binding_revision: return false
	if ctx.selection.is_empty(): ctx.selection=shortcuts.selection(source)
	if skill.combination_only:
		return false
	if skill.operation_id=="disperse" and "actor_context" in caster and caster.actor_context and caster.actor_context.spray:
		return caster.actor_context.spray.start(skill,source,ctx.direction,ctx.selection)
	if combinations and combinations.handles(skill):
		return combinations.start(skill, caster, ctx, source)
	if combinations and combinations.is_busy():
		return false
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_cast_sequence()

	var inst := _find_instance(source)
	if inst and channel_cost < 0 and not inst.is_ready():
		if exec_inst:
			exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		return false

	var plan := combinations.build_plan(skill, caster, ctx.empower,ctx.selection) if combinations else CastPlan.new()
	if not skill.operation_id.is_empty() and combinations:
		plan=combinations.preview_pulse(skill,caster,ctx.empower,channel_cost,ctx.selection) if channel_cost>=0 else combinations.preview(skill,caster,ctx.empower,ctx.selection)
		if not plan.ready:
			if exec_inst: exec_inst.enter_phase(CombatPhase.Phase.IDLE)
			return false
	if not combinations:
		plan.skill = skill
		plan.cost = _get_effective_mana_cost(skill, caster)
		plan.cooldown = _get_effective_cooldown(skill, caster)
	if channel_cost >= 0 and skill.operation_id.is_empty():
		plan.cost = maxi(0, plan.cost - _get_effective_mana_cost(skill, caster) + channel_cost)
	plan.actor = caster
	plan.action = skill
	plan.source = source
	_executing = true
	var transaction := CastTransaction.new(caster, combinations.supplies if combinations else null, CastTransaction.allocate_id())
	if not transaction.reserve(plan):
		transaction.rollback()
		_executing = false
		if exec_inst:
			exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		return false
	ctx.caster = caster
	ctx.skill = plan.skill
	ctx.batch = transaction.batch
	if not is_instance_valid(ctx.world):
		ctx.world = CastContext.default_world(caster)
	if not executor.execute(plan.skill, ctx):
		transaction.rollback()
		_executing = false
		if exec_inst:
			exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		return false
	var cooldown := plan.cooldown
	if channel_cost < 0:
		if inst:
			inst.total_cooldown = cooldown
			inst.current_cooldown = cooldown
		_cooldowns[source] = cooldown
	executor.commit_batch(transaction.batch, transaction.commit)
	_executing = false
	if channel_cost < 0:
		cooldown_changed.emit(source, cooldown, cooldown)
	skill_used.emit(source, plan.skill)
	cast_committed.emit(plan)
	return true


func _find_instance(source: String) -> SkillInstance:
	return shortcuts.instance(source)

func _all_sources() -> Array[String]:
	var sources: Array[String]=[]
	sources.assign(QuickslotLoadout.SOURCES)
	return sources


## ── 冷却内部 ──

func _get_cooldown_total(source: String) -> float:
	return get_cooldown_total(source)

func _get_effective_cooldown(skill: SkillData, caster: Node2D) -> float:
	return effective_cooldown(skill, caster, skill.cooldown)

func effective_cooldown(skill: SkillData, caster: Node2D, base_duration: float) -> float:
	return CastCostPolicy.cooldown(skill, caster, base_duration)

func _get_effective_mana_cost(skill: SkillData, caster: Node2D) -> int:
	return effective_mana_cost(skill, caster, skill.mp_cost)

func effective_mana_cost(skill: SkillData, caster: Node2D, base_cost: int) -> int:
	return CastCostPolicy.mana_cost(skill, caster, base_cost)


## ── 初始化（兼容旧 API） ──

func initialize(pool_res: SkillPool) -> void:
	pool = pool_res
	pool.build()
	for i in range(MAX_SLOTS):
		shortcuts.clear("slot_%d"%i)
		if pool_res and i < pool_res.skills.size():
			equip_slot(i,pool_res.skills[i])

func can_act(actor: Node2D) -> bool:
	var buffs:=actor.get_node_or_null("BuffManager") as BuffManager
	return not buffs or not buffs.prevents_actions()

func normalize_operation_loadout(saved: Dictionary={}) -> void:
	var seen: Dictionary={}
	for source in saved:
		var entry: Dictionary=saved[source]
		var original:=str(entry.get("skill_id",""))
		var inst:=get_instance(source)
		if not inst or original==inst.base_data.get_id(): continue
		if seen.has(inst.base_data.get_id()): shortcuts.clear(source)
		else: seen[inst.base_data.get_id()]=true
