class_name CastTransaction
extends RefCounted
static var _next_id := 0

static func allocate_id() -> int:
	_next_id += 1
	return _next_id

## A synchronous resource transaction. No facts escape before every effect accepts.
var batch := SkillExecutionBatch.new()
var mana: ManaComponent
var buffs: BuffManager
var supplies: CastingSupplies
var _fields: Array[FireSigil] = []
var _surfaces: Array[Dictionary] = []
var execution_id: int
var _health_snapshot: Dictionary = {}
var _health: HealthComponent
var _finished := false
var _soul: SoulRemnant

func _init(actor: Node2D, inventory: CastingSupplies, id: int) -> void:
	mana = actor.get_node_or_null("ManaComponent") as ManaComponent
	buffs = actor.get_node_or_null("BuffManager") as BuffManager
	_health = actor.get_node_or_null("HealthComponent") as HealthComponent
	supplies = inventory
	execution_id = id
	if _health:
		_health_snapshot = {"hp": _health.hp, "max_hp": _health.max_hp}
	if mana:
		mana.begin_transaction()
	if buffs:
		buffs.begin_transaction()
	if supplies:
		supplies.begin_transaction()

func reserve(plan: CastPlan) -> bool:
	if plan.soul_remnant != null:
		if not is_instance_valid(plan.soul_remnant) or not plan.soul_remnant.reserve(plan.soul_revision):
			return false
		_soul = plan.soul_remnant
	for component in plan.components:
		if not component.surface_state.is_empty():
			if not is_instance_valid(component.surface_manager): return false
			var snapshot := component.surface_manager.consume_prepared_surface(component.surface_cell, component.surface_state, component.surface_revision)
			if snapshot.is_empty(): return false
			_surfaces.append({"manager": component.surface_manager, "cell": component.surface_cell, "snapshot": snapshot})
		if component.field != null:
			if not is_instance_valid(component.field) or not component.field.consume(plan.actor, component.version, execution_id):
				return false
			_fields.append(component.field)
	var consumed: Dictionary = {}
	for requirement in plan.status_conditions:
		if requirement.consume and not consumed.has(requirement.id):
			if not buffs:
				return false
			var accepted := buffs.consume_duration(requirement.id) if requirement.mode == CastStatusRequirement.ConsumptionMode.HALF_LIFETIME else buffs.consume_status(requirement.id, requirement.stacks)
			if not accepted:
				return false
			consumed[requirement.id] = true
	return pay(plan.cost, plan.material_costs)

func pay(cost: int, materials: Dictionary = {}) -> bool:
	return (not mana or mana.use_mp(cost)) and (not supplies or supplies.pay(materials))

func commit() -> void:
	_finish(true)

func rollback() -> void:
	if _finished:
		return
	batch.abort()
	for field in _fields:
		if is_instance_valid(field):
			field.refund_consumption(execution_id)
	for surface in _surfaces:
		if is_instance_valid(surface.manager):
			surface.manager.restore_prepared_surface(surface.cell, surface.snapshot)
	_finish(false)
	if _health:
		_health.hp = _health_snapshot.hp
		_health.max_hp = _health_snapshot.max_hp

func _finish(commit: bool) -> void:
	assert(not _finished)
	_finished = true
	if is_instance_valid(_soul):
		_soul.finish(commit)
	var notifications: Array[Callable] = []
	# Finish all mutations before invoking any subscriber.
	if buffs:
		notifications.append(buffs.finish_transaction(commit))
	if mana:
		notifications.append(mana.finish_transaction(commit))
	if supplies:
		notifications.append(supplies.finish_transaction(commit))
	if commit:
		for notify in notifications:
			if notify.is_valid():
				notify.call()
