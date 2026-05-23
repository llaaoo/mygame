@tool
extends EditorScript

## 全面修复迁移后所有残留旧路径

func _run() -> void:
	var path_map := {
		"res://maps/overworld.tscn": "res://world/maps/overworld.tscn",
		"res://runtime/game_runtime.gd": "res://core/game_runtime.gd",
		"res://runtime/command_bus.gd": "res://core/command/command_bus.gd",
		"res://runtime/runtime_command.gd": "res://core/command/runtime_command.gd",
		"res://runtime/combat/combat_event.gd": "res://core/event/combat_event.gd",
		"res://runtime/combat/combat_event_bus.gd": "res://core/event/combat_event_bus.gd",
		"res://runtime/combat/combat_scope.gd": "res://core/event/combat_scope.gd",
		"res://runtime/combat/state.gd": "res://core/state/state.gd",
		"res://runtime/combat/state_machine.gd": "res://core/state/state_machine.gd",
		"res://runtime/combat/input_setup.gd": "res://core/input_setup.gd",
		"res://runtime/combat/combat_executor.gd": "res://gameplay/combat/combat_executor.gd",
		"res://runtime/combat/combat_phase.gd": "res://gameplay/combat/combat_phase.gd",
		"res://runtime/combat/triggered_effect.gd": "res://gameplay/combat/triggered_effect.gd",
		"res://runtime/combat/skills/manager/skill_manager.gd": "res://gameplay/abilities/manager/skill_manager.gd",
		"res://runtime/combat/skills/runtime/projectile.gd": "res://gameplay/abilities/runtime/projectile.gd",
		"res://runtime/combat/skills/runtime/skill_executor.gd": "res://gameplay/abilities/runtime/skill_executor.gd",
		"res://runtime/combat/skills/data/skill_data.gd": "res://gameplay/abilities/data/skill_data.gd",
		"res://runtime/combat/conditions/condition.gd": "res://gameplay/combat/conditions/condition.gd",
		"res://runtime/combat/debug/combat_debugger.gd": "res://core/debug/combat_debugger.gd",
		"res://runtime/combat/on_hit_apply_status.gd": "res://gameplay/combat/on_hit/on_hit_apply_status.gd",
		"res://runtime/combat/on_kill_bonus_exp.gd": "res://gameplay/combat/on_kill/on_kill_bonus_exp.gd",
		"res://runtime/world/world_runtime.gd": "res://world/world_runtime.gd",
		"res://runtime/world/world_spatial_index.gd": "res://world/spatial/world_spatial_index.gd",
		"res://runtime/world/world_state_manager.gd": "res://world/state/world_state_manager.gd",
		"res://runtime/simulation/simulation_runtime.gd": "res://gameplay/interaction/simulation_runtime.gd",
		"res://components/health_component.gd": "res://entities/components/health_component.gd",
		"res://components/combat_component.gd": "res://entities/components/combat_component.gd",
		"res://components/mana_component.gd": "res://entities/components/mana_component.gd",
		"res://components/stats_component.gd": "res://entities/components/stats_component.gd",
		"res://items/buff.gd": "res://gameplay/status/buff.gd",
		"res://items/buff_manager.gd": "res://gameplay/status/buff_manager.gd",
		"res://items/inventory.gd": "res://gameplay/inventory/inventory.gd",
		"res://items/equipment_manager.gd": "res://gameplay/inventory/equipment_manager.gd",
		"res://items/equipment_data.gd": "res://gameplay/inventory/data/equipment_data.gd",
		"res://items/item_data.gd": "res://gameplay/inventory/data/item_data.gd",
		"res://items/player_inventory.tres": "res://content/items/player_inventory.tres",
		"res://pickups/pickup.gd": "res://entities/pickups/pickup.gd",
		"res://pickups/health_pickup.gd": "res://entities/pickups/health_pickup.gd",
		"res://pickups/health_pickup.tscn": "res://entities/pickups/health_pickup.tscn",
		"res://pickups/mana_pickup.gd": "res://entities/pickups/mana_pickup.gd",
		"res://pickups/mana_pickup.tscn": "res://entities/pickups/mana_pickup.tscn",
		"res://skills/archetypes/linear_projectile.tscn": "res://gameplay/abilities/archetypes/linear_projectile.tscn",
		"res://skills/archetypes/persistent_aoe.gd": "res://gameplay/abilities/archetypes/persistent_aoe.gd",
		"res://skills/archetypes/persistent_aoe.tscn": "res://gameplay/abilities/archetypes/persistent_aoe.tscn",
		"res://skills/visuals/projectile_visual_data.gd": "res://gameplay/abilities/visuals/projectile_visual_data.gd",
		"res://skills/visuals/aoe_visual_data.gd": "res://gameplay/abilities/visuals/aoe_visual_data.gd",
		"res://skills/visuals/fire_visual.tres": "res://content/visuals/fire_visual.tres",
		"res://skills/visuals/shadow_visual.tres": "res://content/visuals/shadow_visual.tres",
		"res://skills/visuals/fire_aoe_visual.tres": "res://content/visuals/fire_aoe_visual.tres",
		"res://skills/visuals/ice_aoe_visual.tres": "res://content/visuals/ice_aoe_visual.tres",
		"res://runtime/world/interaction/surface_manager.gd": "res://gameplay/interaction/surface_manager.gd",
		"res://runtime/world/interaction/surface_reaction.gd": "res://gameplay/interaction/surface_reaction.gd",
		"res://world/portal.gd": "res://world/portals/portal.gd",
		"res://world/portal.tscn": "res://world/portals/portal.tscn",
		"res://world/portal_shape.tres": "res://world/portals/portal_shape.tres",
	}

	# Fix all .tscn and .tres files
	var files := _find_all_files("res://", [".tscn", ".tres"])
	var fixed := 0

	for file_path in files:
		if file_path.begins_with("res://.godot"):
			continue
		if file_path.begins_with("res://addons"):
			continue
		var f := FileAccess.open(file_path, FileAccess.READ)
		if not f:
			continue
		var text := f.get_as_text()
		f.close()
		var changed := false
		for old in path_map:
			if text.contains(old):
				text = text.replace(old, path_map[old])
				changed = true
		if changed:
			var out := FileAccess.open(file_path, FileAccess.WRITE)
			out.store_string(text)
			out.close()
			print("✅ ", file_path)
			fixed += 1

	print("\n=== Fixed %d files ===" % [fixed])


func _find_all_files(dir_path: String, extensions: Array) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			result.append_array(_find_all_files(full, extensions))
		else:
			for ext in extensions:
				if name.ends_with(ext):
					result.append(full)
					break
		name = dir.get_next()
	dir.list_dir_end()
	return result
