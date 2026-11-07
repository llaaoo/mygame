class_name CastingSupplies
extends RefCounted
## Inventory owns counts; plans only contain immutable costs. No consumption in preview.
signal changed

const MATERIAL_IDS := ["ash", "resin", "frost_salt", "storm_dust", "echo_ink", "venom_extract", "ward_powder"]
const RAW_TITLES := {"charcoal": "炭屑", "sap": "树液", "crystal": "晶砂"}
var inventory_store: InventoryService
var actor_id := ""
var _amounts: Dictionary={}
var amounts: Dictionary:
	get: return inventory_store.material_amounts(actor_id) if inventory_store else _amounts
	set(value):
		if inventory_store:
			if value!=amounts: inventory_store.set_materials(actor_id,value)
		else: _amounts=value
var _inventory_snapshot: Dictionary={}
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
	for recipe in SpellOperationCatalog.default_catalog().recipes: crafting_recipes[recipe.id]=recipe

func count(id: String) -> int:
	return int(amounts.get(id, 0))

func title(id: String) -> String:
	return catalog[id].title if catalog.has(id) else str(RAW_TITLES.get(id, SurvivalCatalog.TITLES.get(id, ItemCatalog.default_catalog().definition(id).display_name if ItemCatalog.default_catalog().definition(id) else id)))

static func known_item(id: String) -> bool:
	return id in MATERIAL_IDS or RAW_TITLES.has(id) or SurvivalCatalog.TITLES.has(id) or ItemCatalog.default_catalog().definition(id)!=null and not ItemCatalog.default_catalog().definition(id) is EquipmentData

func grant(items: Dictionary) -> void:
	for id in items:
		if known_item(id):
			var added := maxi(0, int(items[id]))
			if id in ["clean_water", "dirty_water"]: added = mini(added, maxi(0, SurvivalCatalog.WATER_CAPACITY - SurvivalCatalog.water_count(self)))
			_set_amount(id,count(id)+added)
	_notify_changed()

func can_pay(costs: Dictionary) -> bool:
	if inventory_store: return inventory_store.can_pay(actor_id,costs)
	for id in costs:
		if int(costs[id]) < 0 or count(id) < int(costs[id]):
			return false
	return true

func pay(costs: Dictionary, pocket_only := false) -> bool:
	if inventory_store:
		var paid:=inventory_store.pay(actor_id,costs,pocket_only)
		if paid and not costs.is_empty(): _notify_changed()
		return paid
	if not can_pay(costs):
		return false
	for id in costs:
		_set_amount(id,count(id)-int(costs[id]))
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
	var output_before:=count(recipe.output_id)
	grant({recipe.output_id: recipe.output_count})
	if count(recipe.output_id)-output_before!=recipe.output_count:
		finish_transaction(false)
		return false
	var notify := finish_transaction(true)
	if notify.is_valid():
		notify.call()
	if inventory_store and inventory_store.facts: inventory_store.facts.publish("recipe_crafted",actor_id,{"recipe":id,"quantity":recipe.output_count})
	return true

func recycle_preview(id: String) -> Dictionary:
	var recipe := crafting_recipes.get(id) as CraftingRecipe
	if not recipe or not knows_recipe(id) or (not catalog.has(id) and not ItemCatalog.default_catalog().definition(id)) or recipe.output_id != id or recipe.output_count <= 0 or recipe.inputs.is_empty(): return {}
	for input in recipe.inputs:
		if not known_item(input) or not recipe.inputs[input] is int or int(recipe.inputs[input]) <= 0: return {}
	return {"costs": {recipe.output_id: 2 * recipe.output_count}, "returns": recipe.inputs.duplicate()}

func recycle(id: String) -> bool:
	if not _transaction.is_empty(): return false
	var preview := recycle_preview(id)
	if preview.is_empty() or not can_pay(preview.costs): return false
	begin_transaction()
	if not pay(preview.costs):
		finish_transaction(false)
		return false
	var before: Dictionary={}
	for key in preview.returns: before[key]=count(key)
	grant(preview.returns)
	for key in preview.returns:
		if count(key)-before[key]!=preview.returns[key]:
			finish_transaction(false)
			return false
	var notify := finish_transaction(true)
	if notify.is_valid(): notify.call()
	return true

func plan(action: SkillData, base: SkillData, include_required: bool = true, preparation_material: String = "", manager: SkillManager = null) -> Dictionary:
	if not action.operation_id.is_empty(): return operation_plan(action,manager)
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
	amounts = {}
	selected.clear()
	for id in data.get("amounts", {}):
		if known_item(id):
			var amount := maxi(0, int(data.amounts[id]))
			if id in ["clean_water", "dirty_water"]: amount = mini(amount, maxi(0, SurvivalCatalog.WATER_CAPACITY - SurvivalCatalog.water_count(self)))
			_set_amount(id,amount)
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
	if inventory_store:
		_inventory_snapshot=inventory_store.snapshot_owners([actor_id])
		inventory_store.begin_batch()
	_notification_pending = false

func finish_transaction(commit: bool) -> Callable:
	if _transaction.is_empty():
		return Callable()
	if not commit:
		if inventory_store: inventory_store.restore_actor(actor_id,_inventory_snapshot)
		else: amounts = _transaction.amounts
		selected = _transaction.selected
	_transaction.clear()
	_inventory_snapshot.clear()
	if inventory_store: inventory_store.end_batch(commit)
	var notify := commit and _notification_pending
	_notification_pending = false
	return changed.emit if notify else Callable()

func knows_recipe(id: String) -> bool:
	return crafting_recipes.has(id) and (not restrict_crafting or known_recipes.has(id))

func bind_inventory(store: InventoryService, owner_id: String) -> void:
	inventory_store=store
	actor_id=owner_id
	_amounts.clear()
func can_pay_combat(costs: Dictionary) -> bool:
	return inventory_store.can_pay(actor_id,costs,true) if inventory_store else can_pay(costs)
func _set_amount(id: String, amount: int) -> void:
	if not inventory_store:
		_amounts[id]=amount
		return
	var current:=count(id)
	if amount>current: inventory_store.receive(actor_id,id,amount-current)
	elif amount<current: inventory_store.pay(actor_id,{id:current-amount})

func select_payload(action: SkillData,payload_id: String,manager: SkillManager) -> bool:
	var operation:=SpellOperationCatalog.default_catalog().operation(action.operation_id)
	var payload:=operation.payload(payload_id) if operation else null
	if not payload or not manager.knows_action(action): return false
	selected[action.get_id()]=payload_id
	_notify_changed()
	return true

func operation_plan(action: SkillData,manager: SkillManager) -> Dictionary:
	var entry:=SpellOperationCatalog.default_catalog().operation(action.operation_id)
	var choice:=str(selected.get(action.get_id(),entry.default_payload if entry else ""))
	var medium:=entry.payload(choice) if entry else null
	var result: Dictionary={"skill":action,"costs":{},"material_id":"","extra_mana":0,"field_bonus":0.0,"reason":"请选择释放介质","payload":medium}
	if not medium: return result
	result.skill=entry.compose(medium)
	result.extra_mana=medium.extra_mana
	result.reason="" if manager and manager.knows_action(action) else "尚未掌握这个基础动作"
	if not medium.material_id.is_empty():
		result.material_id=medium.material_id
		result.costs={medium.material_id:medium.quantity}
	return result
