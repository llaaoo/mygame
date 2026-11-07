@tool
extends EditorScript

## 用 FileAccess 逐文件复制内容到新位置

func _run() -> void:
	var moves := [
		# core/
		["res://runtime/game_runtime.gd", "res://core/game_runtime.gd"],
		["res://runtime/command_bus.gd", "res://core/command/command_bus.gd"],
		["res://runtime/runtime_command.gd", "res://core/command/runtime_command.gd"],
		["res://runtime/combat/combat_event.gd", "res://core/event/combat_event.gd"],
		["res://runtime/combat/combat_event_bus.gd", "res://core/event/combat_event_bus.gd"],
		["res://runtime/combat/combat_scope.gd", "res://core/event/combat_scope.gd"],
		["res://runtime/combat/state.gd", "res://core/state/state.gd"],
		["res://runtime/combat/state_machine.gd", "res://core/state/state_machine.gd"],
		["res://runtime/combat/input_setup.gd", "res://core/input_setup.gd"],
		["res://runtime/combat/debug/combat_debugger.gd", "res://core/debug/combat_debugger.gd"],
		["res://runtime/combat/debug/combat_debug_ui.gd", "res://core/debug/combat_debug_ui.gd"],
		["res://runtime/combat/debug/combat_trace.gd", "res://core/debug/combat_trace.gd"],
		["res://runtime/combat/debug/combat_trace_event.gd", "res://core/debug/combat_trace_event.gd"],
		# gameplay/combat/
		["res://runtime/combat/combat_executor.gd", "res://gameplay/combat/combat_executor.gd"],
		["res://runtime/combat/combat_phase.gd", "res://gameplay/combat/combat_phase.gd"],
		["res://runtime/combat/triggered_effect.gd", "res://gameplay/combat/triggered_effect.gd"],
		["res://runtime/combat/on_hit_apply_status.gd", "res://gameplay/combat/on_hit/on_hit_apply_status.gd"],
		["res://runtime/combat/on_hit_fire_bonus.gd", "res://gameplay/combat/on_hit/on_hit_fire_bonus.gd"],
		["res://runtime/combat/on_kill_bonus_exp.gd", "res://gameplay/combat/on_kill/on_kill_bonus_exp.gd"],
		["res://runtime/combat/on_ice_armor_expire.gd", "res://gameplay/combat/on_armor/on_ice_armor_expire.gd"],
		["res://runtime/combat/conditions/condition.gd", "res://gameplay/combat/conditions/condition.gd"],
		["res://runtime/combat/conditions/buff_name_condition.gd", "res://gameplay/combat/conditions/buff_name_condition.gd"],
		["res://runtime/combat/conditions/low_hp_condition.gd", "res://gameplay/combat/conditions/low_hp_condition.gd"],
		["res://runtime/combat/conditions/skill_tag_condition.gd", "res://gameplay/combat/conditions/skill_tag_condition.gd"],
		["res://runtime/combat/conditions/status_condition.gd", "res://gameplay/combat/conditions/status_condition.gd"],
		["res://runtime/combat/conditions/tag_condition.gd", "res://gameplay/combat/conditions/tag_condition.gd"],
		["res://runtime/combat/conditions/target_type_condition.gd", "res://gameplay/combat/conditions/target_type_condition.gd"],
		["res://runtime/combat/skills/modifiers/damage_modifier.gd", "res://gameplay/combat/modifiers/damage_modifier.gd"],
		["res://runtime/combat/skills/modifiers/flat_bonus_modifier.gd", "res://gameplay/combat/modifiers/flat_bonus_modifier.gd"],
		["res://runtime/combat/skills/modifiers/stat_scaling_modifier.gd", "res://gameplay/combat/modifiers/stat_scaling_modifier.gd"],
		["res://runtime/combat/skills/modifiers/tag_multiplier_modifier.gd", "res://gameplay/combat/modifiers/tag_multiplier_modifier.gd"],
		# gameplay/abilities/
		["res://runtime/combat/skills/data/skill_data.gd", "res://gameplay/abilities/data/skill_data.gd"],
		["res://runtime/combat/skills/data/burning.tres", "res://gameplay/abilities/data/burning.tres"],
		["res://runtime/combat/skills/data/fireball_data.tres", "res://gameplay/abilities/data/fireball_data.tres"],
		["res://runtime/combat/skills/data/flame_storm_data.tres", "res://gameplay/abilities/data/flame_storm_data.tres"],
		["res://runtime/combat/skills/data/frozen.tres", "res://gameplay/abilities/data/frozen.tres"],
		["res://runtime/combat/skills/data/ice_armor_buff.tres", "res://gameplay/abilities/data/ice_armor_buff.tres"],
		["res://runtime/combat/skills/data/ice_armor_data.tres", "res://gameplay/abilities/data/ice_armor_data.tres"],
		["res://runtime/combat/skills/data/ice_explosion_data.tres", "res://gameplay/abilities/data/ice_explosion_data.tres"],
		["res://runtime/combat/skills/data/poison.tres", "res://gameplay/abilities/data/poison.tres"],
		["res://runtime/combat/skills/data/shadow_bolt_data.tres", "res://gameplay/abilities/data/shadow_bolt_data.tres"],
		["res://runtime/combat/skills/data/shadow_step_buff.tres", "res://gameplay/abilities/data/shadow_step_buff.tres"],
		["res://runtime/combat/skills/data/shadow_step_data.tres", "res://gameplay/abilities/data/shadow_step_data.tres"],
		["res://runtime/combat/skills/data/wet.tres", "res://gameplay/abilities/data/wet.tres"],
		["res://runtime/combat/skills/runtime/cast_context.gd", "res://gameplay/abilities/runtime/cast_context.gd"],
		["res://runtime/combat/skills/runtime/damage_context.gd", "res://gameplay/abilities/runtime/damage_context.gd"],
		["res://runtime/combat/skills/runtime/projectile.gd", "res://gameplay/abilities/runtime/projectile.gd"],
		["res://runtime/combat/skills/runtime/skill_executor.gd", "res://gameplay/abilities/runtime/skill_executor.gd"],
		["res://runtime/combat/skills/runtime/skill_instance.gd", "res://gameplay/abilities/runtime/skill_instance.gd"],
		["res://runtime/combat/skills/manager/skill_manager.gd", "res://gameplay/abilities/manager/skill_manager.gd"],
		["res://runtime/combat/skills/registry/skill_pool.gd", "res://gameplay/abilities/registry/skill_pool.gd"],
		["res://runtime/combat/skills/registry/player_skill_pool.tres", "res://gameplay/abilities/registry/player_skill_pool.tres"],
		["res://runtime/combat/skills/loadout/skill_loadout.gd", "res://gameplay/abilities/loadout/skill_loadout.gd"],
		["res://runtime/combat/skills/loadout/default_loadout.tres", "res://gameplay/abilities/loadout/default_loadout.tres"],
		["res://runtime/combat/effect_graph/effect_graph.gd", "res://gameplay/abilities/effect_graph/effect_graph.gd"],
		["res://runtime/combat/effect_graph/effect_node.gd", "res://gameplay/abilities/effect_graph/effect_node.gd"],
		["res://runtime/combat/effect_graph/effect_graph_context.gd", "res://gameplay/abilities/effect_graph/effect_graph_context.gd"],
		["res://runtime/combat/effect_graph/branch_node.gd", "res://gameplay/abilities/effect_graph/branch_node.gd"],
		["res://runtime/combat/effect_graph/callable_node.gd", "res://gameplay/abilities/effect_graph/callable_node.gd"],
		["res://runtime/combat/effect_graph/condition_gate_node.gd", "res://gameplay/abilities/effect_graph/condition_gate_node.gd"],
		["res://runtime/combat/effect_graph/empty_node.gd", "res://gameplay/abilities/effect_graph/empty_node.gd"],
		["res://runtime/combat/effect_graph/log_node.gd", "res://gameplay/abilities/effect_graph/log_node.gd"],
		["res://runtime/combat/effect_graph/sequence_node.gd", "res://gameplay/abilities/effect_graph/sequence_node.gd"],
		["res://skills/archetypes/linear_projectile.tscn", "res://gameplay/abilities/archetypes/linear_projectile.tscn"],
		["res://skills/archetypes/persistent_aoe.gd", "res://gameplay/abilities/archetypes/persistent_aoe.gd"],
		["res://skills/archetypes/persistent_aoe.tscn", "res://gameplay/abilities/archetypes/persistent_aoe.tscn"],
		["res://skills/visuals/projectile_visual_data.gd", "res://gameplay/abilities/visuals/projectile_visual_data.gd"],
		["res://skills/visuals/aoe_visual_data.gd", "res://gameplay/abilities/visuals/aoe_visual_data.gd"],
		["res://skills/visuals/fire_visual.tres", "res://content/visuals/fire_visual.tres"],
		["res://skills/visuals/shadow_visual.tres", "res://content/visuals/shadow_visual.tres"],
		["res://skills/visuals/fire_aoe_visual.tres", "res://content/visuals/fire_aoe_visual.tres"],
		["res://skills/visuals/ice_aoe_visual.tres", "res://content/visuals/ice_aoe_visual.tres"],
		# gameplay/interaction/
		["res://runtime/world/interaction/reaction_rule.gd", "res://gameplay/interaction/reaction_rule.gd"],
		["res://runtime/world/interaction/surface_data.gd", "res://gameplay/interaction/surface_data.gd"],
		["res://runtime/world/interaction/surface_manager.gd", "res://gameplay/interaction/surface_manager.gd"],
		["res://runtime/world/interaction/surface_reaction.gd", "res://gameplay/interaction/surface_reaction.gd"],
		["res://runtime/simulation/simulation_runtime.gd", "res://gameplay/interaction/simulation_runtime.gd"],
		["res://runtime/simulation/surface_scheduler.gd", "res://gameplay/interaction/surface_scheduler.gd"],
		["res://runtime/simulation/propagation_scheduler.gd", "res://gameplay/interaction/propagation_scheduler.gd"],
		["res://runtime/simulation/respawn_scheduler.gd", "res://gameplay/interaction/respawn_scheduler.gd"],
		# world/
		["res://runtime/world/world_runtime.gd", "res://world/world_runtime.gd"],
		["res://runtime/world/world_spatial_index.gd", "res://world/spatial/world_spatial_index.gd"],
		["res://runtime/world/world_state_manager.gd", "res://world/state/world_state_manager.gd"],
		["res://world/portal.gd", "res://world/portals/portal.gd"],
		["res://world/portal.tscn", "res://world/portals/portal.tscn"],
		["res://world/portal_shape.tres", "res://world/portals/portal_shape.tres"],
		["res://maps/overworld.tscn", "res://world/maps/overworld.tscn"],
		# entities/components/
		["res://components/health_component.gd", "res://entities/components/health_component.gd"],
		["res://components/combat_component.gd", "res://entities/components/combat_component.gd"],
		["res://components/mana_component.gd", "res://entities/components/mana_component.gd"],
		["res://components/stats_component.gd", "res://entities/components/stats_component.gd"],
		# entities/pickups/
		["res://pickups/pickup.gd", "res://entities/pickups/pickup.gd"],
		["res://pickups/health_pickup.gd", "res://entities/pickups/health_pickup.gd"],
		["res://pickups/health_pickup.tscn", "res://entities/pickups/health_pickup.tscn"],
		["res://pickups/mana_pickup.gd", "res://entities/pickups/mana_pickup.gd"],
		["res://pickups/mana_pickup.tscn", "res://entities/pickups/mana_pickup.tscn"],
		["res://pickups/mana_pickup_shape.tres", "res://entities/pickups/mana_pickup_shape.tres"],
		# gameplay/status/
		["res://items/buff.gd", "res://gameplay/status/buff.gd"],
		["res://items/buff_manager.gd", "res://gameplay/status/buff_manager.gd"],
		# gameplay/inventory/
		["res://items/inventory.gd", "res://gameplay/inventory/inventory.gd"],
		["res://items/equipment_manager.gd", "res://gameplay/inventory/equipment_manager.gd"],
		["res://items/equipment_data.gd", "res://gameplay/inventory/data/equipment_data.gd"],
		["res://items/item_data.gd", "res://gameplay/inventory/data/item_data.gd"],
		# content/
		["res://items/player_inventory.tres", "res://content/items/player_inventory.tres"],
	]

	var ok := 0
	var fail := 0
	for pair in moves:
		var src: String = pair[0]
		var dst: String = pair[1]
		if not FileAccess.file_exists(src):
			printerr("MISS: ", src)
			fail += 1
			continue
		var f := FileAccess.open(src, FileAccess.READ)
		var content := f.get_as_text()
		f.close()
		var out := FileAccess.open(dst, FileAccess.WRITE)
		out.store_string(content)
		out.close()
		print("OK: %s → %s" % [src.get_file(), dst])
		ok += 1

	print("\n=== %d ok, %d fail ===" % [ok, fail])
