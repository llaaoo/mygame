class_name CombatPhase
extends RefCounted
## 战斗阶段锁 — 定义 CombatExecutor 的固定执行顺序
## 
## 原则：
##   - 阶段之间不可跳跃
##   - 前一阶段未完成，后一阶段不可开始
##   - 任何系统不得绕过阶段直接调用其他阶段

enum Phase {
	IDLE,           ## 空闲
	INPUT,          ## 输入验证（MP/冷却/施法距离）
	CONDITION,      ## 条件检查（Condition.evaluate）
	MODIFIER,       ## 数值管线（DamageModifier Pipeline）
	EFFECT,         ## 效果执行（EffectGraph / SkillExecutor.execute）
	EVENT,          ## 事件广播（CombatEventBus.emit）
	POST,           ## 后处理（冷却记录/统计）
}

## 阶段名称（调试用）
static func name_of(phase: Phase) -> String:
	return Phase.keys()[phase]


## 阶段转移验证 — 只允许顺序前进，或重置到 IDLE / 异步进入 EVENT
static func is_valid_transition(from: Phase, to: Phase) -> bool:
	# 始终允许回到 IDLE（重置）
	if to == Phase.IDLE:
		return true
	# 始终允许进入 EVENT（异步触发链：投射物命中、TriggeredEffect 链）
	if to == Phase.EVENT:
		return true
	# 否则必须严格顺序前进
	return to == from + 1


## 事件类型 → 允许的阶段映射
static func allowed_phases_for_event(event_type: CombatEvent.Type) -> Array[Phase]:
	match event_type:
		CombatEvent.Type.ON_CAST:
			return [Phase.EVENT]                    ## 仅施法事件阶段
		CombatEvent.Type.ON_HIT:
			return [Phase.IDLE, Phase.EVENT]        ## 异步命中 或 链式触发
		CombatEvent.Type.ON_DAMAGE:
			return [Phase.IDLE, Phase.EVENT, Phase.POST]
		CombatEvent.Type.ON_KILL:
			return [Phase.IDLE, Phase.EVENT, Phase.POST]
		CombatEvent.Type.ON_HEAL:
			return [Phase.IDLE, Phase.EVENT, Phase.POST]
		CombatEvent.Type.ON_STATUS_APPLIED, CombatEvent.Type.ON_STATUS_REMOVED:
			return [Phase.IDLE, Phase.EVENT, Phase.POST]
		CombatEvent.Type.ON_DODGE, CombatEvent.Type.ON_CRIT:
			return [Phase.IDLE, Phase.EVENT]
		_:
			return [Phase.EVENT]
