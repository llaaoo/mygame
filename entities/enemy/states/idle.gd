extends State
class_name EnemyIdleState

func physics_update(_delta: float) -> void:
	if not entity.player:
		return
	
	var dist = entity.distance_to_player()
	
	# 玩家在侦测范围内 → 追击
	if dist <= entity.detect_range:
		transitioned.emit(self, "chase")
