class_name OnKillBonusExp
extends TriggeredEffect
## 击杀额外经验 — 演示 Event + Condition + Effect 完整闭环
## 
## 默认条件：目标必须是 enemy 组（通过 TargetTypeCondition）
## 可通过 conditions 数组叠加更多条件

@export var bonus_exp: int = 15

var _recipient: WeakRef


## 静态工厂：创建带默认条件的实例
static func create_for_player(player: Player, exp: int = 15) -> OnKillBonusExp:
	var effect := OnKillBonusExp.new()
	effect.bonus_exp = exp
	effect._recipient = weakref(player)
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
	if not ev.data.get("reward_eligible", true): return
	# 击杀奖励发放给玩家（副作用收敛到 CombatExecutor）
	var player := _recipient.get_ref() as Player if _recipient else null
	if not is_instance_valid(player) or not player.is_inside_tree():
		return

	CombatExecutor.report_exp_bonus(player, bonus_exp)
	print("⚡ [OnKillBonusExp] +%d 额外经验 (target=%s)" % [bonus_exp, ev.target.name])
