class_name OnIceArmorExpire
extends TriggeredEffect
## Buff 消失时释放 AoE — 通用模块，通过 conditions 配置
## 
## 默认：冰霜护盾消失 → 冰爆
## 可改为任意 Buff → 任意 AoE 技能：修改 buff_name + skill_path 即可
## 
## 验证链路：Buff过期 → ON_STATUS_REMOVED → Condition(BuffName) → SkillExecutor → AoE

## 消失时释放的技能路径（res://...）
@export var unleash_skill_path: String = "res://runtime/combat/skills/data/ice_explosion_data.tres"


static func create_default() -> OnIceArmorExpire:
	var effect := OnIceArmorExpire.new()
	effect.trigger_type = CombatEvent.Type.ON_STATUS_REMOVED
	effect.scope_source = "skill"
	effect.max_recursion = 0

	# 条件：仅冰霜护盾消失时触发（可改为其他 Buff）
	var cond := BuffNameCondition.new()
	cond.required_buff_name = "冰霜护盾"
	effect.conditions = [cond]

	return effect


func _execute(ev: CombatEvent) -> void:
	var caster := ev.target
	if not caster:
		return

	var skill := load(unleash_skill_path) as SkillData
	if not skill:
		push_warning("[OnIceArmorExpire] 无法加载技能: %s" % unleash_skill_path)
		return

	var executor := _find_executor(caster)
	if not executor:
		return

	var ctx := CastContext.at_position(caster, caster.global_position, skill)
	executor.execute(skill, ctx)
	print("❄️ [OnIceArmorExpire] %s 消失 → 释放 %s" % [ev.data.get("buff_name", "?"), skill.display_name])


func _find_executor(entity: Node2D) -> SkillExecutor:
	var sm := entity.get_node_or_null("SkillManager") as SkillManager
	if sm and sm.executor:
		return sm.executor
	var tree := entity.get_tree()
	if tree:
		for node in tree.get_nodes_in_group("player"):
			var fallback_sm := node.get_node_or_null("SkillManager") as SkillManager
			if fallback_sm and fallback_sm.executor:
				return fallback_sm.executor
	return null
