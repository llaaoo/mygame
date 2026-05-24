extends State
class_name PlayerAttackState

@export var attack_duration: float = 0.3
var attack_timer: float = 0.0


func enter() -> void:
	attack_timer = 0.0
	entity.perform_melee_attack()


func physics_update(delta: float) -> void:
	if entity.get("ui_blocked"):
		return
	attack_timer += delta

	var actions: Array = entity.poll_universal_actions()
	var has_move := false

	for action in actions:
		match action.action_type:
			Action.ActionType.MOVE:
				has_move = true
				entity.velocity = action.direction * entity.move_speed * 0.6
				entity.move_and_slide()
				entity.facing_direction = action.direction
			Action.ActionType.DODGE:
				entity.resolve_action(action)
				return

	if attack_timer >= attack_duration:
		transitioned.emit(self, "move" if has_move else "idle")
