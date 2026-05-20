extends State
class_name PlayerIdleState

func enter() -> void:
	# 停止移动
	if entity is CharacterBody2D:
		entity.velocity = Vector2.ZERO

func physics_update(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length() > 0.05:
		print("🔍 Idle: 检测到移动输入! input_dir=", input_dir)
		transitioned.emit(self, "move")
		return
	
	if Input.is_action_just_pressed("dodge"):
		print("🔍 Idle: 检测到闪避输入!")
		transitioned.emit(self, "dodge")
		return
	
	if Input.is_action_just_pressed("attack"):
		print("🔍 Idle: 检测到攻击输入!")
		transitioned.emit(self, "attack")
		return
	
	if Input.is_action_just_pressed("skill"):
		print("🔍 Idle: 检测到技能输入!")
		transitioned.emit(self, "skill")
		return
