extends State
class_name PlayerSkillState

@export var skill_duration: float = 0.4
var skill_timer: float = 0.0

func enter() -> void:
	skill_timer = 0.0
	var src: String = entity.pending_skill_source
	entity.pending_skill_source = ""

	if src.begins_with("slot_"):
		var idx := src.trim_prefix("slot_").to_int()
		entity.cast_slot(idx)
	else:
		entity.cast_hand(src)

func physics_update(delta: float) -> void:
	if entity.get("ui_blocked"):
		return
	skill_timer += delta

	if Input.is_action_just_pressed("dodge"):
		transitioned.emit(self, "dodge")
		return

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	entity.velocity = input_dir * entity.move_speed * 0.5
	entity.move_and_slide()

	if input_dir.length() > 0.1:
		entity.facing_direction = input_dir

	if skill_timer >= skill_duration:
		if input_dir.length() > 0.1:
			transitioned.emit(self, "move")
		else:
			transitioned.emit(self, "idle")
