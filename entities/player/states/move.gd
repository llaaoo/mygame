extends State
class_name PlayerMoveState


func physics_update(_delta: float) -> void:
	if entity.get("ui_blocked"):
		return

	if entity.cancel_aim:
		entity.cancel_aim = false
		entity.aiming_sources.clear()
		entity.hide_aim()

	var actions: Array = entity.poll_universal_actions()

	var has_move := false
	for action in actions:
		match action.action_type:
			Action.ActionType.MOVE:
				has_move = true
				entity.velocity = action.direction * entity.move_speed
				entity.move_and_slide()
				entity.facing_direction = action.direction
			Action.ActionType.INTERACT, Action.ActionType.DODGE, Action.ActionType.MELEE:
				entity.resolve_action(action)
			Action.ActionType.CAST:
				entity.resolve_action(action)

	if not has_move:
		transitioned.emit(self, "idle")
		return
