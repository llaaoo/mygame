extends State
class_name PlayerSkillState

@export var skill_duration: float = 0.4
var skill_timer: float = 0.0


func enter() -> void:
	skill_timer = 0.0
	# cast 已在 resolve_action() 中执行，这里只播动画
	if entity.animation_player.has_animation("skill"):
		entity.animation_player.play("skill")


func physics_update(delta: float) -> void:
	if entity.get("ui_blocked"):
		return
	skill_timer += delta

	var actions: Array = entity.poll_universal_actions()
	var has_move := false

	for action in actions:
		match action.action_type:
			Action.ActionType.MOVE:
				has_move = true
				entity.velocity = action.direction * entity.move_speed * 0.5
				entity.move_and_slide()
				entity.facing_direction = action.direction
			Action.ActionType.DODGE:
				entity.resolve_action(action)
				return

	if skill_timer >= skill_duration:
		transitioned.emit(self, "move" if has_move else "idle")
