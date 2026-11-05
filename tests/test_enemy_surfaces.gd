extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	GameRuntime.instance.set_process(false)
	var enemy := load("res://entities/enemy/enemy.tscn").instantiate() as Enemy
	enemy.position = Vector2(24032, 24032)
	enemy.ai_role = Enemy.AIRole.RANGED
	game.region_root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var awareness := enemy.surface_awareness
	# Test the action and patrol/return movement paths, not just the status flag.
	var buffs := enemy.get_node("BuffManager") as BuffManager
	enemy.surface_awareness = null
	enemy.resolve_action(Action.move(Vector2.RIGHT, enemy))
	var ordinary_speed := enemy.velocity.length()
	buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"), enemy)
	enemy.resolve_action(Action.move(Vector2.RIGHT, enemy))
	check(is_equal_approx(enemy.velocity.length(), ordinary_speed * .3), "Frozen did not slow actual enemy action movement")
	enemy._move_towards_point(enemy.position + Vector2.RIGHT * 200)
	check(is_equal_approx(enemy.velocity.length(), ordinary_speed * .3), "Frozen did not slow patrol/return movement")
	buffs.remove_status("frozen")
	enemy.resolve_action(Action.move(Vector2.RIGHT, enemy))
	check(is_equal_approx(enemy.velocity.length(), ordinary_speed), "Enemy speed did not recover after freeze")
	enemy.surface_awareness = awareness
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	var cell := SurfaceManager.cell_at(enemy.global_position)
	surfaces.force_set_surface(cell + Vector2i.RIGHT, "burning", 12)
	awareness.steer(Vector2.RIGHT)
	awareness.tick(.25)
	check(awareness.direction.dot(Vector2.RIGHT) < .99 and awareness.last_candidate_queries <= 8, "Enemy ignored danger ahead or exceeded candidate budget")
	var evaluations := awareness.evaluations
	for i in range(10): awareness.tick(.01)
	check(awareness.evaluations == evaluations, "Enemy reevaluated hazards every frame")
	# All directions may be dangerous: pick the least harmful valid option, do not gain immunity.
	for x in range(-1, 2):
		for y in range(-1, 2): surfaces.force_set_surface(cell + Vector2i(x, y), "burning", 12)
	surfaces.force_set_surface(cell + Vector2i.UP, "poisoned", 12)
	awareness.steer(Vector2.RIGHT)
	awareness.tick(.25)
	check(awareness.should_evade and awareness.direction.dot(Vector2.UP) > .99, "Trapped enemy did not select the least harmful route")
	surfaces.tick_entity_surface()
	check((enemy.get_node("BuffManager") as BuffManager).has_buff("burning"), "Hazard avoidance granted damage/status immunity")
	# Candidate steering also respects actual static collision.
	GameRuntime.instance.get_simulation_runtime().clear_region()
	var wall := StaticBody2D.new()
	wall.position = enemy.position + Vector2(45, 0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 90)
	shape.shape = rect
	wall.add_child(shape)
	game.region_root.add_child(wall)
	await physics_frame
	awareness.steer(Vector2.RIGHT)
	awareness.tick(.25)
	check(awareness.direction.dot(Vector2.RIGHT) < .99 and not enemy.test_move(enemy.global_transform, awareness.direction * 64), "Enemy steering chose a wall-crossing candidate")
	# Batch checks remain bounded at full surface capacity.
	for x in range(16):
		for y in range(16): surfaces.force_set_surface(Vector2i(500 + x, 500 + y), "poisoned", 12)
	var enemies: Array[Enemy] = []
	for i in range(20):
		var item := load("res://entities/enemy/enemy.tscn").instantiate() as Enemy
		item.position = Vector2(32032 + i * 128, 32032)
		game.region_root.add_child(item)
		item.set_physics_process(false)
		item.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(item)
	await physics_frame
	for step in range(40):
		for item in enemies:
			item.surface_awareness.steer(Vector2.RIGHT)
			item.surface_awareness.tick(.25)
			check(item.surface_awareness.last_candidate_queries <= 8, "Batch enemy exceeded its bounded query count")
	check(GameRuntime.instance.get_simulation_runtime().surface_cells().size() == 256, "Surface capacity changed during AI evaluation")
	await fixture.close()
	if errors.is_empty(): print("Enemy surfaces passed: bounded local steering, risk preferences, no-safe-route behavior, real harm, collisions and batch limits")
	quit(0 if errors.is_empty() else 1)
