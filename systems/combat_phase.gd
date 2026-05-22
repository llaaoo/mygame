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
