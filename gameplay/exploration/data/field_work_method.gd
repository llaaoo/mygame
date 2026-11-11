class_name FieldWorkMethod
extends Resource
@export var animation_id: StringName
## A mundane, interruptible operation. Spell costs/boons do not modify it.
@export var id: String
@export var title: String
@export var required_attributes: Dictionary = {}
@export var material_costs: Dictionary = {}
@export var duration := 2.0
## Ritual preparation does not borrow crafting speed.
@export var fixed_duration := false

func fingerprint() -> Array:
	return [id, title, required_attributes.duplicate(), material_costs.duplicate(), duration, fixed_duration]

func validation_error() -> String:
	if id.is_empty() or title.is_empty() or not is_finite(duration) or duration <= 0: return "作业名称或时长无效"
	if not StatsComponent.valid_requirements(required_attributes): return "作业属性条件无效"
	for key in material_costs:
		if not CastingSupplies.known_item(str(key)): return "未知作业材料：" + str(key)
		if not material_costs[key] is int or int(material_costs[key]) <= 0: return "作业材料数量无效"
	return ""
