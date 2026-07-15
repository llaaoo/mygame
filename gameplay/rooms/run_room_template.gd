class_name RunRoomTemplate
extends Resource

@export var template_id: String = "room"
@export var display_name: String = "未知区域"
@export var room_types: PackedStringArray = PackedStringArray()
@export_range(0.1, 10.0, 0.1) var weight: float = 1.0
@export var arena_size: Vector2 = Vector2(1120, 720)
@export_enum("open", "pillars", "crossroads", "split", "gauntlet", "ring", "sanctum") var pattern: String = "open"
@export_range(0, 8, 1) var prop_budget: int = 2
@export_range(0, 8, 1) var hazard_budget: int = 1


func supports(room_type: String) -> bool:
	return room_types.has(room_type)
