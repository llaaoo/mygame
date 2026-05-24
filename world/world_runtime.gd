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
		command_bus.subscribe("DESTROYED", _on_destroyed_command)
		command_bus.subscribe("RESPAWN_REQUEST", _on_respawn_request)
		command_bus.subscribe("CHUNK_LOAD_REQUEST", _on_chunk_load_request)
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
	var object_node: MapObject = cmd.payload.get("object_node")
	
	if object_node:
		state_manager.update_state(object_id, object_node.get_state())
		
		# 如果有 AOE 连锁，发布 SURFACE_CHANGE 命令
		var aoe_radius: float = cmd.payload.get("destruction_radius", 0.0)
		if aoe_radius > 0.0 and command_bus:
			var aoe_cmd := RuntimeCommand.create(
				"SURFACE_CHANGE",
				"WorldRuntime",
				RuntimeCommand.Target.SIMULATION,
				{
					"position": cmd.payload.get("position", Vector2.ZERO),
					"radius": aoe_radius,
					"tags": cmd.payload.get("destruction_aoe_tags", []),
					"damage": cmd.payload.get("destruction_aoe_damage", 0)
				}
			)
			command_bus.emit(aoe_cmd)


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
