extends SceneTree

const Fixture := preload("res://tests/support/mvp_fixture.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	await process_frame

	var hud: Node = scene.get_node_or_null("HUDLayer")
	var run_manager: Node = scene.get_node_or_null("RunManager")
	_check(hud != null, "HUD missing")
	_check(run_manager != null, "RunManager missing")
	if hud and run_manager:
		var status := hud.get_node("MarginContainer/HUDRoot/StatusPanel") as Control
		var run_top := run_manager.get_node("RunOverlay/RunTopPanel") as Control
		var skill_panel := hud.get_node("MarginContainer/HUDRoot/SkillBarPanel") as Control
		_check(status.get_global_rect().end.x <= run_top.get_global_rect().position.x, "HUD overlaps run objective")
		_check(skill_panel.get_global_rect().end.y <= root.size.y, "skill bar leaves viewport")
		var skill_bar := hud.get("skill_bar") as SkillBar
		_check(skill_bar != null and (skill_bar.get("_sources") as Array).size() == 9 and "quick_e" in skill_bar._sources and "slot_0" in skill_bar._sources, "skill bar must expose independent Q/E/R and six numeric shortcuts")

	var inventory := scene.get_node_or_null("InventoryPanel") as CanvasLayer
	var skill_pool := scene.get_node_or_null("SkillPoolUI") as CanvasLayer
	var skill_tree := hud.get_node_or_null("SkillTreeUI") as CanvasLayer if hud else null
	for modal in [inventory, skill_pool, skill_tree]:
		_check(modal != null, "modal UI missing")
		if modal:
			_check(modal.layer == GameUIStyle.LAYER_MODAL, "%s has inconsistent layer" % modal.name)
			_check(modal.is_in_group("modal_ui"), "%s is not coordinated as a modal" % modal.name)

	if inventory:
		inventory.open()
		await process_frame
		var panel := inventory.get_node("Panel") as Control
		var viewport_rect := Rect2(Vector2.ZERO, root.size)
		_check(viewport_rect.encloses(panel.get_global_rect()), "inventory panel leaves viewport")
		inventory.close()

	scene.queue_free()
	current_scene = null
	for i in range(5): await process_frame
	await _test_expedition_layout()
	if _failures.is_empty(): print("UI system passed: legacy HUD, responsive expedition panels, bounded tooltips, keyboard focus and modal lifecycle")
	quit(0 if _failures.is_empty() else 1)

func _test_expedition_layout() -> void:
	root.size = Vector2i(960, 600)
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	var choices: Array[Dictionary] = []
	for i in range(12):
		choices.append({"title": "选择 %d" % i, "disabled": i == 0, "callback": game.ui.close_modal})
	game.ui.show_panel("长内容与材料配置", "水系可清洗、凝霜与导电；主动消费恩赐会失去原有防护。".repeat(120), choices)
	for i in range(4): await process_frame
	var panel := game.ui._modal_panel
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "MVP modal leaves minimum viewport")
	var scroll := panel.find_child("BodyScroll", true, false) as ScrollContainer
	var body := scroll.get_child(0) as RichTextLabel
	_check(body.size.x <= scroll.size.x and body.get_content_height() > scroll.size.y, "Long casting text cannot wrap/scroll within the panel")
	var focused := root.gui_get_focus_owner() as Button
	_check(focused != null and not focused.disabled and focused.text == "选择 1", "Keyboard focus did not skip disabled action")
	_scroll_down(scroll.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(scroll.scroll_vertical > 0, "Mouse wheel did not scroll the modal body")
	root.size = Vector2i(1280, 720)
	for i in range(4): await process_frame
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "MVP modal failed to resize with viewport")
	game.ui.close_modal()
	_check(not paused and not game.player.ui_blocked, "Closing panel left gameplay blocked")
	root.size = Vector2i(960, 600)
	for i in range(4): await process_frame
	var hud := game.get_node("HUDLayer")
	var status := hud.get_node("MarginContainer/HUDRoot/StatusPanel") as Control
	_check(status.get_global_rect().end.x <= game.ui._heading_panel.get_global_rect().position.x, "Expedition heading overlaps resources at minimum width")
	var bar := hud.get("skill_bar") as SkillBar
	_check(bar._hint_panel.get_global_rect().end.y <= bar.global_position.y, "Cast information overlaps skill slots")
	var tooltip := bar._panels[bar._sources.find("right")]._make_custom_tooltip(bar._panels[bar._sources.find("right")].tooltip_text) as Control
	root.add_child(tooltip)
	for i in range(2): await process_frame
	_check(tooltip.size.x <= 400 and tooltip.size.y <= 480, "Skill tooltip covers the viewport")
	tooltip.queue_free()
	game.ui.show_panel("不可中断的提示", "测试", choices, true)
	_tap(KEY_ESCAPE)
	await process_frame
	_check(is_instance_valid(game.ui.modal) and paused, "Escape bypassed locked modal")
	game.ui.close_modal()
	await _test_cast_interruption(game)
	await fixture.close()


