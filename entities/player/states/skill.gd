extends State
class_name PlayerSkillState

@export var skill_duration: float = 0.4
var skill_timer: float = 0.0

func enter() -> void:
	skill_timer = 0.0
	entity.velocity = Vector2.ZERO
	# 释放技能
	entity.cast_skill()

func physics_update(delta: float) -> void:
	skill_timer += delta
	if skill_timer >= skill_duration:
		transitioned.emit(self, "idle")
