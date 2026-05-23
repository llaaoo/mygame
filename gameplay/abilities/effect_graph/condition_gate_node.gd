class_name ConditionGateNode
extends EffectNode
## 条件门 — 满足条件才放行子节点，否则直接跳过（不执行 false 分支）
## 
## 与 BranchNode 的区别：没有 else 分支，不满足 = 静默跳过

@export var condition: Condition = null
@export var child: EffectNode = null


func process(ctx: EffectGraphContext) -> void:
	if not condition:
		return
	if not condition.check(_build_cond_ctx(ctx)):
		return
	if child:
		child.process(ctx)


func _build_cond_ctx(ctx: EffectGraphContext) -> Dictionary:
	return {
		"event": ctx.event,
		"source": ctx.source,
		"target": ctx.target,
		"skill": ctx.skill,
		"data": ctx.data,
	}
