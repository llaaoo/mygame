extends SceneTree
## Shared fixture only. Test cases never inherit other test cases.

class Target extends CharacterBody2D:
	var hits := 0
	var move_speed := 100.0
	func take_damage(_amount: int) -> void:
		hits += 1

var errors: Array[String] = []
var game: MVPGame

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int = 5) -> void:
	for i in range(count):
		await process_frame

func _travel(id: String) -> void:
	game.request_travel(id)
	await _frames()
	_check(game.region_id == id, "Travel failed: " + id)

func _interact(title: String) -> void:
	var found: ExplorationInteractable
	for node in get_nodes_in_group("interactable"):
		if node is ExplorationInteractable and node.title.begins_with(title):
			found = node
			break
	_check(found != null, "Interaction missing: " + title)
	if found:
		game.player.global_position = found.global_position
		game.player._try_interact()
		await _frames()

func _clear_encounter() -> void:
	for enemy in game.active_enemies.duplicate():
		enemy.health_component.invincible = false
		CombatExecutor.instance.reset_chain()
		CombatExecutor.report_hit(game.player, enemy, 2000, enemy.global_position, null, ["test"])
	await _frames()
	_check(game.active_enemies.is_empty() and game.progress.cleared.has(game.region_id), "Actual deaths did not clear encounter")

func _target(offset: Vector2) -> Target:
	var target := Target.new()
	target.collision_layer = 2
	target.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10
	collider.shape = shape
	target.add_child(collider)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	target.position = game.player.position + offset
	game.region_root.add_child(target)
	return target


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		push_error(message)

class SpellTarget extends CharacterBody2D:
	var damage_taken := 0
	var move_speed := 100.0
	func take_damage(amount: int) -> void:
		damage_taken += amount

var sm: SkillManager
var controller: ConditionalCastController
var supplies: CastingSupplies

func _dummy(offset: Vector2, enemy_group: bool = false) -> SpellTarget:
	var target := SpellTarget.new()
	target.collision_layer = 2
	target.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12
	collider.shape = shape
	target.add_child(collider)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	target.position = game.player.position + offset
	game.region_root.add_child(target)
	if enemy_group:
		target.add_to_group("enemy")
	return target

func _cast(slot: int, direction := Vector2.RIGHT) -> void:
	var action := sm.get_slot(slot).data
	_check(sm.use_slot(slot, game.player, direction), "Cast rejected: " + action.get_id() + " / " + controller.last_message)
	await create_timer(0.95 if action.get_id().ends_with("_sigil") else 0.7).timeout

func _sandbox() -> void:
	await _travel("camp")
	game.player.global_position = Vector2(12000, 12000)
	game.player.mana_component.max_mp = 300
	game.player.mana_component.mp = 300
	game.player.mana_component.mp_regen_rate = 0
	game.player.health_component.regen_rate = 0

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / 64), floori(point.y / 64))

func _puzzle(id: String) -> SpellWorldObject:
	for node in game.region_root.get_children():
		if node is SpellWorldObject and node.spec.id == id:
			return node
	return null

class HealthTarget extends CharacterBody2D:
	var health: HealthComponent
	var calls := 0
	var move_speed := 100.0
	func take_damage(amount: int) -> void:
		calls += 1
		health.take_damage(amount)

class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool:
		return false

func _empowered_cast(slot: int, direction := Vector2.RIGHT) -> void:
	var skill := sm.get_slot(slot).data
	var context := CastContext.simple(game.player, direction, skill)
	context.empower = true
	_check(sm.use_slot_with_context(slot, game.player, context), "Empowered cast rejected: " + skill.get_id() + " / " + controller.last_message)
	await create_timer(0.95 if skill.get_id().ends_with("_sigil") else 0.7).timeout

func _health_target(offset: Vector2) -> HealthTarget:
	var target := HealthTarget.new()
	target.collision_layer = 2
	target.collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 12
	var body_shape := CollisionShape2D.new()
	body_shape.shape = shape
	target.add_child(body_shape)
	var hurt := Area2D.new()
	hurt.collision_layer = 8
	hurt.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = shape.duplicate()
	hurt.add_child(hurt_shape)
	target.add_child(hurt)
	hurt.owner = target
	target.health = HealthComponent.new()
	target.health.name = "HealthComponent"
	target.health.max_hp = 1000
	target.health.regen_rate = 0
	target.add_child(target.health)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	target.position = game.player.position + offset
	game.region_root.add_child(target)
	target.health.setup(body_shape)
	return target

func _arena() -> void:
	await _sandbox()
	for pair in [[0, "pulse"], [1, "focus"], [2, "frost_sigil"], [3, "echo_mark"], [4, "fire_sigil"], [5, "ignite"]]:
		sm.equip_slot(pair[0], sm.pool.get_skill(pair[1]))
	for id in supplies.selected.keys():
		supplies.configure(id, "")

func _hit_puzzle(skill_id: String, puzzle: SpellWorldObject) -> void:
	var skill := sm.pool.get_skill(skill_id)
	var context := CastContext.at_position(game.player, puzzle.global_position, skill)
	context.world = game.region_root
	_check(sm.executor.execute(skill, context), "Puzzle spell failed: " + skill_id)
	await create_timer(0.2).timeout

class RejectSecond extends SkillExecutor:
	var accepted := 0
	func execute(skill: SkillData, context: CastContext) -> bool:
		accepted += 1
		return false if accepted == 2 else super.execute(skill, context)

func _place(id: String) -> FireSigil:
	sm.equip_slot(4, sm.pool.get_skill(id + "_sigil"))
	var cooldown := sm.get_cooldown("slot_4")
	if cooldown > 0:
		await create_timer(cooldown + 0.1).timeout
	await _cast(4)
	return controller.field

func _run() -> void:
	push_error("ExplorationCase is a fixture, not a test case")
	quit(1)
