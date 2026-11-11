class_name ManaComponent
extends Node
## 魔能组件 — MP / 消耗 / 自动回复
## 挂载到任意施法实体（Player、Enemy），与 HealthComponent 同级

var magic_state := ActorMagicState.new()
@export var max_mp: int = 50:
	set(value):
		max_mp=maxi(0,value) if not magic_state or magic_state.awakened else 0
		mp=mini(mp,max_mp)
@export var mp_regen_rate: float = 2.0       ## 每秒回复量
@export var mp_regen_delay: float = 2.0       ## 施法后延迟（秒）才开始回复
var regen_multiplier := 1.0
var regen_bonus := 0.0
var regen_bonus_sources: Dictionary = {}
var _recovery_events: Array = []

signal recovered(actual: float, source: String)
signal mp_changed(current_mp: int, max_mp: int)

var mp: int = 50:
	set(value):mp=clampi(value,0,max_mp) if not magic_state or magic_state.awakened else 0
var _time_since_use: float = 0.0
var _regen_accumulator: float = 0.0
var _transaction: Dictionary = {}


func configure_magic(has_aptitude: bool,starts_awakened: bool) -> void:
	magic_state=ActorMagicState.fresh(has_aptitude,starts_awakened)
	max_mp=max_mp
func can_cast(requires_magic := true) -> bool:
	return not requires_magic or magic_state.awakened
func cast_reason(requires_magic := true) -> String:
	return "" if can_cast(requires_magic) else "尚未觉醒魔力，不能施展法术"
func transaction_active() -> bool:return not _transaction.is_empty()


func _ready() -> void:
	mp = max_mp
	# 禁用独立 _process，改为 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_register_with_simulation")


## 注册到 SimulationRuntime（统一 tick）
func _register_with_simulation() -> void:
	RuntimeRegistration.register_ticker(self)


## 统一 tick 入口（由 SimulationRuntime 驱动，替代独立 _process）
func tick(delta: float) -> void:
	if not magic_state.awakened:
		max_mp=0;return
	if mp >= max_mp:
		return
	_time_since_use += delta
	if _time_since_use >= mp_regen_delay:
		_regen_accumulator += (mp_regen_rate + regen_bonus) * regen_multiplier * delta
		var amt := int(_regen_accumulator)
		if amt > 0:
			_regen_accumulator -= amt
			var actual := mini(max_mp - mp, amt)
			mp += actual
			RecoveryAccounting.regeneration(recovered, actual, mp_regen_rate, regen_bonus_sources)
			notify_changed()


## 消耗 MP，返回是否成功
func use_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if not magic_state.awakened:return false
	if mp < amount:
		return false
	mp -= amount
	_time_since_use = 0.0
	_regen_accumulator = 0.0
	notify_changed()
	return true


## 回复 MP（药水/Buff 等调用）
func restore_mp(amount: int, source := "skill") -> void:
	if not magic_state.awakened:return
	var actual := mini(max_mp - mp, maxi(0, amount))
	mp += actual
	if actual > 0:
		if _transaction.is_empty(): recovered.emit(float(actual), source)
		else: _recovery_events.append({"actual": actual, "source": source})
	notify_changed()

func notify_changed() -> void:
	if _transaction.is_empty():
		mp_changed.emit(mp, max_mp)

func begin_transaction() -> void:
	assert(_transaction.is_empty())
	_recovery_events.clear()
	_transaction = {"mp": mp, "max_mp": max_mp, "time": _time_since_use, "accumulator": _regen_accumulator}

func finish_transaction(commit: bool) -> Callable:
	if _transaction.is_empty():
		return Callable()
	var changed: bool = mp != _transaction.mp or max_mp != _transaction.max_mp
	if not commit:
		max_mp = _transaction.max_mp
		mp = _transaction.mp
		_time_since_use = _transaction.time
		_regen_accumulator = _transaction.accumulator
	_transaction.clear()
	var events := _recovery_events.duplicate()
	_recovery_events.clear()
	if not commit: return Callable()
	return func():
		if changed: notify_changed()
		for event in events: recovered.emit(float(event.actual), event.source)
