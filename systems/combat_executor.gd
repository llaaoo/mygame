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

## ── 深度限制（防爆炸） ──
const MAX_EVENT_DEPTH: int = 3
const MAX_GRAPH_DEPTH: int = 10
const MAX_CHAIN_LENGTH: int = 5

## ── 链式计数 ──
var _chain_count: int = 0


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


## ── 唯一事件发射入口 ──

## 报告命中（替代 Projectile/FlameStorm 的 _emit_hit_event）
static func report_hit(caster: Node2D, target: Node2D, damage: int, position: Vector2, skill: SkillData = null, tags: Array = []) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_HIT, caster, target, {"damage": damage, "position": position, "tags": tags}, skill)
		return
	instance._enforce_emit(CombatEvent.Type.ON_HIT, caster, target, {"damage": damage, "position": position, "tags": tags}, skill)


## 报告伤害（替代 HealthComponent._emit_damage_event）
static func report_damage(target: Node2D, amount: int, remaining_hp: int) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_DAMAGE, null, target, {"damage": amount, "remaining_hp": remaining_hp}, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_DAMAGE, null, target, {"damage": amount, "remaining_hp": remaining_hp}, null)


## 报告击杀（替代 HealthComponent._emit_kill_event）
static func report_kill(target: Node2D, overkill: int, position: Vector2) -> void:
	if not instance:
		_emit_direct(CombatEvent.Type.ON_KILL, null, target, {"overkill_damage": overkill, "position": position}, null)
		return
	instance._enforce_emit(CombatEvent.Type.ON_KILL, null, target, {"overkill_damage": overkill, "position": position}, null)


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


## 阶段门控：某些事件类型只能在特定阶段发射
func _can_emit_in_phase(type: CombatEvent.Type) -> bool:
	# IDLE 阶段允许（phase tracking 未激活时的默认状态）
	if current_phase == CombatPhase.Phase.IDLE:
		return true
	# EVENT 阶段允许所有类型
	if current_phase == CombatPhase.Phase.EVENT:
		return true
	# POST 阶段也允许（后处理）
	if current_phase == CombatPhase.Phase.POST:
		return true
	# 其他阶段：拒绝
	return false


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


## ── 阶段转换（仅 CombatExecutor 可调用） ──
func enter_phase(phase: CombatPhase.Phase) -> void:
	current_phase = phase
