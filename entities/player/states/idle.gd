class_name PlayerIdleState
extends State


func enter() -> void:
	if entity is CharacterBody2D:
		entity.velocity = Vector2.ZERO


func physics_update(_delta: float) -> void:
	if entity.get("ui_blocked"):
		return

	var actions: Array = entity.poll_universal_actions()

	for action in actions:
		match action.action_type:
			Action.ActionType.MOVE:
				transitioned.emit(self, "move")
				return
			Action.ActionType.INTERACT, Action.ActionType.DODGE, Action.ActionType.MELEE:
				entity.resolve_action(action)
			Action.ActionType.CAST:
				entity.resolve_action(action)
