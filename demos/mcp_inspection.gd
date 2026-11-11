extends GrayriverGame
## Real campaign and normal AI, with a fresh in-memory journey for editor inspection.
var inspection_ready := false

func _ready() -> void:
	persistence_enabled=false
	SaveManager.instance.repository=MemorySaveRepository.new()
	super._ready()
	call_deferred("_finish_inspection")

func _finish_inspection() -> void:
	while not ready_for_play: await get_tree().process_frame
	ui.close_modal()
	inspection_ready=true
	print("MCP inspection ready: normal AI, default resources, isolated memory saves")

func start_location() -> Dictionary:
	return {"region":"camp","position":Vector2(-4000,800)}

func query_profile(sample_id := "") -> Dictionary:
	var reports: Dictionary={}
	var operations: Dictionary={
		"progression":func():return ActorProgression.values(player),
		"inventory_weight":func():return session.inventory.weight("player"),
		"interaction_focus_sweep":func():
			for point in get_tree().get_nodes_in_group("interactable"):player.input_controller.interaction_target(),
		"spell_preview":func():return player.skill_manager.preview_source("right"),
		"enemy_navigation":func():return session.region.navigation.direction(active_enemies[0].position,player.position),
		"all_enemy_visibility":func():
			for enemy in active_enemies:enemy.can_see(player)
	}
	for key: String in operations:
		var started:=Time.get_ticks_usec()
		for i in range(5):operations[key].call()
		reports[key]={"calls":5,"total_usec":Time.get_ticks_usec()-started}
	return {"sample_id":sample_id,"queries":reports,"normal_ai":true,"enemies":active_enemies.size(),"interactables":get_tree().get_nodes_in_group("interactable").size(),"has_focus":player.input_controller.interaction_target()!=null,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"max_fps":Engine.max_fps}
