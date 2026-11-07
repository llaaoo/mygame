class_name GameRuntime
extends Node
signal runtimes_ready
## GameRuntime — 顶层运行时协调器 (Runtime Root)
##
## 五大 Runtime 边界:
##   CombatRuntime (结算) — 伤害/技能/Modifier/事件（CombatExecutor + CombatEventBus）
##   WorldRuntime (状态一致性) — WorldState/MapObject/SceneTree同步
##   SimulationRuntime (统一调度) — Surface/Propagation/Respawn tick
##   UIRuntime (展示与请求) — HUD/菜单/背包
##   SaveRuntime (持久化) — 序列化/反序列化
##
## 公共接口接受同步请求/查询；已提交事实广播事件，延迟世界工作使用带scope的CommandBus。
## UI可请求领域服务操作，SaveManager通过恢复接口写入；文件I/O由SaveRepository负责。
##
## Runtime 唯一访问入口（禁止硬编码路径查找）:
##   GameRuntime.instance.get_world_runtime()
##   GameRuntime.instance.get_command_bus()

## ── 全局静态访问 ──
static var instance: GameRuntime = null

## ── 子 Runtime 引用 ──
@export var legacy_player: Player
@export var legacy_region: Node2D

var world_runtime: WorldRuntime = null
var simulation_runtime: SimulationRuntime = null
var command_bus: CommandBus = null
var region_runtime: RegionRuntime = null
var region_session: RegionSession

## CombatExecutor / CombatEventBus 由 GameRuntime 统一创建（Player 不再越权创建）
var combat_executor: CombatExecutor = null
var combat_event_bus: CombatEventBus = null


func _enter_tree() -> void:
	if not is_instance_valid(instance):
		instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_runtimes()
	RuntimeRegistration.runtime_ready(self)
	runtimes_ready.emit()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# 1. 分发 CommandBus 队列
	if command_bus:
		command_bus.dispatch()

	if combat_executor:
		combat_executor.tick(delta)

	# 2. SimulationRuntime 统一 tick
	if simulation_runtime and simulation_runtime.has_method("tick"):
		simulation_runtime.tick(delta)


## ── Runtime 初始化 ──

func _setup_runtimes() -> void:
	region_session = RegionSession.new(self)
	# === CommandBus（最先创建，其他 Runtime 依赖它） ===
	if not command_bus:
		command_bus = CommandBus.new()
		command_bus.name = "CommandBus"
		add_child(command_bus)

	# === CombatRuntime（CombatExecutor + CombatEventBus 统一归 GameRuntime 管理） ===
	_setup_combat_runtime()

	if not has_node("ElementHitBindings"):
		var elements := preload("res://gameplay/combat/on_hit/element_hit_bindings.gd").new(combat_event_bus)
		elements.name="ElementHitBindings"
		add_child(elements)

	# === WorldRuntime（如果场景中已有则复用，否则创建） ===
	if has_node("WorldRuntime"):
		world_runtime = $WorldRuntime as WorldRuntime
	else:
		world_runtime = WorldRuntime.new()
		world_runtime.name = "WorldRuntime"
		add_child(world_runtime)
	world_runtime.bind_command_bus(command_bus)

	# === SimulationRuntime（如果场景中已有则复用，否则创建） ===
	if has_node("SimulationRuntime"):
		simulation_runtime = $SimulationRuntime as SimulationRuntime
	else:
		simulation_runtime = SimulationRuntime.new()
		simulation_runtime.name = "SimulationRuntime"
		add_child(simulation_runtime)

	# === 连接 Simulation → World 依赖 ===
	simulation_runtime.setup_dependencies(
			world_runtime.spatial_index,
			world_runtime.state_manager,
			command_bus,
	)

	# === WorldTime 也归 GameRuntime 管理 ===
	_setup_world_time()

	# === SaveRuntime — F5 保存 / F9 读取 ===
	if not has_node("SaveManager"):
		var sv := SaveManager.new()
		sv.name = "SaveManager"
		add_child(sv)

	if has_node("RegionRuntime"):
		region_runtime = $RegionRuntime as RegionRuntime
	else:
		region_runtime = RegionRuntime.new()
		region_runtime.name = "RegionRuntime"
		add_child(region_runtime)
	region_runtime.setup(region_session, get_parent(), legacy_player, legacy_region)

	# === 伤害数字生成器（监听 CombatEventBus → 浮动数字） ===
	if not has_node("DamageNumberSpawner"):
		var dns := DamageNumberSpawner.new(combat_event_bus)
		dns.name = "DamageNumberSpawner"
		add_child(dns)

	# === Boss 血条（顶部居中） ===
	if not has_node("BossHPBar"):
		var bar := BossHPBar.new()
		bar.name = "BossHPBar"
		add_child(bar)

	print("🏛️ GameRuntime: 五大 Runtime 初始化完成")
	print("   CommandBus       : %s" % ("✅" if command_bus else "❌"))
	print("   CombatExecutor   : %s" % ("✅" if combat_executor else "❌"))
	print("   CombatEventBus   : %s" % ("✅" if combat_event_bus else "❌"))
	print("   WorldRuntime     : %s" % ("✅" if world_runtime else "❌"))
	print("   SimulationRuntime: %s" % ("✅" if simulation_runtime else "❌"))
	print("   WorldTime        : %s" % ("✅" if WorldTime.instance else "❌"))


## ── Combat Runtime 初始化 ──

func _setup_combat_runtime() -> void:
	combat_event_bus = CombatEventBus.new()
	combat_event_bus.name = "CombatEventBus"
	combat_executor = CombatExecutor.new(combat_event_bus)
	combat_executor.name = "CombatExecutor"
	if instance == self:
		CombatEventBus.instance = combat_event_bus
		CombatExecutor.instance = combat_executor
	add_child(combat_event_bus)
	add_child(combat_executor)


func _setup_world_time() -> void:
	var clock := WorldTime.new()
	clock.name = "WorldTime"
	if instance == self:
		WorldTime.instance = clock
	add_child(clock)


## ── 公开访问器（禁止硬编码路径查找） ──

func get_world_runtime() -> WorldRuntime:
	return world_runtime


func get_simulation_runtime() -> SimulationRuntime:
	return simulation_runtime


func get_command_bus() -> CommandBus:
	return command_bus


func get_region_runtime() -> RegionRuntime:
	return region_runtime

func get_region_session() -> RegionSession:
	return region_session


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
