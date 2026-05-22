class_name EffectGraph
extends Resource
## 效果图 — 节点组合的容器和执行入口
## 
## 用法：
##   var graph := EffectGraph.new()
##   graph.root = my_sequence_node
##   graph.run(ctx)
## 
## 这是"规则列表" → "可组合图"的关键跃迁

## 根节点（执行入口）
@export var root: EffectNode = null


## 执行图
func run(ev: CombatEvent) -> void:
	if not root:
		return
	var ctx := EffectGraphContext.from_event(ev)
	root.process(ctx)


## 从 TriggeredEffect 的旧模式迁移：条件列表 → ConditionGate + 效果
static func from_flat(trigger_type: CombatEvent.Type, conds: Array[Condition], action: EffectNode) -> EffectGraph:
	var graph := EffectGraph.new()

	if conds.is_empty():
		graph.root = action
		return graph

	# 构建 ConditionGate 链
	var current: ConditionGateNode = null
	var first: ConditionGateNode = null

	for i in range(conds.size()):
		var gate := ConditionGateNode.new()
		gate.condition = conds[i]
		if first == null:
			first = gate
			current = gate
		else:
			current.child = gate
			current = gate

	# 最后一个 gate 的 child = action
	if current:
		current.child = action

	graph.root = first if first else action
	return graph
