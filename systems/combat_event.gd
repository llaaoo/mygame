class_name CombatEvent
extends RefCounted
## 战斗事件 — 在 EventBus 中流转的纯数据载体
## 
## 描述"发生了什么"，不描述"该如何响应"
## 响应逻辑由订阅者自行处理

## ── 事件类型 ──
enum Type {
	ON_CAST,            ## 技能施放（SkillExecutor.execute 成功时）
	ON_HIT,             ## 投射物/AoE 命中目标（take_damage 之前）
	ON_DAMAGE,          ## 伤害已应用（take_damage 之后）
	ON_KILL,            ## 目标死亡（hp <= 0）
	ON_STATUS_APPLIED,  ## Buff/Debuff 施加
	ON_STATUS_REMOVED,  ## Buff/Debuff 移除
	ON_HEAL,            ## 治疗
	ON_DODGE,           ## 闪避
	ON_CRIT,            ## 暴击
}

## ── 事件数据 ──
var type: Type
var source: Node2D = null           ## 事件发起者（施法者/攻击者）
var target: Node2D = null           ## 事件承受者（被击中者）
var skill: SkillData = null         ## 关联技能（可能为空）
var data: Dictionary = {}           ## 附加数据：{"damage": 50, "element": "fire"}


## 快捷构造
static func create(event_type: Type, source: Node2D, target: Node2D = null) -> CombatEvent:
	var ev := CombatEvent.new()
	ev.type = event_type
	ev.source = source
	ev.target = target
	return ev


## 调试字符串
func _to_string() -> String:
	var tname := Type.keys()[type] if type < Type.size() else "UNKNOWN"
	return "CombatEvent(%s | src=%s → tgt=%s | data=%s)" % [tname, source, target, data]
