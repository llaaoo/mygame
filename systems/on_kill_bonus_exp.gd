class_name OnKillBonusExp
extends TriggeredEffect
## 击杀时额外奖励经验值
## 演示：Event System 如何驱动实际行为

@export var bonus_exp: int = 15


func _execute(ev: CombatEvent) -> void:
	# 击杀者 = ev.source（需要从 ON_HIT 追溯，这里简化：从 world 找 player）
	var player := ev.target.get_tree().get_first_node_in_group("player") as Player
	if not player or not player.stats_component:
		return

	player.stats_component.add_experience(bonus_exp)
	print("⚡ [TriggeredEffect] ON_KILL: +%d 额外经验 (target=%s)" % [bonus_exp, ev.target.name])
