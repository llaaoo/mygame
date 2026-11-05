class_name StatsComponent
extends Node
## 属性组件 — 主属性 + 等级 + 派生属性
## 挂载到任意实体（Player/Enemy/NPC），编辑器中配置基础值

## ── 主属性 ──
@export var strength: int = 10       ## 力量 → 物理伤害
@export var intelligence: int = 10   ## 智力 → 魔法伤害/魔能
@export var agility: int = 10        ## 敏捷 → 移动与施法准备
@export var endurance: int = 10      ## 耐力 → 生命与环境伤害耐受

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
var preparation_multiplier := 1.0
var hazard_damage_multiplier := 1.0

## ── 信号 ──
signal stat_changed(stat_name: String, new_value: int)
signal leveled_up(new_level: int)


func _ready() -> void:
	_recalculate_all()


## 重新计算所有派生属性
func _recalculate_all() -> void:
	var values := derived_values()
	max_hp_bonus = values.max_hp_bonus
	max_mana = values.max_mana
	physical_damage = values.physical_damage
	magic_damage = values.magic_damage
	move_speed_bonus = values.move_speed_bonus
	preparation_multiplier = values.preparation_multiplier
	hazard_damage_multiplier = values.hazard_damage_multiplier

## Read-only projection used by training, casting, damage and authored checks.
## Overrides are base primary values; current Buff contributions still apply.
func derived_values(overrides: Dictionary = {}) -> Dictionary:
	var primary := primary_values(overrides)
	return {"primary": primary, "max_hp_bonus": primary.endurance * 5, "max_mana": 30 + primary.intelligence * 3, "physical_damage": primary.strength * 2, "magic_damage": primary.intelligence * 2, "move_speed_bonus": primary.agility * 3.0, "preparation_multiplier": clampf(1 - maxf(0, primary.agility - 10) * .015, .7, 1.0), "hazard_damage_multiplier": clampf(1 - maxf(0, primary.endurance - 10) * .02, .6, 1.0)}

func primary_values(overrides: Dictionary = {}) -> Dictionary:
	var values: Dictionary = {}
	var buffs := get_parent().get_node_or_null("BuffManager") as BuffManager if get_parent() else null
	for key in Buff.PRIMARY_STATS:
		var base := maxi(1, int(overrides.get(key, get(key))))
		values[key] = buffs.effective_primary(key, base) if buffs else base
	return values

static func valid_requirements(requirements: Dictionary) -> bool:
	for key in requirements:
		if key not in Buff.PRIMARY_STATS or not requirements[key] is int or requirements[key] < 1 or requirements[key] > 100: return false
	return true

func meets_requirements(requirements: Dictionary) -> bool:
	if not valid_requirements(requirements): return false
	for key in requirements:
		if effective_stat(key) < requirements[key]: return false
	return true

func describe_requirements(requirements: Dictionary) -> String:
	if not valid_requirements(requirements): return "属性条件配置无效"
	var parts: Array[String] = []
	for key in Buff.PRIMARY_STATS:
		if requirements.has(key): parts.append("%s%d（当前%d）" % [primary_title(key), requirements[key], effective_stat(key)])
	return "、".join(parts)

static func primary_title(key: String) -> String:
	return {"strength": "力量", "intelligence": "智力", "agility": "敏捷", "endurance": "耐力"}.get(key, key)

func effective_stat(key: String) -> int:
	if key not in Buff.PRIMARY_STATS: return 0
	var buffs := get_parent().get_node_or_null("BuffManager") as BuffManager if get_parent() else null
	return buffs.effective_primary(key, int(get(key))) if buffs else int(get(key))



## 修改指定属性（用于 Buff/装备加成/升级）
func modify_stat(stat_name: String, amount: int) -> bool:
	if stat_name not in Buff.PRIMARY_STATS: return false
	match stat_name:
		"strength":     strength = maxi(1, strength + amount)
		"intelligence": intelligence = maxi(1, intelligence + amount)
		"agility":      agility = maxi(1, agility + amount)
		"endurance":    endurance = maxi(1, endurance + amount)
	_recalculate_all()
	stat_changed.emit(stat_name, get(stat_name))
	return true


## 添加经验值（自动检测升级）
func add_experience(amount: int) -> void:
	if amount <= 0: return
	experience += amount
	while experience >= exp_to_next:
		experience -= exp_to_next
		level += 1
		exp_to_next = int(exp_to_next * 1.5)
		attribute_points += 3  # 每级 3 属性点
		leveled_up.emit(level)


## 消耗属性点升级主属性
func spend_attribute_point(stat_name: String) -> bool:
	if attribute_points <= 0 or stat_name not in Buff.PRIMARY_STATS:
		return false
	attribute_points -= 1
	return modify_stat(stat_name, 1)


## 获取格式化的属性摘要
func get_summary() -> String:
	return "Lv.%d  💪%d 🧠%d 🏃%d 🛡️%d" % [level, effective_stat("strength"), effective_stat("intelligence"), effective_stat("agility"), effective_stat("endurance")]
