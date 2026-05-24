class_name MarkerRegistry
extends RefCounted
## 全局 Marker 注册表 — marker_id → global_position (Vector2)


static var _positions: Dictionary = {}


static func register(marker: WorldMarker) -> void:
	if marker.marker_id.is_empty():
		return
	_positions[marker.marker_id] = marker.global_position


static func get_position(marker_id: String) -> Vector2:
	if _positions.has(marker_id):
		return _positions[marker_id]
	push_warning("MarkerRegistry: 未找到 '%s'" % marker_id)
	return Vector2.ZERO


static func has(marker_id: String) -> bool:
	return _positions.has(marker_id)


static func clear() -> void:
	_positions.clear()
