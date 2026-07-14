class_name SkillInstance
extends RefCounted
## 技能运行时实例 — 包装 SkillData + 运行时状态（冷却等）
## 用于 SkillLoadout 的槽位映射

var base_data: SkillData = null
var data: SkillData = null
var upgrade_ranks: Dictionary = {}
var current_cooldown: float = 0.0      ## 剩余冷却时间
var total_cooldown: float = 0.0        ## 总冷却时间（快取）


func _init(skill: SkillData = null) -> void:
	if skill:
		bind(skill)


func bind(skill: SkillData) -> void:
	base_data = skill
	upgrade_ranks.clear()
	_rebuild_data()
	current_cooldown = 0.0


func apply_upgrade(upgrade_id: String) -> bool:
	if not base_data:
		return false
	var upgrade := base_data.get_upgrade(upgrade_id)
	if not upgrade or not upgrade.has_method("can_apply"):
		return false
	var current_rank := int(upgrade_ranks.get(upgrade_id, 0))
	if current_rank >= int(upgrade.get("max_rank")) or not upgrade.can_apply(upgrade_ranks):
		return false
	upgrade_ranks[upgrade_id] = current_rank + 1
	_rebuild_data()
	return true


func get_available_upgrades() -> Array[Resource]:
	var result: Array[Resource] = []
	if not base_data:
		return result
	for upgrade in base_data.upgrades:
		if not upgrade or not upgrade.has_method("can_apply"):
			continue
		var upgrade_id := str(upgrade.get("id"))
		if int(upgrade_ranks.get(upgrade_id, 0)) >= int(upgrade.get("max_rank")):
			continue
		if upgrade.can_apply(upgrade_ranks):
			result.append(upgrade)
	return result


func get_upgrade_rank(upgrade_id: String) -> int:
	return int(upgrade_ranks.get(upgrade_id, 0))


func serialize_state() -> Dictionary:
	return {
		"skill_id": base_data.get_id() if base_data else "",
		"upgrades": upgrade_ranks.duplicate(true),
	}


func restore_upgrades(saved_ranks: Dictionary) -> void:
	upgrade_ranks.clear()
	if not base_data:
		return
	for upgrade in base_data.upgrades:
		if not upgrade:
			continue
		var upgrade_id := str(upgrade.get("id"))
		var rank := clampi(int(saved_ranks.get(upgrade_id, 0)), 0, int(upgrade.get("max_rank")))
		if rank > 0:
			upgrade_ranks[upgrade_id] = rank
	_rebuild_data()


func _rebuild_data() -> void:
	var cooldown_ratio := get_remaining_ratio()
	data = base_data.create_runtime_variant(upgrade_ranks) if base_data else null
	total_cooldown = data.cooldown if data else 0.0
	current_cooldown = cooldown_ratio * total_cooldown


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
