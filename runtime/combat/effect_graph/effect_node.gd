class_name EffectNode
extends Resource
## 效果节点 — EffectGraph 中的一个处理单元
## 
## 每个子类覆写 process(ctx) 来定义行为
## 
## 节点类型：
##   - 流程控制：Branch / Sequence / Parallel / ConditionGate
##   - 动作节点：自定义（伤害、Buff、生成等）
##   - 终端：EmptyNode（什么都不做）

## 节点显示名（编辑器用）
@export var node_name: String = ""


## 核心方法：处理上下文
## 返回 EffectGraphContext（支持链式调用）
func process(ctx: EffectGraphContext) -> void:
	pass
