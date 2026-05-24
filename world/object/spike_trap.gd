class_name SpikeTrap
extends Area2D
## 陷阱 — 每 tick_interval 对范围内的实体造成 damage 点伤害
## 使用距离检测（不依赖 body_entered 信号或碰撞形状）


@export var damage: int = 10
@export var tick_interval: float = 0.5
@export var trap_radius: float = 48.0  ## 伤害范围（> 碰撞形状尺寸）

var _timer: float = 0.0


func _ready() -> void:
	# tick 由 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	_try_register()


func _try_register() -> void:
	var cb := func():
		var gr := GameRuntime.instance
		if not gr:
			_try_register()
			return
		var sim := gr.get_simulation_runtime()
		if not sim:
			_try_register()
			return
		sim.register_ticker(self)
		print("📎 SpikeTrap 已注册到 SimulationRuntime")
	cb.call_deferred()


func tick(delta: float) -> void:
	_timer += delta
	if _timer < tick_interval:
		return
	_timer -= tick_interval

	for target in _get_damage_targets():
		if target.global_position.distance_squared_to(global_position) <= trap_radius * trap_radius:
			CombatExecutor.report_hit(self, target, damage, target.global_position, null, ["trap"])


func _get_damage_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for group_name in ["player", "enemy"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			var target := node as Node2D
			if target == self or not target.has_method("take_damage"):
				continue
			if target in targets:
				continue
			targets.append(target)
	return targets
