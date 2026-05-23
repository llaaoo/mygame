extends Projectile
class_name ShadowBolt

## 暗影弹 — 敌人远程投射物，低速低伤 + 紫色视觉


func _apply_visual() -> void:
	speed = 250.0
	damage = 10
	collision_radius = 6.0

	var spr = $Sprite2D
	if spr:
		spr.modulate = Color(0.5, 0.2, 0.8, 1)  # 紫色暗影
