extends SceneTree
## Render the real MVP with isolated progress. Run with an actual display driver.
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var output := "/tmp/mygame-visual-review"
func _init() -> void: call_deferred("_run")
func capture(name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	assert(result == OK)
	print("Captured: " + output.path_join(name + ".png"))
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1152, 648)
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	await capture("camp")
	game.request_travel("archive")
	for i in range(8): await process_frame
	GameRuntime.instance.set_process(false)
	game.player.global_position = Vector2.ZERO
	game.player.health_component.invincible = true
	for enemy in game.active_enemies:
		enemy.set_physics_process(false)
	var sm := game.player.skill_manager
	sm.restrict_actions = false
	for rule in sm.combinations.rules: sm.combinations.learned_rules[rule.id] = true
	for i in range(6): sm.equip_slot(i, sm.pool.get_skill(["pulse", "focus", "frost_sigil", "water_call", "fire_sigil", "ignite"][i]))
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	for entry in [[Vector2(-180, 60), "wet"], [Vector2(-40, 160), "frozen"], [Vector2(150, 80), "burning"], [Vector2(220, -70), "poisoned"], [Vector2(-200, -80), "electrified"]]:
		surfaces.apply_area(entry[0], 68, [], "visual review", entry[1], 20)
	var field := FireSigil.new()
	field.caster = game.player
	field.position = Vector2(10, -40)
	game.region_root.add_child(field)
	sm.combinations.fields.append(field)
	var flow := sm.pool.get_skill("flow_attunement")
	(game.player.get_node("BuffManager") as BuffManager).apply_buff(flow.buff_resource, game.player, flow)
	await capture("elements")
	# A reproducible mid-frame view of the actual skill archetypes.
	for entry in [["fireball", Vector2(-180, -95)], ["frost_bolt", Vector2(-180, -25)], ["storm_bolt", Vector2(-180, 45)], ["spore_bolt", Vector2(-180, 115)]]:
		var skill := sm.pool.get_skill(entry[0])
		game.player.global_position = entry[1]
		var context := CastContext.simple(game.player, Vector2.RIGHT, skill)
		context.world = game.region_root
		sm.executor.execute(skill, context)
	game.player.global_position = Vector2.ZERO
	for i in range(2): await process_frame
	for projectile in get_nodes_in_group("projectile"): projectile.set_physics_process(false)
	await capture("spell-effects")
	for entry in [["fire_sigil_pulse", Vector2(-210, -80)], ["frost_sigil_pulse", Vector2(0, -80)], ["storm_sigil_pulse", Vector2(210, -80)]]:
		var skill: SkillData = game.catalog.spell_rules[entry[0]].result_skill
		var context := CastContext.at_position(game.player, entry[1], skill)
		context.world = game.region_root
		sm.executor.execute(skill, context)
	for i in range(2): await process_frame
	# Freeze a mid-frame for inspection; this does not change gameplay resources.
	for node in game.region_root.find_children("*", "Area2D", true, false):
		if node is PersistentAOE: node.set_physics_process(false)
	for node in game.region_root.find_children("*", "Node2D", true, false):
		if node is SpellVisual and node.kind == "burst":
			node.elapsed = node.duration * .3
			node.set_process(false)
			node.queue_redraw()
	await capture("spell-bursts")
	game.workshop.show_action(sm.pool.get_skill("focus"))
	await capture("casting-panel")
	root.size = Vector2i(960, 600)
	await capture("casting-panel-small")
	game.ui.close_modal()
	await fixture.close()
	quit()
