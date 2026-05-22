extends State
class_name PlayerAttackState

@export var attack_duration: float = 0.3
var attack_timer: float = 0.0

func enter() -> void:
	attack_timer = 0.0
	entity.perform_melee_attack()

func physics_update(delta: float) -> void:
	attack_timer += delta

	if Input.is_action_just_pressed("dodge"):
		transitioned.emit(self, "dodge")
		return

	for i in range(4):
		var key := "skill_%d" % (i + 1)
		if Input.is_action_just_pressed(key):
			entity.pending_skill_source = "slot_%d" % i
			transitioned.emit(self, "skill")
			return

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	entity.velocity = input_dir * entity.move_speed * 0.6
	entity.move_and_slide()

	if input_dir.length() > 0.1:
		entity.facing_direction = input_dir

	if attack_timer >= attack_duration:
		if input_dir.length() > 0.1:
			transitioned.emit(self, "move")
		else:
			transitioned.emit(self, "idle")
