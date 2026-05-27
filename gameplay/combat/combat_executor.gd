class_name CombatExecutor
extends Node
## 战斗执行器 — 唯一控制流入口
## 
## 原则（Single Authority Rule）：
##   - 只有 CombatExecutor 能发射事件
##   - 只有 CombatExecutor 能跨阶段调度
##   - Modifier/Graph/Projectile/HealthComponent 都必须通过它
## 
## 反模式（禁止）：
##   ❌ Projectile._emit_hit_event() 直接调 CombatEventBus
##   ❌ HealthComponent._emit_damage_event() 直接调 CombatEventBus
##   ❌ Modifier.modify() 内部触发副作用
## 
## 正确模式：
##   ✅ Projectile → CombatExecutor.report_hit()
##   ✅ HealthComponent → CombatExecutor.report_damage()
##   ✅ CombatExecutor → 检查 phase → CombatEventBus.emit()

## ── 全局静态访问 ──
static var instance: CombatExecutor = null

## ── 阶段跟踪 ──
var current_phase: CombatPhase.Phase = CombatPhase.Phase.IDLE
var _previous_phase: CombatPhase.Phase = CombatPhase.Phase.IDLE
var _phase_violations: int = 0                ## 阶段违规计数器（调试用）
var _phase_violation_limit: int = 3           ## 连续违规上限（触发即重置）

## ── 深度限制（防爆炸） ──
const MAX_EVENT_DEPTH: int = 3
const MAX_GRAPH_DEPTH: int = 10
const MAX_CHAIN_LENGTH: int = 10

## ── 链式计数 ──
var _chain_count: int = 0

## ── TriggeredEffect 冷却表（所有权上交） ──
## key = TriggeredEffect Resource, value = last_trigger_time (float)
## TriggeredEffect 自身不再持有任何运行时状态
var _trigger_cooldowns: Dictionary = {}


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


## ── 唯一事件发射入口 ──

## 报告命中 — 唯一伤害入口（事件 + 扣血）
## 所有命中源（Projectile/AoE/近战/陷阱/DOT）只能通过此方法造成伤害
static func report_hit(caster: Node2D, target: Node2D, damage: int, position: Vector2, skill: SkillData = null, tags: Array = []) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_HIT, caster, target, {"damage": damage, "position": position, "tags": tags}, skill)
		_apply_damage(target, damage, tags)
		return
	instance._enforce_emit(CombatEvent.Type.ON_HIT, caster, target, {"damage": damage, "position": position, "tags": tags}, skill)
	_apply_damage(target, damage, tags)


## 内部：安全调用 Damageable.take_damage()
static func _apply_damage(target: Node2D, amount: int, tags: Array = []) -> void:
	if amount <= 0:
		return
	# 存储命中标签（供 MapObject 判断破坏类型）
	if not tags.is_empty() and "set_meta" in target:
		target.set_meta("_last_hit_tags", tags)
	if target and target.has_method("take_damage"):
		target.take_damage(amount)


## 报告伤害（替代 HealthComponent._emit_damage_event）
static func report_damage(target: Node2D, amount: int, remaining_hp: int) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_DAMAGE, null, target, {"damage": amount, "remaining_hp": remaining_hp}, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_DAMAGE, null, target, {"damage": amount, "remaining_hp": remaining_hp}, null)


## 报告击杀（替代 HealthComponent._emit_kill_event）
static func report_kill(target: Node2D, overkill: int, position: Vector2) -> void:
	# 读取 _last_hit_tags（由 _apply_damage 在 take_damage 前写入）
	var tags: Array = []
	if target and "get_meta" in target:
		var raw = target.get_meta("_last_hit_tags", [])
		if raw is Array:
			tags = raw
	if not instance:
		_emit_direct(CombatEvent.Type.ON_KILL, null, target, {"overkill_damage": overkill, "position": position, "tags": tags}, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_KILL, null, target, {"overkill_damage": overkill, "position": position, "tags": tags}, null)


