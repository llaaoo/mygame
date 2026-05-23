class_name EmptyNode
extends EffectNode
## 空节点 — 终端，什么都不做
## 用于 Branch 的 false_branch 占位


func process(_ctx: EffectGraphContext) -> void:
	pass
