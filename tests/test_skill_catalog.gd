extends SceneTree

const EXPECTED_SCHOOL_COUNTS := {
	SkillMastery.School.DESTRUCTION: 15,
	SkillMastery.School.CONJURATION: 3,
	SkillMastery.School.RESTORATION: 2,
	SkillMastery.School.ALTERATION: 7,
	SkillMastery.School.ILLUSION: 3,
}

const TREE_PATHS := {
	SkillMastery.School.DESTRUCTION: "res://gameplay/abilities/data/trees/destruction_tree.tres",
	SkillMastery.School.CONJURATION: "res://gameplay/abilities/data/trees/conjuration_tree.tres",
	SkillMastery.School.RESTORATION: "res://gameplay/abilities/data/trees/restoration_tree.tres",
	SkillMastery.School.ALTERATION: "res://gameplay/abilities/data/trees/alteration_tree.tres",
	SkillMastery.School.ILLUSION: "res://gameplay/abilities/data/trees/illusion_tree.tres",
}


func _init() -> void:
	if Player.PLAYER_SKILL_IDS.size() != 30:
		_fail("expected 30 player spells, got %d" % Player.PLAYER_SKILL_IDS.size())
		return
	if RunManager.SKILL_REWARD_IDS.size() != 30:
		_fail("run reward catalog does not contain 30 spells")
		return
	for reward_skill_id in RunManager.SKILL_REWARD_IDS:
		if reward_skill_id not in Player.PLAYER_SKILL_IDS:
			_fail("run reward catalog references unknown spell: %s" % reward_skill_id)
			return

	var ids: Dictionary = {}
	var icons: Dictionary = {}
	var synergy_ids: Dictionary = {}
	var school_counts: Dictionary = {}
	for skill_id in Player.PLAYER_SKILL_IDS:
		if ids.has(skill_id):
			_fail("duplicate spell id: %s" % skill_id)
			return
		ids[skill_id] = true
		var skill := load("res://gameplay/abilities/data/%s_data.tres" % skill_id) as SkillData
		if not skill or skill.get_id() != skill_id:
			_fail("spell failed to load: %s" % skill_id)
			return
		if skill.description.is_empty() or skill.mechanics.is_empty() or skill.role.is_empty():
			_fail("spell presentation data is incomplete: %s" % skill_id)
			return
		if skill.upgrades.size() < 3:
			_fail("spell needs at least three upgrade branches: %s" % skill_id)
			return
		if skill.icon_atlas_index < 0 or skill.icon_atlas_index >= 30 or icons.has(skill.icon_atlas_index):
			_fail("spell icon index is missing or duplicated: %s" % skill_id)
			return
		if not SkillIconCatalog.get_icon(skill):
			_fail("spell icon failed to resolve: %s" % skill_id)
			return
		icons[skill.icon_atlas_index] = true
		for synergy_resource in skill.synergies:
			var synergy := synergy_resource as SkillSynergyData
			if not synergy or synergy.id.is_empty() or synergy.description.is_empty():
				_fail("spell synergy configuration is incomplete: %s" % skill_id)
				return
			synergy_ids[synergy.id] = true
		school_counts[skill.school] = int(school_counts.get(skill.school, 0)) + 1
	for expected_synergy in ["melt", "steam_burst", "conduction", "toxic_ignition", "shadow_decay"]:
		if not synergy_ids.has(expected_synergy):
			_fail("spell catalog is missing synergy: %s" % expected_synergy)
			return

	for school in EXPECTED_SCHOOL_COUNTS:
		if int(school_counts.get(school, 0)) != int(EXPECTED_SCHOOL_COUNTS[school]):
			_fail("school %d has an unexpected spell count" % school)
			return
		var tree := load(TREE_PATHS[school]) as SkillTreeData
		if not tree or tree.tree_id.is_empty() or tree.display_name.is_empty():
			_fail("skill tree metadata is missing for school %d" % school)
			return
		if tree.skill_ids.size() != int(EXPECTED_SCHOOL_COUNTS[school]):
			_fail("skill tree catalog count mismatch for school %d" % school)
			return
		for skill_id in tree.skill_ids:
			if not ids.has(skill_id):
				_fail("skill tree references unknown spell: %s" % skill_id)
				return

	var volley := load("res://gameplay/abilities/data/cinder_volley_data.tres") as SkillData
	var volley_inst := SkillInstance.new(volley)
	if not volley_inst.apply_upgrade("multishot") or volley_inst.data.projectile_count != volley.projectile_count + 1:
		_fail("multishot upgrade did not alter projectile count")
		return
	var orb := load("res://gameplay/abilities/data/glacial_orb_data.tres") as SkillData
	var orb_inst := SkillInstance.new(orb)
	if not orb_inst.apply_upgrade("seeker") or orb_inst.data.homing_strength <= orb.homing_strength:
		_fail("seeker upgrade did not alter homing strength")
		return
	var pool := load("res://gameplay/abilities/data/magma_pool_data.tres") as SkillData
	var pool_inst := SkillInstance.new(pool)
	if not pool_inst.apply_upgrade("pulse") or pool_inst.data.aoe_max_hits_per_target <= pool.aoe_max_hits_per_target:
		_fail("pulse upgrade did not alter AoE hit count")
		return

	print("Skill catalog tests passed: 30 spells, 5 trees, 30 unique icons")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
