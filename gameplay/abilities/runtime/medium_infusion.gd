class_name MediumInfusion
extends RefCounted
## A loadout capability, not another named spell or combination table.
## Planning only: the shared cast transaction reserves the selected charge.

static func plan(component: CastComponent, actor: Node2D, fields: Array[FireSigil], empower: bool) -> int:
	var skill := component.skill
	var medium := skill.creates_surface if not skill.creates_surface.is_empty() else skill.impact_surface
	if medium.is_empty():
		return 0
	var runtime := GameRuntime.instance
	var sim := runtime.get_simulation_runtime() if runtime else null
	var surfaces := sim.get_surface_manager() if sim else null
	if not surfaces:
		return 0
	var equipment := actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var cost := equipment.medium_infusion_cost() if equipment else -1
	if empower and cost >= 0 and component.field == null:
		var current := surfaces.project_state(medium, skill.surface_payload_tags)
		for i in range(fields.size() - 1, -1, -1):
			var field := fields[i]
			var tag: String = {"fire": "fire", "frost": "ice", "storm": "lightning"}.get(field.field_type, "")
			if tag.is_empty() or not field.is_available_to(actor) or surfaces.project_state(current, [tag]) == current:
				continue
			component.skill = skill.create_runtime_variant()
			component.skill.surface_payload_tags.append(tag)
			component.field = field
			component.version = field.revision
			component.anchor_to_field = false
			component.infusion_label = FireSigil.title_for(field.field_type) + "灌注（1次充能）"
			break
	component.medium_label = surfaces.describe_surface_path(medium, component.skill.surface_payload_tags)
	if not component.skill.surface_payload_tags.is_empty() and component.skill.aoe_visual:
		component.skill = component.skill.create_runtime_variant()
		var final_state := surfaces.project_state(medium, component.skill.surface_payload_tags)
		component.skill.aoe_visual.color = Color(SurfaceCatalog.color_for(final_state), 0.6)
	return cost if not component.infusion_label.is_empty() else 0
