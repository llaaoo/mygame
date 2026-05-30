class_name SummonManager
extends Node
## 召唤物管理器 — 追踪所有活跃召唤物，分发攻击/复仇指令
##
## 职责:
##   1. 追踪活跃召唤物（上限 MAX_SUMMONS）
##   2. 监听 CombatEventBus ON_HIT 事件 → 设定 attack_target / revenge_target
##   3. 提供 can_summon() / register() / unregister() 接口
##   4. 玩家死亡时清理所有召唤物

const MAX_SUMMONS := 3

## ── 运行时状态 ──
var active_summons: Array[SummonEntity] = []
var attack_target: Node2D = null       ## 玩家攻击的目标 → 召唤物集火
var revenge_target: Node2D = null      ## 伤害了玩家的敌人 → 召唤物复仇
var player: Player = null

## ── 信号 ──
signal summon_added(entity: SummonEntity)
signal summon_removed(entity: SummonEntity)
signal summons_changed


func _ready() -> void:
	player = get_parent() as Player
	if not player:
		push_warning("[SummonManager] 父节点不是 Player，召唤物指令系统将不工作")
		return

	# 延迟订阅 CombatEventBus（等待 GameRuntime 初始化）
	call_deferred("_subscribe_events")


func _subscribe_events() -> void:
	var bus := CombatEventBus.instance
	if not bus:
		await get_tree().process_frame
		_subscribe_events()
		return

	bus.subscribe(CombatEvent.Type.ON_HIT, _on_combat_event)
	bus.subscribe(CombatEvent.Type.ON_KILL, _on_combat_event)
	print("📡 [SummonManager] 已订阅 CombatEventBus (ON_HIT + ON_KILL)")


## ── 公共接口 ──

func can_summon() -> bool:
	return active_summons.size() < MAX_SUMMONS


func register(entity: SummonEntity) -> void:
	if entity in active_summons:
		return
	active_summons.append(entity)
	summon_added.emit(entity)
	summons_changed.emit()
	print("👻 [SummonManager] 召唤物加入: %s (%d/%d)" % [entity.summon_name, active_summons.size(), MAX_SUMMONS])


func unregister(entity: SummonEntity) -> void:
	var idx := active_summons.find(entity)
	if idx >= 0:
		active_summons.remove_at(idx)
		summon_removed.emit(entity)
		summons_changed.emit()
		print("💀 [SummonManager] 召唤物离开: %s (%d/%d)" % [entity.summon_name, active_summons.size(), MAX_SUMMONS])


func clear_all() -> void:
	for summon in active_summons:
		if is_instance_valid(summon):
			summon.queue_free()
	active_summons.clear()
	attack_target = null
	revenge_target = null
	summons_changed.emit()


## ── 事件处理 ──

func _on_combat_event(ev: CombatEvent) -> void:
	if not player:
		return

	match ev.type:
		CombatEvent.Type.ON_HIT:
			_on_player_hit_something(ev)
			_on_player_got_hit(ev)
		CombatEvent.Type.ON_KILL:
			# 目标死亡 → 清除对应指令
			_clear_dead_target(ev)


## 玩家命中了某目标 → 设为召唤物攻击目标
func _on_player_hit_something(ev: CombatEvent) -> void:
	if ev.source != player:
		return
	if not is_instance_valid(ev.target):
		return
	attack_target = ev.target


## 玩家被某目标命中 → 设为召唤物复仇目标（优先级高于攻击目标）
func _on_player_got_hit(ev: CombatEvent) -> void:
	if ev.target != player:
		return
	if not is_instance_valid(ev.source):
		return
	# 只对敌人复仇
	if not ev.source.is_in_group("enemy"):
		return
	revenge_target = ev.source


## 目标死亡 → 清除指令
func _clear_dead_target(ev: CombatEvent) -> void:
	if attack_target == ev.target:
		attack_target = null
	if revenge_target == ev.target:
		revenge_target = null


## ── 获取当前最高优先级目标 ──
## 优先级: revenge_target > attack_target > null
func get_priority_target() -> Node2D:
	if is_instance_valid(revenge_target):
		return revenge_target
	if is_instance_valid(attack_target):
		return attack_target
	return null
