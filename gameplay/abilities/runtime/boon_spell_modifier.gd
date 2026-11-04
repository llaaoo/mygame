class_name BoonSpellModifier
extends RefCounted
## Pure cast-plan transformation. Spending is owned by the combination transaction.

static func plan(skill: SkillData, actor: Node2D, empower: bool) -> Dictionary:
	var result := {"skill": skill, "conditions": [] as Array[CastStatusRequirement], "retained": [], "spent": []}
	if skill.skill_type not in [SkillData.SkillType.PROJECTILE, SkillData.SkillType.AOE]:
		return result
	var manager := actor.get_node_or_null("BuffManager") as BuffManager
	if not manager:
		return result
	var copied := false
	for boon in manager.get_spell_boons():
		var matches := false
		for tag in boon.spell_tags:
			matches = matches or tag in skill.tags
		if not matches:
			continue
		var spend := empower and boon.can_empower
		result.conditions.append(CastStatusRequirement.new(boon.status_id, manager.status_version(boon.status_id), spend, boon.empower_mana_cost if spend else 0, boon.empower_damage_multiplier if spend else boon.spell_damage_multiplier))
		if spend:
			result.spent.append(boon.display_name)
		else:
			result.retained.append(boon.display_name)
		if not spend and is_equal_approx(boon.spell_damage_multiplier, 1.0):
			continue
		if not copied:
			result.skill = skill.create_runtime_variant()
			copied = true
		var modified: SkillData = result.skill
		var factor := boon.empower_damage_multiplier if spend else boon.spell_damage_multiplier
		modified.damage = int(round(modified.damage * factor))
		modified.damage_scaling *= factor
		if not spend:
			modified.mechanics += "\n保留%s：本次法术伤害 ×%.2f。" % [boon.display_name, factor]
			continue
		modified.display_name += "·" + boon.empower_name
		modified.description += "\n本次消耗%s，释放%s，随后失去其持续收益。" % [boon.display_name, boon.empower_name]
		modified.mechanics += "\n恩赐释放：伤害 ×%.2f，额外%d MP。" % [factor, boon.empower_mana_cost]
		modified.projectile_pierce += boon.empower_pierce_bonus
		modified.aoe_radius += boon.empower_radius_bonus
		if modified.aoe_visual:
			modified.aoe_visual.radius += boon.empower_radius_bonus
		if modified.skill_type == SkillData.SkillType.PROJECTILE and boon.empower_projectile_count > 0:
			modified.projectile_count += boon.empower_projectile_count - 1
			modified.projectile_spread_degrees = maxf(modified.projectile_spread_degrees, boon.empower_projectile_spread)
		if not boon.empower_surface.is_empty():
			if modified.skill_type == SkillData.SkillType.PROJECTILE:
				modified.impact_surface = boon.empower_surface
			else:
				modified.creates_surface = boon.empower_surface
			modified.surface_radius = maxf(modified.surface_radius, boon.empower_surface_radius)
			modified.surface_duration = maxf(modified.surface_duration if not skill.impact_surface.is_empty() or not skill.creates_surface.is_empty() else 0.0, boon.empower_surface_duration)
	return result
