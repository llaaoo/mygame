class_name Buff
extends Resource
## Buff/被动效果/状态 — 可被装备、技能、消耗品、表面交互等任何系统复用
##
## duration = 0 表示永久（装备类 Buff）
## tick_interval = 0 表示不触发 tick
## status_id 非空时视为"状态"（burning/frozen/poison 等），参与 Surface 交互和 AI 查询

## ── 核心标识 ──
@export var display_name: String = ""
@export var icon: Texture2D
@export var status_id: String = ""               ## "burning"/"frozen"/"wet"/"poison"/"shock"/"bleeding" — 空=纯数值Buff

## ── 生命周期 ──
@export var duration: float = 0.0                ## 秒，0=永久
@export var tick_interval: float = 0.0           ## 秒，0=不触发

## ── 叠加规则 ──
enum StackBehavior { REFRESH, INTENSITY, INDEPENDENT }
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH
@export var max_stacks: int = 1                  ## INTENSITY 模式最大层数

## ── 属性加成（固定值） ──
@export var stat_modifiers: Dictionary = {}

## ── 属性百分比加成 ──
@export var stat_multipliers: Dictionary = {}

## ── Tick 效果 ──
@export var tick_heal: int = 0                   ## 每 tick 回复 HP
@export var tick_damage: int = 0                 ## 每 tick 造成伤害
@export var tick_damage_scaling: float = 0.0     ## 伤害属性缩放系数
@export var speed_multiplier: float = 1.0        ## 移动速度倍率（0.5=减速50%, 移除时还原）

## ── 主属性名集合 ──
const PRIMARY_STATS: Array[String] = ["strength", "intelligence", "agility", "endurance"]


## 描述 Buff 效果为可读字符串（供 trace/debug 使用）
func describe() -> String:
	var parts: Array[String] = []
	var name := display_name if not display_name.is_empty() else "未命名效果"

	for stat in stat_modifiers:
		var val: float = stat_modifiers[stat]
		var sign := "+" if val >= 0 else ""
		parts.append("%s%s%d" % [stat, sign, int(val)])

	for stat in stat_multipliers:
		var val: float = stat_multipliers[stat]
		var sign := "+" if val >= 0 else ""
		parts.append("%s%s%d%%" % [stat, sign, int(val * 100)])

	if tick_damage > 0:
		parts.append("DOT+%d/%ds" % [tick_damage, tick_interval])
	if tick_heal > 0:
		parts.append("HOT+%d/%ds" % [tick_heal, tick_interval])
	if speed_multiplier != 1.0:
		var pct := int((1.0 - speed_multiplier) * 100)
		parts.append("slow%d%%" % pct)

	var effect_str := ", ".join(parts) if not parts.is_empty() else "无属性效果"
	var dur_str := " (%.1fs)" % duration if duration > 0 else " (永久)"
	return "%s: %s%s" % [name, effect_str, dur_str]


## 应用此 Buff 到目标实体
func apply_to(entity: Node) -> void:
	if not entity:
		return
	for stat_name in stat_modifiers:
		_apply_stat(entity, stat_name, stat_modifiers[stat_name])
	
	# 速度修正
	if speed_multiplier != 1.0 and "move_speed" in entity:
		entity.move_speed *= speed_multiplier


## 从目标实体移除此 Buff
func remove_from(entity: Node) -> void:
	if not entity:
		return
	for stat_name in stat_modifiers:
		_apply_stat(entity, stat_name, -stat_modifiers[stat_name])
	
	# 还原速度
	if speed_multiplier != 1.0 and "move_speed" in entity and speed_multiplier != 0.0:
		entity.move_speed /= speed_multiplier


## 应用单个属性修改
func _apply_stat(entity: Node, stat_name: String, amount: float) -> void:
	var amt := int(amount)
	if amt == 0:
		return

	# 1. 主属性 → StatsComponent.modify_stat（会触发 _apply_stats）
	if stat_name in PRIMARY_STATS:
		var stats := _get_stats_component(entity)
		if stats:
			stats.modify_stat(stat_name, amt)
		return

	# 2. max_hp → HealthComponent
	if stat_name == "max_hp":
		var hp := entity.get_node_or_null("HealthComponent") as HealthComponent
		if hp:
			hp.max_hp += amt
			hp.hp = clampi(hp.hp + amt, 1, hp.max_hp)
			hp.health_changed.emit(hp.hp, hp.max_hp)
		return

	# 3. attack_damage → CombatComponent
	if stat_name == "attack_damage":
		var combat := entity.get_node_or_null("CombatComponent") as CombatComponent
		if combat:
			combat.attack_damage += amt
		return

	# 4. 直接属性（如 move_speed, base_move_speed 在 Player 上）
	if stat_name in entity:
		entity.set(stat_name, entity.get(stat_name) + amt)


## 查找实体上的 StatsComponent
func _get_stats_component(entity: Node) -> StatsComponent:
	if entity is Player:
		return entity.stats_component
	return entity.get_node_or_null("StatsComponent") as StatsComponent
