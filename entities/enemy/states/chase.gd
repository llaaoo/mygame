extends State
class_name EnemyChaseState

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	if not entity.player or entity.player.is_dead:
		transitioned.emit(self, "idle")
		return
	
	var dist = entity.distance_to_player()
	
	# 进入攻击范围 → 攻击
	if dist <= entity.attack_range:
		transitioned.emit(self, "attack")
		return
	
	# 超出侦测范围 → 放弃
	if dist > entity.detect_range * 1.5:
		transitioned.emit(self, "idle")
		return
	
	# 向玩家移动
	var dir = entity.get_player_direction()
	entity.velocity = dir * entity.move_speed
	entity.move_and_slide()
