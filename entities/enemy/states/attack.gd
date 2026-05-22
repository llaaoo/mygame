extends State
class_name EnemyAttackState

var attack_timer: float = 0.0

func enter() -> void:
	attack_timer = 0.0
	entity.velocity = Vector2.ZERO
	# 立即攻击一次
	entity.perform_attack()

func physics_update(delta: float) -> void:
	if not entity.player or entity.player.health_component.is_dead:
		transitioned.emit(self, "idle")
		return
	
	attack_timer += delta
	var dist = entity.distance_to_player()
	
	# 玩家跑远了 → 继续追
	if dist > entity.attack_range * 1.5:
		transitioned.emit(self, "chase")
		return
	
	# 攻击冷却到了 → 再打一次
	if attack_timer >= entity.attack_cooldown:
		attack_timer = 0.0
		entity.perform_attack()
