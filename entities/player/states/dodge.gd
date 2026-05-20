extends State
class_name PlayerDodgeState

@export var dodge_duration: float = 0.35
@export var dodge_speed: float = 600.0
var dodge_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.RIGHT

func enter() -> void:
	dodge_timer = 0.0
	# 使用移动方向闪避，如果没有方向则使用朝向
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = input_dir if input_dir.length() > 0.1 else entity.facing_direction
	dodge_direction = dodge_direction.normalized()

func physics_update(delta: float) -> void:
	dodge_timer += delta
	
	# 闪避过程中不可控移动
	entity.velocity = dodge_direction * dodge_speed
	entity.move_and_slide()
	
	if dodge_timer >= dodge_duration:
		transitioned.emit(self, "idle")
