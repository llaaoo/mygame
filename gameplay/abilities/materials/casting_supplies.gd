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
var restrict_crafting := false
var known_recipes: Dictionary = {}
var _transaction: Dictionary = {}
var _notification_pending := false
var discarded_legacy_selection := false

func _init() -> void:
	for id in MATERIAL_IDS:
		catalog[id] = load("res://content/casting_materials/%s.tres" % id)
		crafting_recipes[id] = load("res://content/crafting/%s.tres" % id)

func count(id: String) -> int:
	return int(amounts.get(id, 0))

func title(id: String) -> String:
	return catalog[id].title if catalog.has(id) else str(RAW_TITLES.get(id, SurvivalCatalog.TITLES.get(id, id)))

static func known_item(id: String) -> bool:
	return id in MATERIAL_IDS or RAW_TITLES.has(id) or SurvivalCatalog.TITLES.has(id)

func grant(items: Dictionary) -> void:
	for id in items:
		if known_item(id):
			var added := maxi(0, int(items[id]))
			if id in ["clean_water", "dirty_water"]: added = mini(added, maxi(0, SurvivalCatalog.WATER_CAPACITY - SurvivalCatalog.water_count(self)))
			amounts[id] = count(id) + added
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
	if not recipe or not knows_recipe(id) or not can_pay(recipe.inputs):
		return false
	begin_transaction()
	pay(recipe.inputs)
	grant({recipe.output_id: recipe.output_count})
	var notify := finish_transaction(true)
	if notify.is_valid():
		notify.call()
	return true

func recycle_preview(id: String) -> Dictionary:
	var recipe := crafting_recipes.get(id) as CraftingRecipe
	if not recipe or not knows_recipe(id) or not catalog.has(id) or recipe.output_id != id or recipe.output_count <= 0 or recipe.inputs.is_empty(): return {}
	for input in recipe.inputs:
		if (not catalog.has(input) and not RAW_TITLES.has(input)) or not recipe.inputs[input] is int or int(recipe.inputs[input]) <= 0: return {}
	return {"costs": {recipe.output_id: 2 * recipe.output_count}, "returns": recipe.inputs.duplicate()}

func recycle(id: String) -> bool:
	if not _transaction.is_empty(): return false
	var preview := recycle_preview(id)
	if preview.is_empty() or not can_pay(preview.costs): return false
	begin_transaction()
	if not pay(preview.costs):
		finish_transaction(false)
		return false
	grant(preview.returns)
	var notify := finish_transaction(true)
	if notify.is_valid(): notify.call()
	return true

func plan(action: SkillData, base: SkillData, include_required: bool = true, preparation_material: String = "") -> Dictionary:
	var costs: Dictionary = {}
	var material_id := str(selected.get(action.get_id(), ""))
	var optional: CastingMaterialData = catalog.get(material_id)
	var is_preparation := optional != null and material_id == preparation_material
	if optional and not is_preparation and not optional.supports(action.get_id(), base.get_id(), base):
		optional = null
		material_id = ""
	if include_required and not action.required_material.is_empty():
		costs[action.required_material] = action.material_amount
	if optional:
		costs[material_id] = int(costs.get(material_id, 0)) + 1
	return {"skill": optional.modify(base) if optional and not is_preparation else base, "costs": costs, "material_id": material_id, "extra_mana": optional.extra_mana if optional else 0, "field_bonus": optional.field_lifetime_bonus if optional else 0.0}

func describe_cost(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for id in costs:
		parts.append("%s ×%d（持有%d）" % [title(id), int(costs[id]), count(id)])
	return "、".join(parts)

func clear_selection() -> void:
	if selected.is_empty(): return
	selected.clear()
	_notify_changed()

func serialize(persistent := false) -> Dictionary:
	return {"amounts": amounts.duplicate(), "selected": {} if persistent else selected.duplicate()}

func restore(data: Dictionary) -> void:
	amounts.clear()
	selected.clear()
	for id in data.get("amounts", {}):
		if known_item(id):
			var amount := maxi(0, int(data.amounts[id]))
			if id in ["clean_water", "dirty_water"]: amount = mini(amount, maxi(0, SurvivalCatalog.WATER_CAPACITY - SurvivalCatalog.water_count(self)))
			amounts[id] = amount
	discarded_legacy_selection = not data.get("selected", {}).is_empty()
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

func knows_recipe(id: String) -> bool:
	return crafting_recipes.has(id) and (not restrict_crafting or known_recipes.has(id))
