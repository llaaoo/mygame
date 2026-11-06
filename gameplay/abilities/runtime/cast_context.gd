class_name CastContext
extends RefCounted
## 施法上下文 — 纯数据类，SkillExecutor 的输入参数
## 每次施法创建一个实例，不持有任何逻辑

var caster: Node2D = null
var target: Node2D = null
var direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var has_target_position: bool = false
var world: Node = null
var skill: SkillData = null
var charge_power: float = 1.0          ## 蓄力倍率（0.0~1.0，1.0=满蓄）
var batch: SkillExecutionBatch
var family_id := ""
var empower := false
var requires_live_target := false

static func target_available(victim) -> bool:
	if not is_instance_valid(victim) or victim.is_queued_for_deletion(): return false
	var health := victim.get_node_or_null("HealthComponent") as HealthComponent
	return not health or not health.is_dead

func has_valid_target() -> bool:
	return not requires_live_target or target_available(target)


## 快捷构造：仅需 caster + direction
static func simple(caster: Node2D, direction: Vector2, skill: SkillData) -> CastContext:
	var ctx := CastContext.new()
	ctx.caster = caster
	ctx.direction = direction
	ctx.skill = skill
	ctx.world = default_world(caster)
	return ctx


## 构造：caster + target 锁定
static func targeted(caster: Node2D, target: Node2D, skill: SkillData) -> CastContext:
	var ctx := CastContext.new()
	ctx.caster = caster
	ctx.target = target
	ctx.direction = (target.global_position - caster.global_position).normalized()
	ctx.target_position = target.global_position
	ctx.has_target_position = true
	ctx.skill = skill
	ctx.world = default_world(caster)
	return ctx


## 构造：caster + 指定位置（AoE）
static func at_position(caster: Node2D, position: Vector2, skill: SkillData) -> CastContext:
	var ctx := CastContext.new()
	ctx.caster = caster
	ctx.direction = (position - caster.global_position).normalized()
	ctx.target_position = position
	ctx.has_target_position = true
	ctx.skill = skill
	ctx.world = default_world(caster)
	return ctx

## Region-owned effects expire with their region. Explicit callers can override world.
static func default_world(actor: Node) -> Node:
	if GameRuntime.instance:
		var session := GameRuntime.instance.get_region_session()
		if session and is_instance_valid(session.active_root):
			return session.active_root
	return actor.get_tree().current_scene if actor and actor.is_inside_tree() else null

## One bounded point used by input, aiming and conditional preparation.
static func ground_point(actor: Node2D, requested: Vector2, max_range: float) -> Vector2:
	return actor.global_position + (requested - actor.global_position).limit_length(maxf(0, max_range))
