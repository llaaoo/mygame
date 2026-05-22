class_name HealthComponent
extends Node
## 生命值组件 — HP/受伤/无敌/死亡/自回
## Player 和 Enemy 共用，挂载为子节点即可

## 属性
@export var max_hp: int = 100
@export var invincible_duration: float = 0.5
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

## 关联的碰撞体（死亡时禁用）
var _collision_shape: CollisionShape2D = null


func setup(shape: CollisionShape2D) -> void:
	_collision_shape = shape
	hp = max_hp


func _process(delta: float) -> void:
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
	if invincible:
		return

	hp = maxi(0, hp - amount)
	_time_since_damage = 0.0
	health_changed.emit(hp, max_hp)

	if hp <= 0:
		is_dead = true
		died.emit()
		if _collision_shape:
			_collision_shape.set_deferred("disabled", true)
		return

	invincible = true
	await get_tree().create_timer(invincible_duration).timeout
	invincible = false


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
