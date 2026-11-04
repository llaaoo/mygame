class_name ActionResolver
extends RefCounted
## ActionResolver — 统一 Action 验证节点
##
## 所有实体（Player/Enemy/NPC/Boss）在执行 Action 前通过此节点验证。
##
## 用法:
##   var ok := ActionResolver.validate(entity, action)
##   if not ok:
##       return


## ── 主入口 ──

## 验证一个 Action 对给定实体是否可执行。返回 true = 可执行
static func validate(entity: Node2D, action: Action) -> bool:
	if _is_dead(entity):
		return false

	match action.action_type:
		Action.ActionType.MELEE:
			return _validate_melee(entity)
		Action.ActionType.CAST:
			return _validate_cast(entity, action)
		Action.ActionType.DODGE:
			return _validate_dodge()
		Action.ActionType.INTERACT:
			return _validate_interact()
		Action.ActionType.MOVE:
			return _validate_move(entity)
		_:
			return true


## ── 类型专用验证 ──

static func _validate_melee(_entity: Node2D) -> bool:
	return true


static func _validate_cast(entity: Node2D, action: Action) -> bool:
	var sm := entity.get_node_or_null("SkillManager") as SkillManager
	if not sm:
		return false
	var inst := sm.get_instance(action.skill_source)
	if not inst:
		return false
	if not action.cast_context:
		action.cast_context = CastContext.simple(entity, action.direction, inst.data)
	return sm.can_start(action.skill_source, entity, action.cast_context)


static func _validate_dodge() -> bool:
	return true


static func _validate_interact() -> bool:
	return true


static func _validate_move(entity: Node2D) -> bool:
	return entity is CharacterBody2D


## ── 辅助 ──

static func _is_dead(entity: Node2D) -> bool:
	var hp := entity.get_node_or_null("HealthComponent") as HealthComponent
	if hp and hp.is_dead:
		return true
	if "is_dead" in entity and entity.is_dead:
		return true
	return false
