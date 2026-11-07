class_name SpellOperationData
extends Resource
## How a substance is delivered; payloads supply chemistry and strength.
@export var action: SkillData
@export var knowledge_actions: PackedStringArray=[]
@export var aliases: PackedStringArray=[]
@export var payloads: Array[SpellPayloadData]=[]
@export var default_payload := ""
func payload(id: String) -> SpellPayloadData:
	for entry in payloads:
		if entry.id==id: return entry
	return null
func compose(entry: SpellPayloadData) -> SkillData:
	var result: SkillData=(entry.effect if entry.effect else action).create_runtime_variant()
	result.id=action.get_id()+"."+entry.id
	result.display_name=action.display_name+" · "+entry.title
	result.required_material=""
	result.mp_cost=action.mp_cost
	result.preparation=action.preparation
	result.cooldown=action.cooldown
	result.requires_soul_remnant=entry.source_kind=="soul"
	if entry.effect:
		if action.operation_id=="extract" and result.buff_resource:
			result.buff_resource=result.buff_resource.duplicate() as Buff
			result.buff_resource.set_meta("definition_path",entry.effect.buff_resource.resource_path)
			result.buff_resource.exclusive_group="stored_energy"
			if entry.source_kind!="soul": result.buff_resource.capacity_key=""
			result.buff_resource.max_stacks=3
		result.operation_id=""
		return result
	result.tags=entry.tags.duplicate()
	result.damage=entry.damage
	result.damage_scaling=entry.damage_scaling
	result.contact_statuses=entry.statuses.duplicate()
	result.creates_surface=entry.surface
	result.surface_duration=entry.surface_duration
	result.field_type=entry.field_type
	result.field_charges=entry.field_charges
	result.field_duration=entry.field_duration
	result.aoe_color=entry.color
	result.operation_id="" # This is an execution result, never another input request.
	return result
