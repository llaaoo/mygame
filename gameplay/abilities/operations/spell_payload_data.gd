class_name SpellPayloadData
extends Resource
## What is carried into an operation. No delivery geometry or executable scripts.
@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export var material_id := ""
@export var quantity := 1
@export var tags: Array[String]=[]
@export var damage := 0
@export var damage_scaling := 0.0
@export var statuses: Array[Buff]=[]
@export var surface := ""
@export var surface_duration := 8.0
@export var field_type := ""
@export var field_charges := 2
@export var field_duration := 15.0
@export var extra_mana := 0
@export var color := Color.WHITE
func describe() -> String:
	var text:=description
	if damage>0: text+="\n直接伤害 %d"%damage
	for status in statuses: text+="\n"+status.describe()
	if not field_type.is_empty(): text+="\n%d次充能 · %.0f秒"%[field_charges,field_duration]
	if not surface.is_empty():
		var definition:=SurfaceCatalog.definition(surface)
		text+="\n地面：%s · %.0f秒"%[definition.title if definition else surface,surface_duration]
	return text
