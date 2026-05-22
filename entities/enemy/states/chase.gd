extends State
class_name EnemyChaseState

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	if not entity.player or entity.player.health_component.is_dead:
		transitioned.emit(self, "idle")
		return

	var dist = entity.distance_to_player()

	# 进入攻击范围 → 近战
	if dist <= entity.attack_range:
		transitioned.emit(self, "attack")
		return

	# 超出侦测范围 → 放弃
	if dist > entity.detect_range * 1.5:
		transitioned.emit(self, "idle")
		return

	# 远程技能：冷却好了就放
	if entity.skill_manager and entity.skill_manager.can_use("right"):
		var dir = entity.get_player_direction()
		entity.skill_manager.use_hand("right", entity, dir)

	# 向玩家移动
	var dir = entity.get_player_direction()
	entity.velocity = dir * entity.move_speed
	entity.move_and_slide()
