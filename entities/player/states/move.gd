extends State
class_name PlayerMoveState

var _aiming_left: bool = false
var _aiming_right: bool = false

func enter() -> void:
	_aiming_left = false
	_aiming_right = false

func physics_update(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir.length() < 0.1:
		transitioned.emit(self, "idle")
		return

	entity.velocity = input_dir * entity.move_speed
	entity.move_and_slide()

	if input_dir.length() > 0.1:
		entity.facing_direction = input_dir

	if Input.is_action_just_pressed("dodge"):
		transitioned.emit(self, "dodge")
		return

	# ── 左键 ──
	if Input.is_action_just_pressed("attack"):
		if entity.skill_manager.has_left_spell():
			_aiming_left = true
			entity.start_aim("left")
		else:
			transitioned.emit(self, "attack")
	if Input.is_action_just_released("attack"):
		if _aiming_left:
			_aiming_left = false
			entity.end_aim("left")
			transitioned.emit(self, "skill")

	# ── 右键 ──
	if Input.is_action_just_pressed("skill"):
		if entity.skill_manager.has_right_spell():
			_aiming_right = true
			entity.start_aim("right")
	if Input.is_action_just_released("skill"):
		if _aiming_right:
			_aiming_right = false
			entity.end_aim("right")
			transitioned.emit(self, "skill")

	# ── 快捷键 1-4 ──
	for i in range(4):
		var key := "skill_%d" % (i + 1)
		if Input.is_action_just_pressed(key):
			entity.pending_skill_source = "slot_%d" % i
			transitioned.emit(self, "skill")
			return
