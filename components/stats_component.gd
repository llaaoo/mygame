class_name StatsComponent
extends Node
## 属性组件 — 主属性 + 等级 + 派生属性
## 挂载到任意实体（Player/Enemy/NPC），编辑器中配置基础值

## ── 主属性 ──
@export var strength: int = 10       ## 力量 → 物理伤害
@export var intelligence: int = 10   ## 智力 → 魔法伤害/魔能
@export var agility: int = 10        ## 敏捷 → 移动速度/暴击
@export var endurance: int = 10      ## 耐力 → 生命值/体力

## ── 等级 ──
@export var level: int = 1
@export var experience: int = 0
@export var exp_to_next: int = 100
@export var attribute_points: int = 0  ## 可用属性点

## ── 派生属性（运行时计算） ──
var max_hp_bonus: int = 0        ## 来自耐力的额外 HP
var max_mana: int = 0            ## 魔能上限
var physical_damage: int = 0     ## 物理伤害加成
var magic_damage: int = 0        ## 魔法伤害加成
var move_speed_bonus: float = 0.0  ## 移动速度加成

## ── 信号 ──
signal stat_changed(stat_name: String, new_value: int)
signal leveled_up(new_level: int)


func _ready() -> void:
	_recalculate_all()


## 重新计算所有派生属性
func _recalculate_all() -> void:
	max_hp_bonus = endurance * 5
	max_mana = 30 + intelligence * 3
	physical_damage = strength * 2
	magic_damage = intelligence * 2
	move_speed_bonus = agility * 3.0


## 修改指定属性（用于 Buff/装备加成/升级）
func modify_stat(stat_name: String, amount: int) -> void:
	match stat_name:
		"strength":     strength = maxi(1, strength + amount)
		"intelligence": intelligence = maxi(1, intelligence + amount)
		"agility":      agility = maxi(1, agility + amount)
		"endurance":    endurance = maxi(1, endurance + amount)
	_recalculate_all()
	stat_changed.emit(stat_name, get(stat_name))


## 添加经验值（自动检测升级）
func add_experience(amount: int) -> void:
	experience += amount
	while experience >= exp_to_next:
		experience -= exp_to_next
		level += 1
		exp_to_next = int(exp_to_next * 1.5)
		attribute_points += 3  # 每级 3 属性点
		leveled_up.emit(level)


## 消耗属性点升级主属性
func spend_attribute_point(stat_name: String) -> bool:
	if attribute_points <= 0:
		return false
	modify_stat(stat_name, 1)
	attribute_points -= 1
	return true


## 获取格式化的属性摘要
func get_summary() -> String:
	return "Lv.%d  💪%d 🧠%d 🏃%d 🛡️%d" % [level, strength, intelligence, agility, endurance]
