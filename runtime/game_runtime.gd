class_name GameRuntime
extends Node
## GameRuntime — 顶层运行时协调器 (Autoload)
##
## 五大 Runtime 边界:
##   CombatRuntime (纯计算) — 伤害/技能/Modifier/事件
##   WorldRuntime (状态一致性) — WorldState/MapObject/SceneTree同步
##   SimulationRuntime (统一调度) — Surface/Propagation/Respawn tick
##   UIRuntime (只观察) — HUD/菜单/背包
##   SaveRuntime (持久化) — 序列化/反序列化
##
## 依赖方向铁律: simulation → world → combat (通过 CommandBus)
##                  combat 纯计算，无依赖
##                  ui/save 只读所有 Runtime

## 子 Runtime 引用
var combat_runtime: Node = null
var world_runtime: Node = null
var simulation_runtime: Node = null
var command_bus: CommandBus = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_runtimes()


func _process(delta: float) -> void:
	# 1. 分发 CommandBus 队列
	if command_bus:
		command_bus.dispatch()
	
	# 2. SimulationRuntime 统一 tick
	if simulation_runtime and simulation_runtime.has_method("tick"):
		simulation_runtime.tick(delta)


func _setup_runtimes() -> void:
	# CommandBus
	command_bus = CommandBus.new()
	command_bus.name = "CommandBus"
	add_child(command_bus)
	
	# WorldRuntime（如果存在）
	if has_node("WorldRuntime"):
		world_runtime = $WorldRuntime
	
	# SimulationRuntime（如果存在）
	if has_node("SimulationRuntime"):
		simulation_runtime = $SimulationRuntime
	
	# CombatRuntime（如果存在）
	if has_node("CombatRuntime"):
		combat_runtime = $CombatRuntime


## 暂停/恢复
func set_paused(paused: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_ALWAYS


func _to_string() -> String:
	return "GameRuntime(cmd_q=%d)" % (command_bus._queue.size() if command_bus else 0)
