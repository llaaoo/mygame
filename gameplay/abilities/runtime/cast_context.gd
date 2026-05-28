class_name CastContext
extends RefCounted
## 施法上下文 — 纯数据类，SkillExecutor 的输入参数
## 每次施法创建一个实例，不持有任何逻辑

var caster: Node2D = null
var target: Node2D = null
var direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var world: Node = null
var skill: SkillData = null
var charge_power: float = 1.0          ## 蓄力倍率（0.0~1.0，1.0=满蓄）


## 快捷构造：仅需 caster + direction
static func simple(caster: Node2D, direction: Vector2, skill: SkillData) -> CastContext:
	var ctx := CastContext.new()
	ctx.caster = caster
	ctx.direction = direction
	ctx.skill = skill
	ctx.world = caster.get_tree().current_scene
	return ctx


## 构造：caster + target 锁定
static func targeted(caster: Node2D, target: Node2D, skill: SkillData) -> CastContext:
	var ctx := CastContext.new()
	ctx.caster = caster
	ctx.target = target
	ctx.direction = (target.global_position - caster.global_position).normalized()
	ctx.target_position = target.global_position
	ctx.skill = skill
	ctx.world = caster.get_tree().current_scene
	return ctx


## 构造：caster + 指定位置（AoE）
static func at_position(caster: Node2D, position: Vector2, skill: SkillData) -> CastContext:
	var ctx := CastContext.new()
	ctx.caster = caster
	ctx.direction = (position - caster.global_position).normalized()
	ctx.target_position = position
	ctx.skill = skill
	ctx.world = caster.get_tree().current_scene
	return ctx
