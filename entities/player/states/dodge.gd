extends State
class_name PlayerDodgeState

@export var dodge_duration: float = 0.35
@export var dodge_speed: float = 600.0
var dodge_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.RIGHT

func enter() -> void:
	dodge_timer = 0.0
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = input_dir if input_dir.length() > 0.1 else entity.facing_direction
	dodge_direction = dodge_direction.normalized()

func physics_update(delta: float) -> void:
	if entity.get("ui_blocked"):
		return
	dodge_timer += delta

	entity.velocity = dodge_direction * dodge_speed
	entity.move_and_slide()

	if dodge_timer >= dodge_duration:
		# Transição inteligente: se há input de movimento, vai para Move
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir.length() > 0.1:
			transitioned.emit(self, "move")
		else:
			transitioned.emit(self, "idle")
