class_name SkillManager
extends Node
## 技能管理器 — 纯运行态，描述"怎么装备"
## 左手/右手 + 4 快捷键槽位
## 执行逻辑委托给 SkillExecutor

const MAX_SLOTS := 6

## ── 信号 ──
signal hand_changed(hand: String)          ## "left" / "right"
signal slot_changed(slot_index: int)
signal cooldown_changed(source: String, remaining: float, total: float)
signal skill_used(source: String, skill: SkillData)

## ── 核心依赖 ──
var pool: SkillPool = null                 ## 技能池（ID索引）
var executor: SkillExecutor = null         ## 执行器（计算+执行）

## ── 左右手（SkillInstance 包装） ──
var left_hand: SkillInstance = null
var right_hand: SkillInstance = null

## ── 快捷键槽位 ──
var _slots: Array[SkillInstance] = []

## ── 冷却（统一字典，source → remaining） ──
var _cooldowns: Dictionary = {}


func _ready() -> void:
	_slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		_slots[i] = null
	# 自动创建 executor（如果未从外部注入）
	if not executor:
		executor = SkillExecutor.new()
		executor.name = "SkillExecutor"
		add_child(executor)
	# 禁用独立 _process，改为 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_register_with_simulation")


## 注册到 SimulationRuntime（统一 tick）
func _register_with_simulation() -> void:
	var gr := GameRuntime.instance
	if not gr:
		call_deferred("_register_with_simulation")
		return
	var sim := gr.get_simulation_runtime()
	if not sim:
		call_deferred("_register_with_simulation")
		return
	sim.register_ticker(self)


## 统一 tick 入口（由 SimulationRuntime 驱动，替代独立 _process）
func tick(delta: float) -> void:
	# 更新所有 SkillInstance 冷却
	_tick_instance(left_hand, delta)
	_tick_instance(right_hand, delta)
	for i in range(MAX_SLOTS):
		_tick_instance(_slots[i], delta)

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

func equip_hand(hand: String, skill: SkillData) -> void:
	var inst := SkillInstance.new(skill) if skill else null
	match hand:
		"left":  left_hand = inst
		"right": right_hand = inst
	hand_changed.emit(hand)


func unequip_hand(hand: String) -> SkillData:
	var old: SkillData = null
	match hand:
		"left":
			if left_hand: old = left_hand.data
			left_hand = null
		"right":
			if right_hand: old = right_hand.data
			right_hand = null
	hand_changed.emit(hand)
	return old


func equip_slot(idx: int, skill: SkillData) -> void:
	if idx < 0 or idx >= MAX_SLOTS:
		return
	_slots[idx] = SkillInstance.new(skill) if skill else null
	slot_changed.emit(idx)


func unequip_slot(idx: int) -> SkillData:
	if idx < 0 or idx >= MAX_SLOTS:
		return null
	var old: SkillData = _slots[idx].data if _slots[idx] else null
	_slots[idx] = null
	slot_changed.emit(idx)
	return old


## ── 查询 ──

func get_slot(idx: int) -> SkillInstance:
	if idx < 0 or idx >= MAX_SLOTS:
		return null
	return _slots[idx]


func has_left_spell() -> bool:
	return left_hand != null


func has_right_spell() -> bool:
	return right_hand != null


func can_use(source: String) -> bool:
	return _cooldowns.get(source, 0.0) <= 0.0


func get_cooldown(source: String) -> float:
	return _cooldowns.get(source, 0.0)


func get_cooldown_total(source: String) -> float:
	return _get_cooldown_total(source)


## ── 释放（委托给 SkillExecutor） ──

func use_hand(hand: String, caster: Node2D, direction: Vector2) -> bool:
	var inst: SkillInstance = left_hand if hand == "left" else right_hand
	if not inst or not inst.data:
		return false
	return _execute(inst.data, hand, caster, direction)


func use_slot(idx: int, caster: Node2D, direction: Vector2) -> bool:
	if idx < 0 or idx >= MAX_SLOTS:
		return false
	var inst := _slots[idx]
	if not inst or not inst.data:
		return false
	return _execute(inst.data, "slot_%d" % idx, caster, direction)


## ── 内部执行（委托给 SkillExecutor） ──

func _execute(skill: SkillData, source: String, caster: Node2D, direction: Vector2) -> bool:
	# ── INPUT 阶段（阶段机门控） ──
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_cast_sequence()

	# 冷却检查
	var inst := _find_instance(source)
	if inst and not inst.is_ready():
		if exec_inst:
			exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		return false

	# MP 检查
	var mana := caster.get_node_or_null("ManaComponent") as ManaComponent
	if mana and skill.mp_cost > 0 and not mana.use_mp(skill.mp_cost):
		if exec_inst:
			exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		return false

	# 委托给 SkillExecutor（内部驱动 MODIFIER → EFFECT → EVENT → POST → IDLE）
	var ctx := CastContext.simple(caster, direction, skill)
	var ok := executor.execute(skill, ctx)

	if not ok:
		if mana and skill.mp_cost > 0:
			mana.restore_mp(skill.mp_cost)
		if exec_inst:
			exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		return false

	# 触发冷却（POST 之后）
	if inst:
		inst.trigger_cooldown()
	_cooldowns[source] = skill.cooldown
	cooldown_changed.emit(source, skill.cooldown, skill.cooldown)
	skill_used.emit(source, skill)
	return true


func _find_instance(source: String) -> SkillInstance:
	match source:
		"left":  return left_hand
		"right": return right_hand
	var idx := source.trim_prefix("slot_").to_int()
	if idx >= 0 and idx < MAX_SLOTS:
		return _slots[idx]
	return null


## ── 冷却内部 ──

func _get_cooldown_total(source: String) -> float:
	var inst := _find_instance(source)
	if inst and inst.data:
		return inst.data.cooldown
	return 1.0


## ── 初始化（兼容旧 API） ──

func initialize(pool_res: SkillPool) -> void:
	pool = pool_res
	pool.build()
	for i in range(MAX_SLOTS):
		_slots[i] = null
		if pool_res and i < pool_res.skills.size():
			_slots[i] = SkillInstance.new(pool_res.skills[i])
			slot_changed.emit(i)
