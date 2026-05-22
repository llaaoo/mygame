extends State
class_name PlayerMoveState

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	if entity.get("ui_blocked"):
		return

	if entity.cancel_aim:
		entity.cancel_aim = false
		entity.aiming_sources.clear()
		entity.hide_aim()

	var want_dodge := Input.is_action_just_pressed("dodge")

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() < 0.1:
		transitioned.emit(self, "idle")
		return

	entity.velocity = input_dir * entity.move_speed
	entity.move_and_slide()
	if input_dir.length() > 0.1:
		entity.facing_direction = input_dir

	_handle_press("left",  "attack")
	_handle_press("right", "skill")
	for i in range(4):
		_handle_press("slot_%d" % i, "skill_%d" % (i + 1))

	_handle_release("left", "attack")
	_handle_release("right", "skill")
	for i in range(4):
		_handle_release("slot_%d" % i, "skill_%d" % (i + 1))

	if entity.aiming_sources.size() > 0:
		for src in entity.aiming_sources:
			if _is_held(src):
				_show_aim_for(src)
				break

	if want_dodge:
		transitioned.emit(self, "dodge")


func _is_held(source: String) -> bool:
	match source:
		"left":  return Input.is_action_pressed("attack")
		"right": return Input.is_action_pressed("skill")
		_:       return Input.is_action_pressed("skill_%d" % (source.trim_prefix("slot_").to_int() + 1))


func _handle_press(source: String, action: String) -> void:
	if not Input.is_action_just_pressed(action):
		return
	if _can_cast(source):
		entity.aiming_sources[source] = true
		_show_aim_for(source)
	elif source == "left":
		entity.aiming_sources.clear()
		entity.hide_aim()
		transitioned.emit(self, "attack")


func _handle_release(source: String, action: String) -> bool:
	if not entity.aiming_sources.has(source):
		return false
	if Input.is_action_pressed(action):
		return false
	entity.aiming_sources.erase(source)
	_cast(source)
	if entity.aiming_sources.size() == 0:
		entity.hide_aim()
	return true


func _can_cast(source: String) -> bool:
	var sm = entity.skill_manager
	match source:
		"left":  return sm.has_left_spell()
		"right": return sm.has_right_spell()
		_:       
			var inst: SkillInstance = sm.get_slot(source.trim_prefix("slot_").to_int())
			return inst != null and inst.data != null


func _cast(source: String) -> bool:
	match source:
		"left", "right": return entity.cast_hand(source)
		_:               return entity.cast_slot(source.trim_prefix("slot_").to_int())


func _show_aim_for(source: String) -> void:
	var skill: SkillData = null
	var sm = entity.skill_manager
	match source:
		"left":  skill = sm.left_hand.data if sm.left_hand else null
		"right": skill = sm.right_hand.data if sm.right_hand else null
		_:
			var inst: SkillInstance = sm.get_slot(source.trim_prefix("slot_").to_int())
			skill = inst.data if inst else null
	if skill:
		entity.show_aim(source, skill)
