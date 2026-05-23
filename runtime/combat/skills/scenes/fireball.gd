extends Projectile
class_name Fireball

## 火球术 — 玩家默认投射物，高速高伤


func _apply_visual() -> void:
	speed = 500.0
	damage = 25
	# lifetime / collision_radius 使用基类默认值 (3.0 / 8.0)
