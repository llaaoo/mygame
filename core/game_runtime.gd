class_name GameRuntime
extends Node
## GameRuntime — 顶层运行时协调器 (Runtime Root)
##
## 五大 Runtime 边界:
##   CombatRuntime (纯计算) — 伤害/技能/Modifier/事件（CombatExecutor + CombatEventBus）
##   WorldRuntime (状态一致性) — WorldState/MapObject/SceneTree同步
##   SimulationRuntime (统一调度) — Surface/Propagation/Respawn tick
##   UIRuntime (只观察) — HUD/菜单/背包
##   SaveRuntime (持久化) — 序列化/反序列化
##
## 依赖方向铁律: simulation → world → combat (通过 CommandBus)
##                  combat 纯计算，无依赖
##                  ui/save 只读所有 Runtime
##
## Runtime 唯一访问入口（禁止硬编码路径查找）:
##   GameRuntime.instance.get_world_runtime()
##   GameRuntime.instance.get_command_bus()

## ── 全局静态访问 ──
static var instance: GameRuntime = null

## ── 子 Runtime 引用 ──
var world_runtime: WorldRuntime = null
var simulation_runtime: SimulationRuntime = null
var command_bus: CommandBus = null

## CombatExecutor / CombatEventBus 由 GameRuntime 统一创建（Player 不再越权创建）
var combat_executor: CombatExecutor = null
var combat_event_bus: CombatEventBus = null


func _init() -> void:
	# _init 在 autoload 时最早执行，确保 instance 立即可用
	if instance == null:
		instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if instance == null:
		instance = self
	_setup_runtimes()


func _process(delta: float) -> void:
	# 1. 分发 CommandBus 队列
	if command_bus:
		command_bus.dispatch()

	# 2. SimulationRuntime 统一 tick
	if simulation_runtime and simulation_runtime.has_method("tick"):
		simulation_runtime.tick(delta)


## ── Runtime 初始化 ──

func _setup_runtimes() -> void:
	# === CommandBus（最先创建，其他 Runtime 依赖它） ===
	if not command_bus:
		command_bus = CommandBus.new()
		command_bus.name = "CommandBus"
		add_child(command_bus)

	# === CombatRuntime（CombatExecutor + CombatEventBus 统一归 GameRuntime 管理） ===
	_setup_combat_runtime()

	# === WorldRuntime（如果场景中已有则复用，否则创建） ===
	if has_node("WorldRuntime"):
		world_runtime = $WorldRuntime as WorldRuntime
	else:
		world_runtime = WorldRuntime.new()
		world_runtime.name = "WorldRuntime"
		add_child(world_runtime)

	# === SimulationRuntime（如果场景中已有则复用，否则创建） ===
	if has_node("SimulationRuntime"):
		simulation_runtime = $SimulationRuntime as SimulationRuntime
	else:
		simulation_runtime = SimulationRuntime.new()
		simulation_runtime.name = "SimulationRuntime"
		add_child(simulation_runtime)

	# === 连接 Simulation → World 依赖 ===
	if simulation_runtime and world_runtime and simulation_runtime.has_method("setup_dependencies"):
		simulation_runtime.setup_dependencies(world_runtime.spatial_index, world_runtime.state_manager)

	# === WorldTime 也归 GameRuntime 管理 ===
	_setup_world_time()

	# === SaveRuntime — F5 保存 / F9 读取 ===
	if not has_node("SaveManager"):
		var sv := SaveManager.new()
		sv.name = "SaveManager"
		add_child(sv)

	print("🏛️ GameRuntime: 五大 Runtime 初始化完成")
	print("   CommandBus       : %s" % ("✅" if command_bus else "❌"))
	print("   CombatExecutor   : %s" % ("✅" if combat_executor else "❌"))
	print("   CombatEventBus   : %s" % ("✅" if combat_event_bus else "❌"))
	print("   WorldRuntime     : %s" % ("✅" if world_runtime else "❌"))
	print("   SimulationRuntime: %s" % ("✅" if simulation_runtime else "❌"))
	print("   WorldTime        : %s" % ("✅" if WorldTime.instance else "❌"))


## ── Combat Runtime 初始化 ──

func _setup_combat_runtime() -> void:
	# CombatExecutor — 唯一控制流入口
	if not CombatExecutor.instance:
		combat_executor = CombatExecutor.new()
		combat_executor.name = "CombatExecutor"
		CombatExecutor.instance = combat_executor
	else:
		combat_executor = CombatExecutor.instance
	if not combat_executor.is_inside_tree():
		add_child(combat_executor)

	# CombatEventBus — 全局事件广播
	if not CombatEventBus.instance:
		combat_event_bus = CombatEventBus.new()
		combat_event_bus.name = "CombatEventBus"
		CombatEventBus.instance = combat_event_bus
	else:
		combat_event_bus = CombatEventBus.instance
	if not combat_event_bus.is_inside_tree():
		add_child(combat_event_bus)


## ── WorldTime 初始化 ──

func _setup_world_time() -> void:
	if WorldTime.instance:
		return
	var wt := WorldTime.new()
	wt.name = "WorldTime"
	add_child(wt)


## ── 公开访问器（禁止硬编码路径查找） ──

func get_world_runtime() -> WorldRuntime:
	return world_runtime


func get_simulation_runtime() -> SimulationRuntime:
	return simulation_runtime


func get_command_bus() -> CommandBus:
	return command_bus


func get_combat_executor() -> CombatExecutor:
	return combat_executor


## ── 暂停/恢复 ──

func set_paused(paused: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_ALWAYS


func _to_string() -> String:
	return "GameRuntime(cmd_q=%d, world_objs=%d)" % [
		command_bus._queue.size() if command_bus else 0,
		world_runtime.spatial_index.get_object_count() if world_runtime else 0
	]
