class_name CombatTraceEvent
extends RefCounted
## 战斗追踪事件 — 最小记录单元
## 
## 记录"在某个阶段，发生了什么，输入/输出是什么"

## ── 事件类别 ──
enum Category {
	PHASE_ENTER,       ## 进入阶段
	PHASE_EXIT,        ## 退出阶段
	MODIFIER_APPLY,    ## Modifier 管线
	CONDITION_CHECK,   ## 条件判定
	EVENT_EMIT,        ## 事件发射
	GRAPH_NODE,        ## 图节点执行
	SKILL_EXECUTE,     ## 技能执行
	DAMAGE_RESOLVE,    ## 伤害解析
	FIREWALL_BLOCK,    ## 防火墙拦截
}

## ── 数据字段 ──
var category: Category
var phase: CombatPhase.Phase           ## 当前阶段
var event_name: String = ""            ## 人类可读名称
var source: String = ""                ## 来源（"StatScalingModifier", "BranchNode" 等）
var target: String = ""                ## 目标

var input_data: Dictionary = {}        ## 输入（before values）
var output_data: Dictionary = {}       ## 输出（after values）
var metadata: Dictionary = {}          ## 额外信息（bool result, tags...）

var timestamp_ms: int = 0              ## 时间戳
var depth: int = 0                     ## 嵌套深度


## 快捷构造
static func create(cat: Category, ph: CombatPhase.Phase, name_str: String) -> CombatTraceEvent:
	var ev := CombatTraceEvent.new()
	ev.category = cat
	ev.phase = ph
	ev.event_name = name_str
	ev.timestamp_ms = Time.get_ticks_msec()
	return ev


func _to_string() -> String:
	return "[%s] %s | %s → %s | in=%s out=%s" % [
		Category.keys()[category], event_name, source, target, input_data, output_data
	]
