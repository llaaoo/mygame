extends State
class_name PlayerAttackState

@export var attack_duration: float = 0.3
var attack_timer: float = 0.0

func enter() -> void:
	attack_timer = 0.0
	entity.velocity = Vector2.ZERO
	# 检测攻击命中
	entity.perform_melee_attack()

func physics_update(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_duration:
		transitioned.emit(self, "idle")
