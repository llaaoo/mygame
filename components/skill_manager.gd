class_name SkillManager
extends Node
## 技能管理器 — 管理多个技能的冷却和释放
## 挂载到任意实体（Player/Enemy），编辑器中配置 skills 数组

signal skill_used(skill: SkillData)
signal cooldown_changed(skill_index: int, remaining: float, total: float)

## 已装备的技能列表
@export var skills: Array[SkillData] = []

## 每个技能的剩余冷却（索引 → float）
var _cooldowns: Array[float] = []


func _ready() -> void:
	_cooldowns.resize(skills.size())
	for i in range(_cooldowns.size()):
		_cooldowns[i] = 0.0


func _process(delta: float) -> void:
	for i in range(_cooldowns.size()):
		if _cooldowns[i] > 0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
			if skills[i]:
				cooldown_changed.emit(i, _cooldowns[i], skills[i].cooldown)


## 释放指定索引的技能。caster 需有 global_position
func use_skill(index: int, caster: Node2D, direction: Vector2) -> bool:
	if index < 0 or index >= skills.size():
		return false

	var skill := skills[index]
	if not skill or not skill.scene:
		return false
	if _cooldowns[index] > 0:
		return false

	# 实例化投射物
	var instance := skill.scene.instantiate() as Node2D
	caster.get_tree().current_scene.add_child(instance)
	instance.global_position = caster.global_position + direction * skill.cast_distance

	if instance.has_method("set_direction"):
		instance.set_direction(direction)
	if instance.has_method("set_caster"):
		instance.set_caster(caster)
	if "damage" in instance:
		instance.damage = skill.damage
	if "speed" in instance:
		instance.speed = skill.projectile_speed

	# 设置冷却
	_cooldowns[index] = skill.cooldown
	cooldown_changed.emit(index, skill.cooldown, skill.cooldown)
	skill_used.emit(skill)
	return true


## 查询冷却
func can_use(index: int) -> bool:
	if index < 0 or index >= skills.size():
		return false
	return skills[index] != null and _cooldowns[index] <= 0


func get_cooldown_remaining(index: int) -> float:
	if index < 0 or index >= _cooldowns.size():
		return 0.0
	return _cooldowns[index]


func get_cooldown_total(index: int) -> float:
	if index < 0 or index >= skills.size() or not skills[index]:
		return 1.0
	return skills[index].cooldown