## 报告施法（替代 SkillExecutor._emit_event）
static func report_cast(caster: Node2D, target: Node2D, skill: SkillData, extra_data: Dictionary = {}) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_CAST, caster, target, extra_data, skill)
		return
	instance._enforce_emit(CombatEvent.Type.ON_CAST, caster, target, extra_data, skill)


## ── 强制执行 ──

func _enforce_emit(type: CombatEvent.Type, source: Node2D, target: Node2D, data: Dictionary, skill: SkillData) -> void:
	# 1. 深度防火墙
	if CombatEventBus._emit_depth >= MAX_EVENT_DEPTH:
		_record_firewall("MAX_EVENT_DEPTH=%d" % MAX_EVENT_DEPTH)
		return

	# 2. 链式防火墙
	_chain_count += 1
	if _chain_count > MAX_CHAIN_LENGTH:
		_record_firewall("MAX_CHAIN_LENGTH=%d" % MAX_CHAIN_LENGTH)
		_chain_count = 0
		return

	# 3. 仅在合法阶段发射
	if not _can_emit_in_phase(type):
		_record_firewall("phase=%s not allowed for %s" % [CombatPhase.name_of(current_phase), CombatEvent.Type.keys()[type]])
		return

	# 4. 委托给总线
	var bus := CombatEventBus.instance
	if not bus:
		return

	# 记录事件
	_record_trace_event(type, source, target, data)

	var ev := CombatEvent.create(type, source, target)
	ev.skill = skill
	ev.data = data
	bus.emit(ev)


func _record_firewall(reason: String) -> void:
	var trace := CombatDebugger.active()
	if trace:
		trace.record_firewall(reason)


func _record_trace_event(type: CombatEvent.Type, source: Node2D, target: Node2D, data: Dictionary) -> void:
	var trace := CombatDebugger.active()
	if not trace:
		return
	var src_name: String = source.name if source else "?"
	var tgt_name: String = target.name if target else "?"
	trace.record_event(CombatEvent.Type.keys()[type], src_name, tgt_name, data)


## 阶段门控：事件类型只能在指定阶段发射
func _can_emit_in_phase(type: CombatEvent.Type) -> bool:
	var allowed := CombatPhase.allowed_phases_for_event(type)
	return current_phase in allowed


## ── 直发（无 CombatExecutor 时的降级路径） ──
static func _emit_direct(type: CombatEvent.Type, source: Node2D, target: Node2D, data: Dictionary, skill: SkillData) -> void:
	var bus := CombatEventBus.instance
	if not bus:
		return
	var ev := CombatEvent.create(type, source, target)
	ev.skill = skill
	ev.data = data
	bus.emit(ev)


## ── 链式计数重置（每次新技能施放时调用） ──
func reset_chain() -> void:
	_chain_count = 0


## ── 阶段转换（带转移验证） ──

## 进入新阶段 — 验证转移合法性
func enter_phase(phase: CombatPhase.Phase) -> bool:
	if not CombatPhase.is_valid_transition(current_phase, phase):
		_phase_violations += 1
		push_warning("[CombatExecutor] 非法阶段转移: %s → %s (#%d)" % [
			CombatPhase.name_of(current_phase),
			CombatPhase.name_of(phase),
			_phase_violations
		])
		if _phase_violations >= _phase_violation_limit:
			push_error("[CombatExecutor] 阶段违规达上限 (%d)，强制重置为 IDLE" % _phase_violation_limit)
			_force_idle()
		return false

	_previous_phase = current_phase
	current_phase = phase
	_phase_violations = 0

	var trace := CombatDebugger.active()
	if trace:
		trace.record(
			CombatTraceEvent.Category.PHASE_ENTER,
			phase,
			"PHASE: %s" % CombatPhase.name_of(phase),
			"", "",
			{"from": CombatPhase.name_of(_previous_phase)},
			{}
		)
	return true


func _force_idle() -> void:
	_previous_phase = current_phase
	current_phase = CombatPhase.Phase.IDLE
	_phase_violations = 0
	_chain_count = 0


## ── 施法序列（完整阶段生命周期，供 SkillManager 调用） ──

func begin_cast_sequence() -> bool:
	return enter_phase(CombatPhase.Phase.INPUT)


