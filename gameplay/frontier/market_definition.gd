class_name MarketDefinition
extends Resource
@export var actor_id := ""
@export var region_id := "camp"
@export var position := Vector2(-3210,2200)
@export var service_range := 150.0
@export var initial_stock: Dictionary={}
func valid() -> bool:
	if actor_id.is_empty() or region_id.is_empty() or not position.is_finite() or not is_finite(service_range) or service_range<=0 or initial_stock.is_empty(): return false
	for key in initial_stock:
		if not key is String or not ItemCatalog.default_catalog().definition(key) or not initial_stock[key] is int or initial_stock[key]<1 or initial_stock[key]>999: return false
	return true
