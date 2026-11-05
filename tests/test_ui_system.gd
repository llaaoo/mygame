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
		_check(skill_bar != null and (skill_bar.get("_sources") as Array).size() == 8, "skill bar must expose 2 hand and 6 quick slots")

	var inventory := scene.get_node_or_null("InventoryPanel") as CanvasLayer
	var skill_pool := scene.get_node_or_null("SkillPoolUI") as CanvasLayer
	var skill_tree := scene.get_node_or_null("SkillTreeUI") as CanvasLayer
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
	var tooltip := bar._panels[1]._make_custom_tooltip(bar._panels[1].tooltip_text) as Control
	root.add_child(tooltip)
	for i in range(2): await process_frame
	_check(tooltip.size.x <= 400 and tooltip.size.y <= 480, "Skill tooltip covers the viewport")
	tooltip.queue_free()
	game.ui.show_panel("不可中断的提示", "测试", choices, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game.ui._unhandled_input(escape)
	_check(is_instance_valid(game.ui.modal) and paused, "Escape bypassed locked modal")
	await fixture.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
