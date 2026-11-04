class_name HealthComponent
extends Node
## 生命值组件 — HP/受伤/无敌/死亡/自回
## Player 和 Enemy 共用，挂载为子节点即可

## 属性
@export var max_hp: int = 100
@export var invincible_duration: float = 0.5
@export var invincibility_blocks_status := true
@export var regen_delay: float = 5.0
@export var regen_rate: float = 3.0

## 信号
signal health_changed(current_hp: int, max_hp: int)
signal died

## 运行时状态
var hp: int = 100
var invincible: bool = false
var is_dead: bool = false
var _time_since_damage: float = 0.0
var _regen_accumulator: float = 0.0
var _invincibility_remaining := 0.0
var _hit_group_depth := 0
var _hit_policies: Array[bool] = []
var _periodic_depth := 0
var _group_damaged := false
var _active_family := ""
var _invincibility_family := ""

## 关联的碰撞体（死亡时禁用）
var _collision_shape: CollisionShape2D = null


func setup(shape: CollisionShape2D) -> void:
	_collision_shape = shape
	hp = max_hp
	# 禁用独立 _process，改为 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_register_with_simulation")


## 注册到 SimulationRuntime（统一 tick）
func _register_with_simulation() -> void:
	RuntimeRegistration.register_ticker(self)


## 统一 tick 入口（由 SimulationRuntime 驱动，替代独立 _process）
func tick(delta: float) -> void:
	if _invincibility_remaining > 0:
		_invincibility_remaining = maxf(0, _invincibility_remaining - delta)
		if _invincibility_remaining == 0:
			invincible = false
	# 脱战自回
	if is_dead or hp >= max_hp:
		return
	_time_since_damage += delta
	if _time_since_damage >= regen_delay:
		_regen_accumulator += regen_rate * delta
		var heal_amt := int(_regen_accumulator)
		if heal_amt > 0:
			_regen_accumulator -= heal_amt
			hp = mini(max_hp, hp + heal_amt)
			health_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	if not can_receive_damage(_active_family) or amount <= 0:
		return
	var buffs := get_parent().get_node_or_null("BuffManager") as BuffManager
	if buffs:
		amount = maxi(1, ceili(amount * buffs.get_damage_taken_multiplier()))

	var previous_hp := hp
	hp = maxi(0, hp - amount)
	if _hit_group_depth > 0 and _periodic_depth == 0:
		_group_damaged = true
	_time_since_damage = 0.0
	health_changed.emit(hp, max_hp)

	# 发射 ON_DAMAGE 事件（伤害已应用）
	_emit_damage_event(amount)

	if hp <= 0:
		is_dead = true
		# 发射 ON_KILL 事件（在 died 信号之前）
		_emit_kill_event(maxi(0, amount - previous_hp))
		died.emit()
		if _collision_shape:
			_collision_shape.set_deferred("disabled", true)
		return

	if _hit_group_depth == 0:
		_start_invincibility()

func can_receive_damage(family: String = "", periodic: bool = false) -> bool:
	return not is_dead and (periodic or _periodic_depth > 0 or not invincible or (not family.is_empty() and family == _invincibility_family))

func can_receive_status(family: String = "") -> bool:
	return not is_dead and (not invincibility_blocks_status or can_receive_damage(family))

func begin_hit_group(family_id: String = "", periodic: bool = false) -> void:
	if _hit_group_depth == 0:
		_group_damaged = false
		_active_family = family_id
	_hit_group_depth += 1
	_hit_policies.append(periodic)
	if periodic:
		_periodic_depth += 1

func end_hit_group() -> void:
	if not _hit_policies.is_empty() and _hit_policies.pop_back():
		_periodic_depth -= 1
	_hit_group_depth = maxi(0, _hit_group_depth - 1)
	if _hit_group_depth == 0 and _group_damaged and not is_dead:
		_start_invincibility()
	if _hit_group_depth == 0:
		_group_damaged = false
		_active_family = ""

func _start_invincibility() -> void:
	invincible = true
	_invincibility_remaining = invincible_duration
	_invincibility_family = _active_family if _hit_group_depth > 0 or _group_damaged else ""


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	_emit_heal_event(amount)


## ── 事件发射 → CombatExecutor（唯一权威入口） ──

func _emit_damage_event(amount: int) -> void:
	CombatExecutor.report_damage(get_parent(), amount, hp)


func _emit_kill_event(amount: int) -> void:
	var parent := get_parent()
	var pos: Vector2 = parent.get("global_position") if "global_position" in parent else Vector2.ZERO
	CombatExecutor.report_kill(parent, amount, pos)


func _emit_heal_event(amount: int) -> void:
	CombatExecutor.report_heal(get_parent(), amount)
