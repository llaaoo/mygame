class_name Buff
extends Resource
## Buff/被动效果 — 可被装备、技能、消耗品等任何系统复用
##
## duration = 0 表示永久（装备类 Buff）
## tick_interval = 0 表示不触发 tick

## 显示名称
@export var display_name: String = ""

## 图标
@export var icon: Texture2D

## 持续时间（秒，0=永久）
@export var duration: float = 0.0

## tick 间隔（秒，0=不触发）
@export var tick_interval: float = 0.0

## 属性加成（固定值）
## 支持: strength/intelligence/agility/endurance (主属性, StatsComponent)
##       max_hp (HealthComponent), move_speed (Player), attack_damage (CombatComponent)
@export var stat_modifiers: Dictionary = {}

## 属性百分比加成（如 {"atk": 0.1} = +10% 攻击力）
@export var stat_multipliers: Dictionary = {}

## tick 时回复 HP
@export var tick_heal: int = 0

## ── 主属性名集合 ──
const PRIMARY_STATS: Array[String] = ["strength", "intelligence", "agility", "endurance"]


## 应用此 Buff 到目标实体
func apply_to(entity: Node) -> void:
	if not entity:
		return
	for stat_name in stat_modifiers:
		_apply_stat(entity, stat_name, stat_modifiers[stat_name])


## 从目标实体移除此 Buff
func remove_from(entity: Node) -> void:
	if not entity:
		return
	for stat_name in stat_modifiers:
		_apply_stat(entity, stat_name, -stat_modifiers[stat_name])


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
