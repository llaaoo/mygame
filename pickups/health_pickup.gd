class_name HealthPickup
extends Pickup
## 生命值拾取物 — 玩家触碰后恢复 HP

## 恢复量
@export var heal_amount: int = 20


func _on_collected(player: Player) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
