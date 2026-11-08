class_name SpellPayloadData
extends Resource
## Substance or explicit effect blueprint. The operation owns input/timing;
## an optional SkillData effect supplies existing geometry/status execution.
@export var id := ""
@export var title := ""
## Explicit element family for input assistance; chemistry/requirements still use existing fields.
@export var affinity := ""
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
@export var effect: SkillData
@export var source_field := ""
@export var source_kind := ""
func describe(timed_fields := false) -> String:
	var text:=description
	if effect:
		text+="\n效果："+effect.display_name+"\n"+effect.description
	if damage>0: text+="\n直接伤害 %d"%damage
	for status in statuses: text+="\n"+status.describe()
	if not field_type.is_empty():
		text+="\n存续%.0f秒；每次组合扣%.0f秒，亦自然流逝。"%[120.0 if field_type=="arcane" else 180.0,40.0 if field_type=="arcane" else 30.0] if timed_fields else "\n%d次充能 · %.0f秒"%[field_charges,field_duration]
	if not surface.is_empty():
		var definition:=SurfaceCatalog.definition(surface)
		text+="\n地面：%s · %.0f秒"%[definition.title if definition else surface,surface_duration]
	return text
