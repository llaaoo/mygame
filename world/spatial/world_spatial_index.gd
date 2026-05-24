class_name WorldSpatialIndex
extends RefCounted
## WorldSpatialIndex — 统一空间查询入口（每个地图实例一个）
##
## 固定网格分桶方案 (cell_size=64px)
## 所有系统的空间查询必须走此 Index，禁止遍历 SceneTree
##
## 约束 (CONTRACT 9):
##   SPATIAL_CELL_SIZE = 64
##   MAX_QUERY_RESULTS = 32

const CELL_SIZE: int = 64
const MAX_QUERY_RESULTS: int = 32

## _grid: Dictionary[Vector2i, Array[MapObject]]
var _grid: Dictionary = {}
var _object_count: int = 0


## 注册 MapObject
func register(obj: MapObject) -> void:
	var cell := _world_to_cell(obj.global_position)
	if not _grid.has(cell):
		_grid[cell] = []
	
	var list: Array = _grid[cell]
	if obj not in list:
		list.append(obj)
		_object_count += 1


## 注销 MapObject
func unregister(obj: MapObject) -> void:
	var cell := _world_to_cell(obj.global_position)
	if not _grid.has(cell):
		return
	
	var list: Array = _grid[cell]
	if obj in list:
		list.erase(obj)
		_object_count -= 1
		if list.is_empty():
			_grid.erase(cell)


## 更新对象位置（移动后调用）
func update_position(obj: MapObject, old_pos: Vector2) -> void:
	var old_cell := _world_to_cell(old_pos)
	var new_cell := _world_to_cell(obj.global_position)
	
	if old_cell == new_cell:
		return
	
	# 从旧格移除
	if _grid.has(old_cell):
		var old_list: Array = _grid[old_cell]
		old_list.erase(obj)
		if old_list.is_empty():
			_grid.erase(old_cell)
	
	# 加入新格
	if not _grid.has(new_cell):
		_grid[new_cell] = []
	_grid[new_cell].append(obj)


## 半径查询
func query_radius(pos: Vector2, radius: float) -> Array[MapObject]:
	var results: Array[MapObject] = []
	var cell_radius := ceili(radius / CELL_SIZE) + 1
	var center_cell := _world_to_cell(pos)
	
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
			if not _grid.has(cell):
				continue
			
			var stale: Array = []
			for obj: MapObject in _grid[cell]:
				if not is_instance_valid(obj):
					stale.append(obj)
					continue
				if results.size() >= MAX_QUERY_RESULTS:
					_cleanup_stale(stale, cell)
					return results
				if obj.global_position.distance_squared_to(pos) <= radius * radius:
					results.append(obj)
			_cleanup_stale(stale, cell)
	
	return results


## 单元格查询
func query_cell(cell: Vector2i) -> Array:
	return _grid.get(cell, [])


## 标签过滤半径查询
func query_tags(pos: Vector2, radius: float, tags: Array[String]) -> Array:
	var results: Array[MapObject] = []
	var all := query_radius(pos, radius)
	for obj: MapObject in all:
		if results.size() >= MAX_QUERY_RESULTS:
			break
		for tag: String in tags:
			if tag in obj.get_tags():
				results.append(obj)
				break
	return results


## 获取单元格内的表面数据（委托给 SurfaceManager）
func query_surface(cell: Vector2i) -> SurfaceData:
	# 由 WorldRuntime 注入 SurfaceManager 引用
	if _surface_manager and _surface_manager.has_method("get_surface"):
		return _surface_manager.get_surface(cell)
	return null


## 获取半径内的表面单元格
func get_surface_cells_in_radius(pos: Vector2, radius: float) -> Array[Vector2i]:
	if _surface_manager and _surface_manager.has_method("get_cells_in_radius"):
		return _surface_manager.get_cells_in_radius(pos, radius)
	return []


## 清空索引
func clear() -> void:
	_grid.clear()
	_object_count = 0


## 内部
var _surface_manager: Node = null


func set_surface_manager(mgr: Node) -> void:
	_surface_manager = mgr


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(pos.x / CELL_SIZE),
		floori(pos.y / CELL_SIZE)
	)


## 清理网格中的无效引用
func _cleanup_stale(stale: Array, cell: Vector2i) -> void:
	if stale.is_empty() or not _grid.has(cell):
		return
	var list: Array = _grid[cell]
	for obj in stale:
		list.erase(obj)
		_object_count -= 1
	if list.is_empty():
		_grid.erase(cell)


func get_object_count() -> int:
	return _object_count


func _to_string() -> String:
	return "WorldSpatialIndex(cells=%d, objects=%d)" % [_grid.size(), _object_count]
