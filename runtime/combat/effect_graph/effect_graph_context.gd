class_name EffectGraphContext
extends RefCounted
## 图执行上下文 — 在 Node 之间流转的可读写数据载体
## 
## 每个节点可以读写 ctx，实现节点间通信
## halt() 可以中断整个图的执行

## ── 标准字段 ──
var event: CombatEvent = null
var source: Node2D = null
var target: Node2D = null
var skill: SkillData = null
var data: Dictionary = {}

## ── 控制字段 ──
var halted: bool = false

## 终止执行（后续节点跳过）
func halt() -> void:
	halted = true

## ── 自定义存储（节点间通信） ──
var store: Dictionary = {}


static func from_event(ev: CombatEvent) -> EffectGraphContext:
	var ctx := EffectGraphContext.new()
	ctx.event = ev
	ctx.source = ev.source
	ctx.target = ev.target
	ctx.skill = ev.skill
	ctx.data = ev.data.duplicate()
	return ctx
