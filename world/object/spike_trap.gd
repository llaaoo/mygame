class_name SpikeTrap
extends Area2D
## 陷阱 — 实体进入后周期性造成伤害
##
## 适用: 地刺、毒雾、火焰地板等


@export var damage: int = 10
@export var tick_interval: float = 0.5

var _bodies_in_trap: Array[Node2D] = []
var _timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # ACTOR
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 禁用独立 _process，改为 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_register_with_simulation")


## 注册到 SimulationRuntime（统一 tick）
func _register_with_simulation() -> void:
	var gr := GameRuntime.instance
	if not gr:
		call_deferred("_register_with_simulation")
		return
	var sim := gr.get_simulation_runtime()
	if not sim:
		call_deferred("_register_with_simulation")
		return
	sim.register_ticker(self)


## 统一 tick 入口（由 SimulationRuntime 驱动，替代独立 _process）
func tick(delta: float) -> void:
	if _bodies_in_trap.is_empty():
		return
	_timer += delta
	if _timer >= tick_interval:
		_timer -= tick_interval
		_deal_damage()


func _on_body_entered(body: Node2D) -> void:
	if body not in _bodies_in_trap:
		_bodies_in_trap.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies_in_trap.erase(body)


func _deal_damage() -> void:
	for body in _bodies_in_trap:
		if not is_instance_valid(body):
			continue
		if body.has_method("take_damage"):
			CombatExecutor.report_hit(self, body, damage, body.global_position, null, ["trap"])
			body.take_damage(damage)