func end_cast_sequence() -> void:
	enter_phase(CombatPhase.Phase.POST)
	enter_phase(CombatPhase.Phase.IDLE)
	_chain_count = 0


## ── 异步命中序列（供 Projectile/FlameStorm.hit 调用） ──

func begin_hit_sequence() -> bool:
	_chain_count = 0  ## 每个命中链独立计数，避免跨链累计阻断 ON_KILL
	return enter_phase(CombatPhase.Phase.EVENT)


func end_hit_sequence() -> void:
	enter_phase(CombatPhase.Phase.IDLE)


## ── TriggeredEffect 冷却管理（唯一权威） ──

## 检查并更新 TriggeredEffect 冷却
## 返回 true = 允许触发，false = 冷却中
func check_trigger_cooldown(effect: Resource, cd: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = _trigger_cooldowns.get(effect, -INF)
	if now - last < cd:
		return false
	_trigger_cooldowns[effect] = now
	return true


## ── 额外伤害（TriggeredEffect 专用入口，不走事件系统避免递归） ──

## 施加奖金伤害 — 唯一世界写入口
static func report_bonus_damage(source: Node2D, target: Node2D, amount: int, skill: SkillData = null, tags: Array = []) -> void:
	if amount <= 0:
		return
	if not instance:
		# 降级路径：无 Executor 时直接调用
		if target and target.has_method("take_damage"):
			target.take_damage(amount)
		return
	instance._apply_bonus_damage(source, target, amount, skill, tags)


func _apply_bonus_damage(source: Node2D, target: Node2D, amount: int, skill: SkillData, tags: Array) -> void:
	if not target or not target.has_method("take_damage"):
		return
	# 安全检查：目标已死则跳过
	if "hp" in target and target.hp <= 0:
		return
	target.take_damage(amount)

	var trace := CombatDebugger.active()
	if trace:
		var src_name: String = source.name if source else "?"
		trace.record(
			CombatTraceEvent.Category.EVENT_EMIT,
			CombatPhase.Phase.EVENT,
			"BONUS_DAMAGE", src_name, target.name,
			{"damage": amount},
			{"damage": amount, "target": target.name}
		)


## ── 经验奖励（TriggeredEffect 专用入口） ──

## 发放经验 — 唯一世界写入口
static func report_exp_bonus(target: Node2D, amount: int) -> void:
	if amount <= 0 or not target:
		return
	if not instance:
		# 降级路径
		_apply_exp_fallback(target, amount)
		return
	instance._apply_exp_bonus(target, amount)


func _apply_exp_bonus(target: Node2D, amount: int) -> void:
	var stats := target.get_node_or_null("StatsComponent")
	if stats and stats.has_method("add_experience"):
		stats.add_experience(amount)
		return
	_apply_exp_fallback(target, amount)


static func _apply_exp_fallback(target: Node2D, amount: int) -> void:
	if target.has_method("add_experience"):
		target.add_experience(amount)
		return
	var stats := target.get_node_or_null("StatsComponent")
	if stats and stats.has_method("add_experience"):
		stats.add_experience(amount)


## ── 治疗事件（HealthComponent 专用入口） ──

## 报告治疗 — 唯一事件发射入口
static func report_heal(target: Node2D, amount: int) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_HEAL, null, target, {"amount": amount}, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_HEAL, null, target, {"amount": amount}, null)


## ── 状态事件（BuffManager 专用入口） ──

## Buff/Debuff 施加
static func report_status_applied(target: Node2D, buff: Buff) -> void:
	var data := {
		"buff_name": buff.display_name,
		"effect": buff.describe(),
		"duration": buff.duration,
	}
	if not instance:
		_emit_direct(CombatEvent.Type.ON_STATUS_APPLIED, null, target, data, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_STATUS_APPLIED, null, target, data, null)


## Buff/Debuff 移除
static func report_status_removed(target: Node2D, buff: Buff) -> void:
	var data := {
		"buff_name": buff.display_name,
		"effect": buff.describe(),
	}
	if not instance:
		_emit_direct(CombatEvent.Type.ON_STATUS_REMOVED, null, target, data, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_STATUS_REMOVED, null, target, data, null)
