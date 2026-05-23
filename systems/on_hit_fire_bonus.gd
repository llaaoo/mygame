class_name OnHitFireBonus
extends TriggeredEffect
## 命中火焰增伤 — 演示 Condition 链条
## 
## 条件：skill has "fire" tag AND target is enemy
## 效果：额外 +50% 伤害（通过修改 ev.data["damage"] 实现，在 ON_DAMAGE 之前）

@export var bonus_multiplier: float = 1.5


static func create_default() -> OnHitFireBonus:
	var effect := OnHitFireBonus.new()
	effect.trigger_type = CombatEvent.Type.ON_HIT
	effect.scope_source = "skill"
	effect.max_recursion = 0

	# 条件1: 技能必须是火焰标签
	var skill_cond := SkillTagCondition.new()
	skill_cond.required_skill_tag = "fire"
	# 条件2: 目标必须是敌人
	var target_cond := TargetTypeCondition.new()
	target_cond.target_is_enemy = true
	target_cond.target_is_player = false

	effect.conditions = [skill_cond, target_cond]
	return effect


func _execute(ev: CombatEvent) -> void:
	var target := ev.target
	if not target:
		return

	var original_damage: int = ev.data.get("damage", 0)
	var bonus := int(original_damage * (bonus_multiplier - 1.0))

	if bonus > 0:
		# 副作用收敛：通过 CombatExecutor 统一施加，不走事件系统避免递归
		var caster: Node2D = ev.source
		var skill: SkillData = ev.skill
		var tags: Array = ev.data.get("tags", [])
		CombatExecutor.report_bonus_damage(caster, target, bonus, skill, tags)
		print("🔥 [OnHitFireBonus] 火焰增伤 +%d (%.0f%%) → %s" % [bonus, bonus_multiplier * 100, target.name])
