class_name MapAmenityData
extends Resource
## Spatial access to existing services, not a second crafting/rest implementation.
@export var id := ""
@export var title := ""
@export var pos := Vector2.ZERO
@export_enum("rest", "craft", "equipment", "mediation") var service := "craft"
