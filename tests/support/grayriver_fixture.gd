extends RefCounted
var tree: SceneTree
var game: GrayriverGame
func _init(owner_tree: SceneTree) -> void:tree=owner_tree
func boot(persist:=false, freeze_player_physics:=false) -> GrayriverGame:
	game=load("res://grayriver.tscn").instantiate()
	game.persistence_enabled=persist
	# Persistence assertions may isolate physics from the separately driven status clock.
	if freeze_player_physics: game.get_node("Player").process_mode=Node.PROCESS_MODE_DISABLED
	tree.root.add_child(game)
	tree.current_scene=game
	for i in range(25):await tree.process_frame
	game.ui.close_modal()
	GameRuntime.instance.set_process(false)
	game.player.health_component.regen_rate=0
	game.player.mana_component.mp_regen_rate=0
	freeze_enemies()
	return game
func freeze_enemies() -> void:
	for enemy in game.active_enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
func travel(id: String,point:=Vector2.INF) -> void:
	game.ui.close_modal()
	game._change_region(id,point)
	freeze_enemies()
	for i in range(3):await tree.process_frame
func close() -> void:
	game.ui.close_modal()
	game.queue_free()
	tree.current_scene=null
	for i in range(6):await tree.process_frame
