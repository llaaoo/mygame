extends State
class_name PlayerMoveState

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length() < 0.1:
		print("🔍 Move: 无输入，回到 Idle")
		transitioned.emit(self, "idle")
		return
	
	# 设置移动速度
	entity.velocity = input_dir * entity.move_speed
	entity.move_and_slide()
	print("🔍 Move: 移动中 velocity=", entity.velocity, " position=", entity.global_position)
	
	# 更新朝向（用于攻击/技能方向）
	if input_dir.length() > 0.1:
		entity.facing_direction = input_dir
	
	# 检测动作
	if Input.is_action_just_pressed("dodge"):
		print("🔍 Move: 检测到闪避!")
		transitioned.emit(self, "dodge")
		return
	
	if Input.is_action_just_pressed("attack"):
		print("🔍 Move: 检测到攻击!")
		transitioned.emit(self, "attack")
		return
	
	if Input.is_action_just_pressed("skill"):
		print("🔍 Move: 检测到技能!")
		transitioned.emit(self, "skill")
		return
