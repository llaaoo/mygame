class_name ReactionRule
extends Resource
## ReactionRule — 表面状态迁移规则（纯数据，只读）
##
## 5 个状态的状态机迁移:
##   dry → burning (火技能命中)
##   dry → wet (水/冰技能命中)
##   dry → oiled (油技能命中)
##   wet → frozen (冰技能命中 wet)
##   oiled → burning (火技能命中 oiled)
##   burning → dry (水技能命中 / 自然超时)
##   frozen → wet (自然超时)

@export var required_state: String = "dry"       ## 当前表面状态
@export var required_tags: Array[String] = []    ## 触发标签 ["fire"] / ["ice"] / ["lightning"]
@export var result_state: String = "dry"         ## 迁移后状态
@export var effect_spawn: PackedScene            ## 可选：特效场景（蒸汽云、冰碎片）
@export var duration: float = 5.0                ## 新状态持续时间
@export var aoe_radius: float = 0.0              ## >0 时影响周围单元格


## 检查是否匹配
func matches(current_state: String, tags: Array[String]) -> bool:
	if current_state != required_state:
		return false
	if required_tags.is_empty():
		return true
	for required: String in required_tags:
		if required in tags:
			return true
	return false


func _to_string() -> String:
	return "ReactionRule(%s + %s → %s)" % [required_state, required_tags, result_state]
