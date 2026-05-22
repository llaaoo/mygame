class_name ManaPickup
extends Pickup
## 魔能拾取物 — 玩家触碰后恢复 MP

@export var mana_amount: int = 30


func _on_collected(player: Player) -> void:
	if player.has_method("restore_mp"):
		player.restore_mp(mana_amount)
