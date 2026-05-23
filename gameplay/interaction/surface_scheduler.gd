class_name SurfaceScheduler
extends Node
## SurfaceScheduler — 表面状态倒计时 → 过期/自然迁移
##
## 每个活跃表面 cell 有 remaining 倒计时，到期后自动迁移到默认状态

const MAX_SURFACE_CELLS := 256

## _active_surfaces: Dictionary[Vector2i, Dictionary]
##   {"state": "burning", "remaining": 5.0, "source": "oil_barrel_03"}
var _active_surfaces: Dictionary = {}


func tick(delta: float) -> void:
	var expired: Array[Vector2i] = []
	
	for cell: Vector2i in _active_surfaces:
		var surf: Dictionary = _active_surfaces[cell]
		surf["remaining"] = surf.get("remaining", 0.0) - delta
		if surf["remaining"] <= 0.0:
			expired.append(cell)
	
	for cell: Vector2i in expired:
		_expire_cell(cell)


func set_surface(cell: Vector2i, state: String, duration: float, source: String = "") -> void:
	if _active_surfaces.size() >= MAX_SURFACE_CELLS:
		return
	
	_active_surfaces[cell] = {
		"state": state,
		"remaining": duration,
		"source": source
	}


func get_surface(cell: Vector2i) -> Dictionary:
	return _active_surfaces.get(cell, {"state": "dry", "remaining": 0.0})


func get_cells_in_radius(pos: Vector2, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cell_radius := ceili(radius / 64.0) + 1
	var center := Vector2i(floori(pos.x / 64), floori(pos.y / 64))
	
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if _active_surfaces.has(cell):
				result.append(cell)
	
	return result


func _expire_cell(cell: Vector2i) -> void:
	var surf: Dictionary = _active_surfaces[cell]
	var state: String = surf.get("state", "")
	
	# 自然迁移规则
	match state:
		"burning":
			_active_surfaces[cell] = {"state": "dry", "remaining": 0.0, "source": "expiry"}
		"frozen":
			_active_surfaces[cell] = {"state": "wet", "remaining": 0.0, "source": "expiry"}
		"wet", "oiled":
			_active_surfaces.erase(cell)  # 回到 dry（默认）
		_:
			_active_surfaces.erase(cell)


func _to_string() -> String:
	return "SurfaceScheduler(active=%d)" % _active_surfaces.size()
