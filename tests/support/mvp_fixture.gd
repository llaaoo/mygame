extends RefCounted
## Shared setup independent of any test case or test script inheritance.
var tree: SceneTree
var game: MVPGame

func _init(owner_tree: SceneTree) -> void:
	tree = owner_tree

func boot(persist: bool = false) -> MVPGame:
	game = load("res://mvp.tscn").instantiate()
	game.persistence_enabled = persist
	tree.root.add_child(game)
	tree.current_scene = game
	for i in range(20):
		await tree.process_frame
	game.ui.close_modal()
	game.player.mana_component.mp_regen_rate = 0
	game.player.health_component.regen_rate = 0
	return game

func close() -> void:
	if is_instance_valid(game):
		game.ui.close_modal()
		game.queue_free()
	tree.current_scene = null
	for i in range(6):
		await tree.process_frame
	game = null
