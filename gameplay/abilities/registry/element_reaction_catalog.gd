class_name ElementReactionCatalog
extends RefCounted
## Element properties travel with spells, material variants and imbued attacks.
const RULE_IDS := ["melt", "vaporize", "toxic_ignition", "deep_freeze", "conduction", "static_overload", "steam_burst", "shadow_decay", "shatter"]
static var _rules: Array[SkillSynergyData] = []

static func all_rules() -> Array[SkillSynergyData]:
	if _rules.is_empty():
		for id in RULE_IDS:
			_rules.append(load("res://gameplay/abilities/data/synergies/%s.tres" % id) as SkillSynergyData)
	return _rules.duplicate()

static func for_skill(skill: SkillData) -> Array[SkillSynergyData]:
	var result: Array[SkillSynergyData] = []
	var seen: Dictionary = {}
	var candidates: Array = skill.synergies.duplicate()
	candidates.append_array(all_rules())
	for resource in candidates:
		var rule := resource as SkillSynergyData
		if not rule or seen.has(rule.id):
			continue
		var matching := rule.required_hit_tags.is_empty()
		for tag in rule.required_hit_tags:
			matching = matching or tag in skill.tags
		if matching:
			result.append(rule)
			seen[rule.id] = true
	return result
