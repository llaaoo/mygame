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
@export var stat_modifiers: Dictionary = {}

## 属性百分比加成
@export var stat_multipliers: Dictionary = {}

## tick 时回复 HP
@export var tick_heal: int = 0


## 应用此 Buff 到目标实体
func apply_to(entity: Node) -> void:
	if not entity:
		return
	for stat in stat_modifiers:
		_apply_stat(entity, stat, stat_modifiers[stat])


## 从目标实体移除此 Buff
func remove_from(entity: Node) -> void:
	if not entity:
		return
	for stat in stat_modifiers:
		_apply_stat(entity, stat, -stat_modifiers[stat])


## 应用单个属性修改
func _apply_stat(entity: Node, stat: String, amount: float) -> void:
	if stat in entity:
		entity.set(stat, entity.get(stat) + amount)
