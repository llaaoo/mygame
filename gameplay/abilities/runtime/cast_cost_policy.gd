class_name CastCostPolicy
extends RefCounted
## One cost policy for ordinary actions and conditional results.

static func mana_cost(skill: SkillData, caster: Node, base_cost: int) -> int:
	return maxi(0, int(round(base_cost * mana_multiplier(skill, caster))))

static func mana_multiplier(skill: SkillData, caster: Node) -> float:
	var equipment := caster.get_node_or_null("EquipmentManager") as EquipmentManager
	var modifier := (equipment.get_modifier_value("mana_cost.all") if equipment else 0.0)+ActorProgression.modifier(caster,"mana_cost.all")
	for tag in skill.tags:
		modifier += (equipment.get_modifier_value("mana_cost.%s" % tag) if equipment else 0.0)+ActorProgression.modifier(caster,"mana_cost.%s"%tag)
	return maxf(0, 1.0 + modifier)

static func cooldown(skill: SkillData, caster: Node, base_duration: float) -> float:
	var modifier := 0.0
	var mastery: Node = caster.get("mastery_manager") if "mastery_manager" in caster else null
	if mastery:
		modifier += mastery.get_modifier_value("cooldown.%s" % skill.get_id())
		for tag in skill.tags:
			modifier += mastery.get_modifier_value("cooldown.%s" % tag)
	var equipment := caster.get_node_or_null("EquipmentManager") as EquipmentManager
	if equipment:
		modifier += equipment.get_modifier_value("cooldown.all")
		modifier += equipment.get_modifier_value("cooldown.%s" % skill.get_id())
		for tag in skill.tags:
			modifier += equipment.get_modifier_value("cooldown.%s" % tag)
	return maxf(0.1, base_duration * (1.0 + modifier))
