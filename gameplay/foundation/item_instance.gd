class_name ItemInstance
extends RefCounted
var uid := ""
var definition_id := ""
var quantity := 1
var properties: Dictionary = {}
func snapshot() -> Dictionary:
	return {"uid":uid,"definition":definition_id,"quantity":quantity,"properties":properties.duplicate(true)}
static func from_snapshot(data: Dictionary) -> ItemInstance:
	var item:=ItemInstance.new()
	item.uid=data.uid
	item.definition_id=data.definition
	item.quantity=int(data.quantity)
	item.properties=data.get("properties",{}).duplicate(true)
	return item
