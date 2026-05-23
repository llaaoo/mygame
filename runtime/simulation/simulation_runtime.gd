class_name SimulationRuntime
extends Node
## SimulationRuntime — 统一调度所有持续世界行为
##
## 禁止每个系统独立 _process()
## 调度顺序显式、可审计、可暂停

## 子调度器
var surface_scheduler: SurfaceScheduler = null
var propagation_scheduler: PropagationScheduler = null
var respawn_scheduler: RespawnScheduler = null

## 暂停标记
var is_paused: bool = false


func _ready() -> void:
	_surface_scheduler = SurfaceScheduler.new()
	_surface_scheduler.name = "SurfaceScheduler"
	add_child(_surface_scheduler)
	
	_propagation_scheduler = PropagationScheduler.new()
	_propagation_scheduler.name = "PropagationScheduler"
	add_child(_propagation_scheduler)
	
	_respawn_scheduler = RespawnScheduler.new()
	_respawn_scheduler.name = "RespawnScheduler"
	add_child(_respawn_scheduler)


## 统一 tick（由 GameRuntime._process 驱动）
func tick(delta: float) -> void:
	if is_paused:
		return
	
	# 调度顺序: Surface → Propagation → Respawn
	_surface_scheduler.tick(delta)
	_propagation_scheduler.tick(delta)
	_respawn_scheduler.tick(delta)


func _to_string() -> String:
	return "SimulationRuntime(surf=%d, prop=%d, resp=%d)" % [
		_surface_scheduler._active_surfaces.size() if _surface_scheduler else 0,
		_propagation_scheduler._jobs.size() if _propagation_scheduler else 0,
		_respawn_scheduler._respawn_queue.size() if _respawn_scheduler else 0
	]
