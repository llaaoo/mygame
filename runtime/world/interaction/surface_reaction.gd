class_name SurfaceReaction
extends Resource
## 表面反应规则 — 纯数据，描述 "状态 + 标签 → 新状态"
## 替代硬编码逻辑，设计师可通过 .tres 配置所有表面交互

@export var rule_id: String = ""                   ## 规则标识（调试用）
@export var required_state: String = "dry"         ## 当前表面状态
@export var required_tags: Array[String] = []      ## 触发标签（["fire"]/["ice"]/["lightning"]）
@export var result_state: String = "dry"           ## 结果状态
@export var result_duration: float = 5.0           ## 结果状态持续时间
@export var spread_to_neighbors: bool = false      ## 是否传播到相邻格
@export var spread_tags: Array[String] = []        ## 传播时携带的标签
@export var spread_damage: float = 0.0             ## 传播伤害（会被衰减）
@export var entity_status_path: String = ""        ## 对站在该格上的实体施加的 Buff 路径（可选）


## 判断此规则是否匹配
func matches(state: String, tags: Array[String]) -> bool:
	if state != required_state:
		return false
	if required_tags.is_empty():
		return true
	for tag in required_tags:
		if tag in tags:
			return true
	return false
