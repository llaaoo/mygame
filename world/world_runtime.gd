class_name WorldRuntime
extends Node
## WorldRuntime — 世界运行时入口
##
## 职责: 维护 WorldState 一致性、MapObject 生命周期、SceneTree 同步
## 输入: CommandBus 订阅 (DESTROYED / RESPAWN_REQUEST / CHUNK_LOAD_REQUEST)
## 输出: WorldStateDelta
##
## 依赖: WorldSpatialIndex + WorldStateManager
## 禁止: 伤害计算、AI 调度、技能逻辑

var spatial_index: WorldSpatialIndex
var state_manager: WorldStateManager
var command_bus: CommandBus = null


func _init() -> void:
	spatial_index = WorldSpatialIndex.new()
	state_manager = WorldStateManager.new()


func _ready() -> void:
	state_manager.name = "WorldStateManager"
	add_child(state_manager)
	_connect_to_bus()


func _connect_to_bus() -> void:
	# 通过 GameRuntime.instance 获取 CommandBus（不再硬编码路径）
	var gr := GameRuntime.instance
	if gr:
		command_bus = gr.get_command_bus()
	
	if command_bus:
		command_bus.subscribe_for_target(RuntimeCommand.TYPE_DESTROYED, RuntimeCommand.Target.WORLD, _on_destroyed_command)
		command_bus.subscribe_for_target(RuntimeCommand.TYPE_RESPAWN_REQUEST, RuntimeCommand.Target.WORLD, _on_respawn_request)
		command_bus.subscribe_for_target("CHUNK_LOAD_REQUEST", RuntimeCommand.Target.WORLD, _on_chunk_load_request)
	else:
		# 延迟重试：GameRuntime 可能尚未初始化完成
		await get_tree().process_frame
		_connect_to_bus()


## 注册 MapObject（场景加载时调用）
func register_object(obj: MapObject) -> void:
	spatial_index.register(obj)
	state_manager.register(obj)


## 注销 MapObject（场景卸载时调用）
func unregister_object(obj: MapObject) -> void:
	spatial_index.unregister(obj)
	state_manager.unregister(obj.get_object_id())


## --- CommandBus 订阅 ---

func _on_destroyed_command(cmd: RuntimeCommand) -> void:
	var object_id: String = cmd.payload.get("object_id", "")
	var state_data: Dictionary = cmd.payload.get("state_data", {})
	
	# 更新 WorldState
	if not state_data.is_empty():
		state_manager.update_state(object_id, state_data)
	
	# 重生倒计时 → 转发给 SimulationRuntime
	var respawn_time: float = cmd.payload.get("respawn_time", -1.0)
	if respawn_time > 0.0 and command_bus:
		state_manager.update_state(object_id, {
			"state": "RESPAWNING",
			"respawn_at": respawn_time
		})
		var respawn_cmd := RuntimeCommand.create(
			RuntimeCommand.TYPE_RESPAWN_REQUEST,
			"WorldRuntime",
			RuntimeCommand.Target.SIMULATION,
			{
				"object_id": object_id,
				"object_path": cmd.payload.get("object_path", ""),
				"respawn_time": respawn_time,
			}
		)
		command_bus.emit(respawn_cmd)
	
	# AOE 伤害 + 表面生成 → 转发给 SimulationRuntime
	var aoe_radius: float = cmd.payload.get("destruction_radius", 0.0)
	var surface: String = cmd.payload.get("destruction_surface", "")
	var surface_radius: float = cmd.payload.get("destruction_surface_radius", 0.0)
	
	if (aoe_radius > 0.0) or (not surface.is_empty() and surface_radius > 0.0):
		if command_bus:
			var surf_cmd := RuntimeCommand.create(
				RuntimeCommand.TYPE_SURFACE_CHANGE,
				"WorldRuntime",
				RuntimeCommand.Target.SIMULATION,
				{
					"position": cmd.payload.get("position", Vector2.ZERO),
					"destruction_radius": aoe_radius,
					"destruction_aoe_damage": cmd.payload.get("destruction_aoe_damage", 0),
					"destruction_aoe_tags": cmd.payload.get("destruction_aoe_tags", []),
					"surface_state": surface,
					"surface_radius": surface_radius,
					"display_name": cmd.payload.get("display_name", ""),
				}
			)
			command_bus.emit(surf_cmd)
			print("📨 WorldRuntime: 转发 TYPE_SURFACE_CHANGE → SimulationRuntime (r=%.0f, surface=%s)" % [aoe_radius + surface_radius, surface])


func _on_respawn_request(cmd: RuntimeCommand) -> void:
	var object_id: String = cmd.payload.get("object_id", "")
	state_manager.update_state(object_id, {
		"state": "RESPAWNING",
		"respawn_at": cmd.payload.get("respawn_time", 60.0)
	})


func _on_chunk_load_request(cmd: RuntimeCommand) -> void:
	# Chunk 加载时，恢复该区域内所有持久状态
	pass  # 由 ChunkLoader 调用 restore_objects


func _to_string() -> String:
	return "WorldRuntime(objs=%d)" % (spatial_index.get_object_count() if spatial_index else 0)
