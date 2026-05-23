class_name BranchNode
extends EffectNode
## 分支节点 — if condition → true_branch, else → false_branch
## 
## 用法：
##   Branch(IsBoss):
##     → true: DoubleExplosion
##     → false: NormalExplosion

@export var condition: Condition = null
@export var true_branch: EffectNode = null
@export var false_branch: EffectNode = null


func process(ctx: EffectGraphContext) -> void:
	var result := false
	if condition:
		result = condition.check(_build_cond_ctx(ctx))

	if result and true_branch:
		true_branch.process(ctx)
	elif not result and false_branch:
		false_branch.process(ctx)


func _build_cond_ctx(ctx: EffectGraphContext) -> Dictionary:
	return {
		"event": ctx.event,
		"source": ctx.source,
		"target": ctx.target,
		"skill": ctx.skill,
		"data": ctx.data,
	}
