class_name LogNode
extends EffectNode
## 日志节点 — 打印调试信息到控制台
## 用于图开发时的可视化和调试

@export var message: String = "EffectGraph Node"


func process(ctx: EffectGraphContext) -> void:
	var src_name := ctx.source.name if ctx.source else "?"
	var tgt_name := ctx.target.name if ctx.target else "?"
	print("📊 [Graph:%s] %s | src=%s → tgt=%s | data=%s" % [
		node_name if not node_name.is_empty() else "LogNode",
		message, src_name, tgt_name, ctx.data
	])
