extends State
class_name PlayerIdleState


func enter() -> void:
	if entity is CharacterBody2D:
		entity.velocity = Vector2.ZERO


func physics_update(_delta: float) -> void:
	if entity.get("ui_blocked"):
		return

	if entity.cancel_aim:
		entity.cancel_aim = false
		entity.aiming_sources.clear()
		entity.hide_aim()

	var actions: Array = entity.poll_actions()

	for action in actions:
		match action.type:
			PlayerAction.Type.MOVE:
				transitioned.emit(self, "move")
				return
			PlayerAction.Type.INTERACT, PlayerAction.Type.DODGE, PlayerAction.Type.MELEE:
				entity.try_action(action)
			PlayerAction.Type.CAST_PRESS, PlayerAction.Type.CAST_RELEASE:
				entity.try_action(action)
