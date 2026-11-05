class_name BoonSpellModifier
extends RefCounted
## Pure cast-plan transformation. Spending is owned by the combination transaction.

static func plan(skill: SkillData, actor: Node2D, empower: bool) -> Dictionary:
	var result := {"skill": skill, "conditions": [] as Array[CastStatusRequirement], "retained": [], "spent": [], "partial": []}
	if skill.skill_type not in [SkillData.SkillType.PROJECTILE, SkillData.SkillType.AOE]:
		return result
	var manager := actor.get_node_or_null("BuffManager") as BuffManager
	if not manager:
		return result
	var equipment := actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var partial_cost := equipment.partial_boon_cost() if equipment else -1
	var copied := false
	var families := ElementCatalog.family_ids(skill.tags)
	for boon in manager.get_spell_boons():
		var matches := false
		for tag in boon.spell_tags:
			matches = matches or tag in skill.tags
		for family in boon.spell_elements:
			matches = matches or family in families
		if not matches:
			continue
		var spend := empower and boon.can_empower
		# Utility spells must gain an applicable shape/medium effect before spending a boon.
		var deals_damage := skill.damage > 0 or skill.damage_scaling > 0
		var changes_shape := (skill.skill_type == SkillData.SkillType.AOE and not is_zero_approx(boon.empower_radius_bonus)) or (skill.skill_type == SkillData.SkillType.PROJECTILE and (boon.empower_pierce_bonus > 0 or boon.empower_projectile_count > 1))
		var retains_defense := not spend and (boon.damage_taken_multiplier != 1.0 or not boon.status_immunities.is_empty())
		if not deals_damage and not retains_defense and not (spend and (changes_shape or not boon.empower_surface.is_empty())):
			continue
		var partial := spend and partial_cost >= 0
		var factor := maxf(0.1, (boon.spell_damage_multiplier if partial else boon.empower_damage_multiplier) + (equipment.casting_value("empower_damage_bonus") if equipment else 0.0)) if spend else boon.spell_damage_multiplier
		var cost := maxi(0, boon.empower_mana_cost + int(equipment.casting_value("empower_mana_bonus") if equipment else 0) + (partial_cost if partial else 0)) if spend else 0
		var requirement := CastStatusRequirement.new(boon.status_id, manager.status_version(boon.status_id), spend, cost, factor)
		if partial: requirement.mode = CastStatusRequirement.ConsumptionMode.HALF_LIFETIME
		result.conditions.append(requirement)
		if partial:
			result.partial.append(boon.display_name)
		elif spend:
			result.spent.append(boon.display_name)
		else:
			result.retained.append(boon.display_name)
		if not spend and is_equal_approx(boon.spell_damage_multiplier, 1.0):
			continue
		if not copied:
			result.skill = skill.create_runtime_variant()
			copied = true
		var modified: SkillData = result.skill
		modified.damage = int(round(modified.damage * factor))
		modified.damage_scaling *= factor
		if not spend:
			modified.mechanics += "\n保留%s：本次法术伤害 ×%.2f。" % [boon.display_name, factor]
			continue
		modified.display_name += "·" + boon.empower_name
		modified.description += "\n部分消费%s：保留当前剩余时长的一半，形态强化保留，伤害采用保留倍率。" % boon.display_name if partial else "\n完整消耗%s，释放%s，随后失去其持续收益。" % [boon.display_name, boon.empower_name]
		modified.mechanics += "\n恩赐释放：%s，额外%d MP。" % [("伤害 ×%.2f" % factor if deals_damage else "工具形态强化，无直接伤害"), cost]
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
