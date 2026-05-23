class_name OnHitApplyStatus
extends TriggeredEffect
## 命中施加状态 — 通用模块
## 技能命中目标时，若标签匹配，自动给目标挂指定 Buff（燃烧/中毒/潮湿等）
##
## 配置方式：
##   required_skill_tag = "fire"    ← 匹配技能标签
##   status_buff_path = "res://gameplay/abilities/data/burning.tres"

@export var required_skill_tag: String = "fire"
@export var status_buff_path: String = "res://gameplay/abilities/data/burning.tres"


static func create(tag: String, buff_path: String) -> OnHitApplyStatus:
	var effect := OnHitApplyStatus.new()
	effect.trigger_type = CombatEvent.Type.ON_HIT
	effect.scope_source = "skill"
	effect.max_recursion = 0
	
	var cond := SkillTagCondition.new()
	cond.required_skill_tag = tag
	effect.conditions = [cond]
	
	effect.required_skill_tag = tag
	effect.status_buff_path = buff_path
	return effect


func _execute(ev: CombatEvent) -> void:
	var target := ev.target
	if not target:
		return
	
	var buff_manager := target.get_node_or_null("BuffManager")
	if not buff_manager:
		return
	
	var buff := load(status_buff_path) as Buff
	if not buff:
		push_warning("[OnHitApplyStatus] 无法加载: %s" % status_buff_path)
		return
	
	buff_manager.apply_buff(buff)
	print("🔥 [OnHitApplyStatus] %s → %s 挂 %s" % [ev.source.name if ev.source else "?", target.name, buff.display_name])