func _test_cast_interruption(game: MVPGame) -> void:
	var player := game.player
	var skills := player.skill_manager
	var casting := player.casting
	skills.restrict_actions = false

	skills.equip_slot(0, skills.pool.get_skill("charged_fireball"))
	var mana := player.mana_component.mp
	_key(KEY_1, true)
	await _input_frames()
	_check(casting._charging_source == "slot_0", "Physical skill key did not start charging")
	_tap(KEY_J)
	await process_frame
	_check(is_instance_valid(game.ui.modal) and paused and player.ui_blocked, "Journal shortcut did not block gameplay")
	_check(casting._charging_source.is_empty() and casting.aiming_sources.is_empty(), "Opening a modal kept a held charge")
	_key(KEY_1, false)
	_tap(KEY_ESCAPE)
	await _input_frames()
	_check(not paused and not player.ui_blocked, "Escape did not close the journal")
	_check(player.mana_component.mp == mana, "Releasing a cancelled charge cast through the modal")

	skills.equip_slot(0, skills.pool.get_skill("ice_storm"))
	_key(KEY_1, true)
	await _input_frames()
	_check(casting._channeling_source == "slot_0", "Physical skill key did not start channeling")
	_tap(KEY_J)
	await process_frame
	_check(is_instance_valid(game.ui.modal) and casting._channeling_source.is_empty(), "Opening a modal kept an active channel")
	mana = player.mana_component.mp
	_key(KEY_1, false)
	_tap(KEY_ESCAPE)
	await _input_frames()
	_check(player.mana_component.mp == mana, "Cancelled channel resumed spending mana")

	_key(KEY_1, true)
	await _input_frames()
	_check(casting._channeling_source == "slot_0", "Channel could not restart after reopening the controls")
	skills.unequip_slot(0)
	await _input_frames()
	_check(casting._channeling_source.is_empty(), "Unequipping the source retained its channel")
	_key(KEY_1, false)
	await _input_frames()

	var spark := skills.pool.get_skill("ignite").create_runtime_variant()
	spark.preparation = 0.8
	skills.equip_slot(0, spark)
	_key(KEY_1, true)
	await _input_frames()
	_key(KEY_1, false)
	await _input_frames()
	_check(not skills.combinations.pending.is_empty(), "Release did not create a conditional cast plan")
	_tap(KEY_J)
	await process_frame
	_check(is_instance_valid(game.ui.modal) and skills.combinations.pending.is_empty(), "Paused modal retained an uncommitted spell")
	mana = player.mana_component.mp
	_tap(KEY_ESCAPE)
	await create_timer(1.0).timeout
	_check(player.mana_component.mp == mana, "Uncommitted spell resumed after closing the modal")


func _scroll_down(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var wheel := InputEventMouseButton.new()
	wheel.position = point
	wheel.global_position = point
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	var release := wheel.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(key: Key) -> void:
	_key(key, true)
	_key(key, false)


func _input_frames() -> void:
	for i in range(3):
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
