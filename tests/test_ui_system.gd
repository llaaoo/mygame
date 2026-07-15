extends SceneTree

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

	if _failures.is_empty():
		print("UI system tests passed")
		scene.queue_free()
		await process_frame
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		scene.queue_free()
		await process_frame
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
