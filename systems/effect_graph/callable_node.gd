class_name CallableNode
extends EffectNode
## 可调用节点 — 包装一个 Callable 作为叶子动作
## 
## 用于快速原型和简单效果，不需要写新类

@export var callback_name: String = ""            ## 调试标识


var _callback: Callable


## 工厂：从 Callable 创建
static func from_callable(cb: Callable, name_str: String = "") -> CallableNode:
	var node := CallableNode.new()
	node._callback = cb
	node.node_name = name_str
	return node


func process(ctx: EffectGraphContext) -> void:
	if _callback.is_valid():
		_callback.call(ctx)
