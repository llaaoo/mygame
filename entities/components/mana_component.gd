class_name ManaComponent
extends Node
## 魔能组件 — MP / 消耗 / 自动回复
## 挂载到任意施法实体（Player、Enemy），与 HealthComponent 同级

@export var max_mp: int = 50
@export var mp_regen_rate: float = 2.0       ## 每秒回复量
@export var mp_regen_delay: float = 2.0       ## 施法后延迟（秒）才开始回复

signal mp_changed(current_mp: int, max_mp: int)

var mp: int = 50
var _time_since_use: float = 0.0
var _regen_accumulator: float = 0.0


func _ready() -> void:
	mp = max_mp


func _process(delta: float) -> void:
	if mp >= max_mp:
		return
	_time_since_use += delta
	if _time_since_use >= mp_regen_delay:
		_regen_accumulator += mp_regen_rate * delta
		var amt := int(_regen_accumulator)
		if amt > 0:
			_regen_accumulator -= amt
			mp = mini(max_mp, mp + amt)
			mp_changed.emit(mp, max_mp)


## 消耗 MP，返回是否成功
func use_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if mp < amount:
		return false
	mp -= amount
	_time_since_use = 0.0
	_regen_accumulator = 0.0
	mp_changed.emit(mp, max_mp)
	return true


## 回复 MP（药水/Buff 等调用）
func restore_mp(amount: int) -> void:
	mp = mini(max_mp, mp + amount)
	mp_changed.emit(mp, max_mp)
