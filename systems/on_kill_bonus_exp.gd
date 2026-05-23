class_name OnKillBonusExp
extends TriggeredEffect
## 击杀额外经验 — 演示 Event + Condition + Effect 完整闭环
## 
## 默认条件：目标必须是 enemy 组（通过 TargetTypeCondition）
## 可通过 conditions 数组叠加更多条件

@export var bonus_exp: int = 15


## 静态工厂：创建带默认条件的实例
static func create_for_player(exp: int = 15) -> OnKillBonusExp:
	var effect := OnKillBonusExp.new()
	effect.bonus_exp = exp
	effect.trigger_type = CombatEvent.Type.ON_KILL
	effect.scope_source = "global"
	effect.max_recursion = 0

	# 条件：只对击杀敌人触发
	var cond := TargetTypeCondition.new()
	cond.target_is_enemy = true
	cond.target_is_player = false
	effect.conditions = [cond]

	return effect


func _execute(ev: CombatEvent) -> void:
	# 击杀奖励发放给玩家
	var player := ev.target.get_tree().get_first_node_in_group("player") as Player
	if not player or not player.stats_component:
		return

	player.stats_component.add_experience(bonus_exp)
	print("⚡ [OnKillBonusExp] +%d 额外经验 (target=%s)" % [bonus_exp, ev.target.name])
