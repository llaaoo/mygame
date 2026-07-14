extends SceneTree

const SKILL_IDS: Array[String] = [
	"fireball", "ice_armor", "flame_storm", "shadow_step", "ice_explosion",
	"poison_cloud", "lightning_bolt", "summon_skeleton", "charged_fireball",
	"ice_storm", "shadow_bolt", "frost_lance", "ember_orb", "storm_field",
	"venom_burst", "arcane_dash", "cinder_volley", "solar_spear", "magma_pool",
	"glacial_orb", "blizzard", "thunder_orb", "static_nova", "plague_bolt",
	"miasma_ring", "tidal_orb", "phase_blink", "summon_wisp", "summon_golem",
	"radiant_aegis",
]


func _init() -> void:
	var fireball := load("res://gameplay/abilities/data/fireball_data.tres") as SkillData
	if not fireball or fireball.upgrades.size() < 3:
		_fail("fireball upgrade configuration is missing")
		return
	var original_damage := fireball.damage
	var original_cooldown := fireball.cooldown
	var original_scale := fireball.visual.scale
	var inst := SkillInstance.new(fireball)
	if not inst.apply_upgrade("power") or not inst.apply_upgrade("power"):
		_fail("stacked power upgrade failed")
		return
	var expected_damage := int(round(original_damage * pow(1.2, 2)))
	if inst.data.damage != expected_damage:
		_fail("power upgrade produced incorrect damage")
		return
	if fireball.damage != original_damage or not is_equal_approx(fireball.visual.scale, original_scale):
		_fail("runtime upgrade mutated the shared fireball resource")
		return
	for i in range(3):
		if not inst.apply_upgrade("cadence"):
			_fail("cadence rank %d failed" % (i + 1))
			return
	if inst.apply_upgrade("cadence") or inst.data.cooldown >= original_cooldown:
		_fail("cadence max rank or cooldown scaling failed")
		return

	var saved := inst.serialize_state()
	var restored := SkillInstance.new(fireball)
	restored.restore_upgrades(saved.get("upgrades", {}))
	if restored.upgrade_ranks != inst.upgrade_ranks or restored.data.damage != inst.data.damage:
		_fail("skill upgrade state did not restore")
		return

	var pool := SkillPool.new()
	pool.add_skill(fireball)
	var manager := SkillManager.new()
	manager._slots.resize(SkillManager.MAX_SLOTS)
	manager.pool = pool
	manager.equip_slot(0, fireball)
	manager.upgrade_source("slot_0", "power")
	var manager_state := manager.serialize_skill_state()
	var restored_manager := SkillManager.new()
	restored_manager._slots.resize(SkillManager.MAX_SLOTS)
	restored_manager.pool = pool
	restored_manager.restore_skill_state(manager_state)
	if restored_manager.get_slot(0).get_upgrade_rank("power") != 1:
		_fail("skill manager did not restore per-slot upgrades")
		return

	var storm := load("res://gameplay/abilities/data/storm_field_data.tres") as SkillData
	var storm_radius := storm.aoe_visual.radius
	var storm_inst := SkillInstance.new(storm)
	storm_inst.apply_upgrade("area")
	if storm_inst.data.aoe_visual.radius <= storm_radius or not is_equal_approx(storm.aoe_visual.radius, storm_radius):
		_fail("AoE upgrade did not isolate visual data")
		return

	var summon := load("res://gameplay/abilities/data/summon_skeleton_data.tres") as SkillData
	var summon_hp := summon.summon_data.max_hp
	var summon_inst := SkillInstance.new(summon)
	summon_inst.apply_upgrade("command")
	if summon_inst.data.summon_data.max_hp <= summon_hp or summon.summon_data.max_hp != summon_hp:
		_fail("summon upgrade did not isolate summon data")
		return

	for skill_id in SKILL_IDS:
		var skill := load("res://gameplay/abilities/data/%s_data.tres" % skill_id) as SkillData
		if not skill or skill.get_id() != skill_id:
			_fail("skill resource failed to load: %s" % skill_id)
			return
		if skill.upgrades.size() < 3:
			_fail("skill has fewer than three upgrade directions: %s" % skill_id)
			return

	manager.free()
	restored_manager.free()
	print("Skill upgrade tests passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
