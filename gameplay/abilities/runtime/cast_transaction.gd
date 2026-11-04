class_name CastTransaction
extends RefCounted
## A synchronous resource transaction. No facts escape before every effect accepts.
var batch := SkillExecutionBatch.new()
var mana: ManaComponent
var buffs: BuffManager
var supplies: CastingSupplies
var _fields: Array[FireSigil] = []
var execution_id: int
var _health_snapshot: Dictionary = {}
var _health: HealthComponent
var _finished := false

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
	for component in plan.components:
		if component.field != null:
			if not is_instance_valid(component.field) or not component.field.consume(plan.actor, component.version, execution_id):
				return false
			_fields.append(component.field)
	var consumed: Dictionary = {}
	for requirement in plan.status_conditions:
		if requirement.consume and not consumed.has(requirement.id):
			if not buffs or not buffs.remove_status(requirement.id, BuffManager.RemovalReason.CONSUMED):
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
	_finish(false)
	if _health:
		_health.hp = _health_snapshot.hp
		_health.max_hp = _health_snapshot.max_hp

func _finish(commit: bool) -> void:
	assert(not _finished)
	_finished = true
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
