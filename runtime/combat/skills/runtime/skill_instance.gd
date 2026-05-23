class_name SkillInstance
extends RefCounted
## 技能运行时实例 — 包装 SkillData + 运行时状态（冷却等）
## 用于 SkillLoadout 的槽位映射

var data: SkillData = null
var current_cooldown: float = 0.0      ## 剩余冷却时间
var total_cooldown: float = 0.0        ## 总冷却时间（快取）


func _init(skill: SkillData = null) -> void:
	if skill:
		bind(skill)


func bind(skill: SkillData) -> void:
	data = skill
	total_cooldown = skill.cooldown if skill else 0.0
	current_cooldown = 0.0


func trigger_cooldown() -> void:
	current_cooldown = total_cooldown


func is_ready() -> bool:
	return current_cooldown <= 0.0


func tick(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)


func get_remaining_ratio() -> float:
	if total_cooldown <= 0.0:
		return 0.0
	return current_cooldown / total_cooldown
