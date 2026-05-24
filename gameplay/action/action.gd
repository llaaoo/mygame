class_name Action
extends Resource
## 通用 Action — Player/Enemy/NPC/Boss 共享的意图数据
##
## 设计原则:
##   1. 纯数据 — 不包含任何执行逻辑
##   2. 统一类型 — 所有实体通过相同的 ActionType 表达意图
##   3. 可序列化 — Resource 类型，可存储/网络传输
##
## 数据流:
##   Input/Brain/Schedule → Action → ActionResolver → RuntimeRequest → RuntimeExecute

## ── Action 类型 ──
enum ActionType {
	IDLE,          ## 无操作
	MOVE,          ## 移动（direction 有效）
	MELEE,         ## 近战攻击
	CAST,          ## 技能释放（skill_id + direction 有效）
	INTERACT,      ## 交互（按 E）
	DODGE,         ## 闪避
	USE_ITEM,      ## 使用物品（预留）
}

## ── 核心字段 ──
@export var action_type: ActionType = ActionType.IDLE

## 发起者
var source: Node2D = null

## 目标（可选）：攻击目标 / 交互对象 / 施法目标
var target: Node2D = null

## 方向（MOVE/DODGE/CAST 使用）
var direction: Vector2 = Vector2.ZERO

## 技能 ID（CAST 使用）
var skill_id: String = ""

## 技能来源槽位（CAST 使用）："left" / "right" / "slot_0"~"slot_3"
var skill_source: String = ""

## 扩展参数
var params: Dictionary = {}


## ── 快捷构造 ──

static func move(dir: Vector2, src: Node2D = null) -> Action:
	var a := Action.new()
	a.action_type = ActionType.MOVE
	a.direction = dir
	a.source = src
	return a


static func melee(src: Node2D = null) -> Action:
	var a := Action.new()
	a.action_type = ActionType.MELEE
	a.source = src
	return a


static func cast(skill_source_str: String, dir: Vector2, src: Node2D = null) -> Action:
	var a := Action.new()
	a.action_type = ActionType.CAST
	a.skill_source = skill_source_str
	a.direction = dir
	a.source = src
	return a


static func interact(src: Node2D = null) -> Action:
	var a := Action.new()
	a.action_type = ActionType.INTERACT
	a.source = src
	return a


static func dodge(dir: Vector2, src: Node2D = null) -> Action:
	var a := Action.new()
	a.action_type = ActionType.DODGE
	a.direction = dir
	a.source = src
	return a


static func idle() -> Action:
	var a := Action.new()
	a.action_type = ActionType.IDLE
	return a


## ── 调试 ──

func _to_string() -> String:
	var type_name: String = ActionType.keys()[action_type]
	match action_type:
		ActionType.MOVE:
			return "Action(%s, dir=%s)" % [type_name, direction]
		ActionType.CAST:
			return "Action(%s, src=%s, skill=%s)" % [type_name, skill_source, skill_id]
		ActionType.MELEE, ActionType.DODGE, ActionType.INTERACT:
			return "Action(%s)" % type_name
	return "Action(%s)" % type_name
