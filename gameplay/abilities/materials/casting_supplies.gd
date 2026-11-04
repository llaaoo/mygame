class_name CastingSupplies
extends RefCounted
## Inventory owns counts; plans only contain immutable costs. No consumption in preview.
signal changed

const MATERIAL_IDS := ["ash", "resin", "frost_salt", "storm_dust", "echo_ink", "venom_extract", "ward_powder"]
const RAW_TITLES := {"charcoal": "炭屑", "sap": "树液", "crystal": "晶砂"}
var amounts: Dictionary = {}
var selected: Dictionary = {}
var catalog: Dictionary = {}
var crafting_recipes: Dictionary = {}
var _transaction: Dictionary = {}
var _notification_pending := false

func _init() -> void:
	for id in MATERIAL_IDS:
		catalog[id] = load("res://content/casting_materials/%s.tres" % id)
		crafting_recipes[id] = load("res://content/crafting/%s.tres" % id)

func count(id: String) -> int:
	return int(amounts.get(id, 0))

func title(id: String) -> String:
	return catalog[id].title if catalog.has(id) else str(RAW_TITLES.get(id, id))

func grant(items: Dictionary) -> void:
	for id in items:
		if catalog.has(id) or RAW_TITLES.has(id):
			amounts[id] = count(id) + maxi(0, int(items[id]))
	_notify_changed()

func can_pay(costs: Dictionary) -> bool:
	for id in costs:
		if int(costs[id]) < 0 or count(id) < int(costs[id]):
			return false
	return true

func pay(costs: Dictionary) -> bool:
	if not can_pay(costs):
		return false
	for id in costs:
		amounts[id] = count(id) - int(costs[id])
	if not costs.is_empty():
		_notify_changed()
	return true

func configure(action_id: String, material_id: String) -> void:
	if material_id.is_empty():
		selected.erase(action_id)
	elif catalog.has(material_id):
		selected[action_id] = material_id
	_notify_changed()

func craft(id: String) -> bool:
	var recipe := crafting_recipes.get(id) as CraftingRecipe
	if not recipe or not can_pay(recipe.inputs):
		return false
	begin_transaction()
	pay(recipe.inputs)
	grant({recipe.output_id: recipe.output_count})
	var notify := finish_transaction(true)
	if notify.is_valid():
		notify.call()
	return true

func plan(action: SkillData, base: SkillData, include_required: bool = true) -> Dictionary:
	var costs: Dictionary = {}
	var material_id := str(selected.get(action.get_id(), ""))
	var optional: CastingMaterialData = catalog.get(material_id)
	if optional and not optional.supports(action.get_id(), base.get_id()):
		optional = null
		material_id = ""
	if include_required and not action.required_material.is_empty():
		costs[action.required_material] = action.material_amount
	if optional:
		costs[material_id] = int(costs.get(material_id, 0)) + 1
	return {"skill": optional.modify(base) if optional else base, "costs": costs, "material_id": material_id, "extra_mana": optional.extra_mana if optional else 0, "field_bonus": optional.field_lifetime_bonus if optional else 0.0}

func describe_cost(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for id in costs:
		parts.append("%s ×%d（持有%d）" % [title(id), int(costs[id]), count(id)])
	return "、".join(parts)

func serialize() -> Dictionary:
	return {"amounts": amounts.duplicate(), "selected": selected.duplicate()}

func restore(data: Dictionary) -> void:
	amounts.clear()
	selected.clear()
	for id in data.get("amounts", {}):
		if catalog.has(id) or RAW_TITLES.has(id):
			amounts[id] = maxi(0, int(data.amounts[id]))
	for id in data.get("selected", {}):
		if catalog.has(data.selected[id]):
			selected[id] = data.selected[id]
	_notify_changed()

func _notify_changed() -> void:
	if not _transaction.is_empty():
		_notification_pending = true
	else:
		changed.emit()

func begin_transaction() -> void:
	assert(_transaction.is_empty())
	_transaction = serialize()
	_notification_pending = false

func finish_transaction(commit: bool) -> Callable:
	if _transaction.is_empty():
		return Callable()
	if not commit:
		amounts = _transaction.amounts
		selected = _transaction.selected
	_transaction.clear()
	var notify := commit and _notification_pending
	_notification_pending = false
	return changed.emit if notify else Callable()
