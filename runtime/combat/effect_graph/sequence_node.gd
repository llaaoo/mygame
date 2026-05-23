class_name SequenceNode
extends EffectNode
## 顺序节点 — 依次执行所有子节点
## 任一子节点 halt() 则后续跳过

@export var children: Array[EffectNode] = []


func process(ctx: EffectGraphContext) -> void:
	for child in children:
		if ctx.halted:
			return
		if child:
			child.process(ctx)
