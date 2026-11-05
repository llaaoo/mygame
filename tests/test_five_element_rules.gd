extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []

class Target extends Node2D:
	var health: HealthComponent
	func take_damage(amount: int) -> void: health.take_damage(amount)

func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	GameRuntime.instance.set_process(false)
	var sim := GameRuntime.instance.get_simulation_runtime()
	var surfaces := sim.get_surface_manager()
	var target := Target.new()
	target.health = HealthComponent.new()
	target.health.name = "HealthComponent"
	target.health.max_hp = 10000
	target.health.hp = 10000
	target.health.regen_rate = 0
	target.add_child(target.health)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	game.region_root.add_child(target)
	target.global_position = Vector2(20000, 20000)
	check(ElementCatalog.all_definitions().size() == 4 and not ElementCatalog.is_element("aoe") and ElementCatalog.is_element("shadow"), "Core elements swallowed behavior tags or legacy elements")
	check(ElementCatalog.all_aspects().size() == 1 and not ElementCatalog.is_core_element("ice") and ElementCatalog.is_element("ice"), "Frost was not retained as a compatible form rather than a base element")
	check(ElementCatalog.family_id("ice") == "water" and ElementCatalog.family_definition("ice") == ElementCatalog.definition("water") and ElementCatalog.family_ids(["water", "ice", "aoe"]) == ["water"], "Water/frost did not share one deduplicated affinity")
	check(ElementCatalog.definition("ice").hit_status_paths == ["res://gameplay/abilities/data/frozen.tres"] and ElementCatalog.definition("water").hit_status_paths == ["res://gameplay/abilities/data/wet.tres"], "Family merge flattened the distinct liquid and frost effects")
	check(SurfaceCatalog.all_reactions().size() == 16 and surfaces.project_state("wet", ["ice", "impact", "lightning"]) == "electrified", "Surface resource migration changed the shared transition chain")
	target.add_to_group("fire_immune")
	target.add_to_group("player")
	target.add_to_group("enemy")
	var cell := SurfaceManager.cell_at(target.global_position)
	for state in ["wet", "frozen", "poisoned", "electrified"]:
		buffs.clear_all()
		surfaces.force_set_surface(cell, state, 10)
		surfaces.tick_entity_surface()
		check(not buffs.get_active_statuses().is_empty(), "Fire immunity incorrectly blocked " + state)
	buffs.clear_all()
	surfaces.force_set_surface(cell, "burning", 10)
	surfaces.tick_entity_surface()
	check(not buffs.has_buff("burning") and not ElementCatalog.can_affect(target, "burning"), "Fire status immunity was not shared across entrypoints")
	target.remove_from_group("fire_immune")
	# Adjacent clean water cannot wash poison from an actor whose actual cell is toxic.
	target.global_position = Vector2(cell * 64) + Vector2(63.9, 32)
	surfaces.force_set_surface(cell, "poisoned", 10)
	surfaces.force_set_surface(cell + Vector2i.RIGHT, "wet", 10)
	surfaces.tick_entity_surface()
	check(buffs.has_buff("poison") and not buffs.has_buff("wet"), "Exposure leaked across cell boundaries")
	target.global_position.x += 0.2
	surfaces.tick_entity_surface()
	check(not buffs.has_buff("poison") and buffs.has_buff("wet"), "Crossing the boundary did not enter clean water")
	buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	surfaces.force_set_surface(SurfaceManager.cell_at(target.global_position), "electrified", 10)
	surfaces.tick_entity_surface()
	check(buffs.has_buff("wet") and buffs.has_buff("shocked") and buffs.has_buff("poison"), "Conductive water lost moisture or accidentally cleansed poison")
	buffs.clear_all()
	surfaces.force_set_surface(SurfaceManager.cell_at(target.global_position), "steam", 10)
	surfaces.tick_entity_surface()
	buffs.tick(1)
	surfaces.tick_entity_surface()
	check(is_equal_approx(buffs.capture_status("steam_veil").remaining, 2) and is_equal_approx(buffs.get_speed_multiplier(), .85), "Steam did not refresh defense or preserve slowdown")
	var projectile := SkillData.new()
	projectile.tags = ["lightning", "projectile"]
	projectile.skill_type = SkillData.SkillType.PROJECTILE
	buffs.apply_buff(load("res://gameplay/abilities/data/wet.tres"))
	target.remove_from_group("player")
	target.remove_from_group("enemy")
	var before := target.health.hp
	var hit := CombatExecutor.report_hit(game.player, target, 400, target.global_position, projectile, projectile.tags)
	check(hit.damage_dealt == 435 and before - target.health.hp == 435, "Steam did not mitigate base and conduction bonus exactly once")
	for delivery in ["melee", "aoe", "dot"]:
		target.health.invincible = false
		var skill := SkillData.new()
		skill.skill_type = SkillData.SkillType.AOE if delivery == "aoe" else SkillData.SkillType.PROJECTILE
		hit = CombatExecutor.report_hit(game.player, target, 100, target.global_position, null if delivery == "melee" else skill, [delivery])
		check(hit.damage_dealt == 100, "Steam incorrectly protected " + delivery)
	# Imbued melee carries a synthetic SkillData whose legacy default type is PROJECTILE.
	# Its actual melee delivery must still bypass projectile-only protection.
	buffs.remove_status("wet")
	buffs.remove_status("frozen")
	buffs.remove_status("poison")
	target.health.invincible = false
	var ember := game.player.skill_manager.pool.get_skill("ember_focus")
	(game.player.get_node("BuffManager") as BuffManager).apply_buff(ember.buff_resource)
	before = target.health.hp
	var melee_damage := game.player.combat_component.attack_damage
	game.player.combat_component._apply_melee_hit(target)
	check(before - target.health.hp == melee_damage, "Steam incorrectly mitigated actual elemental melee")
	var validator := ExplorationContentValidator.new()
	check(validator.validate(game.catalog).is_empty(), "Current migrated catalogs are invalid")
	var definition := ElementCatalog.all_definitions()[0]
	var id := definition.id
	definition.id = "invalid_element"
	check("Unknown/duplicate core element" in "\n".join(validator.validate(game.catalog)), "Unknown elements were not rejected")
	definition.id = id
	var aspect := ElementCatalog.definition("ice")
	var parent := aspect.parent_id
	aspect.parent_id = "unknown_element"
	check("Invalid element aspect parent" in "\n".join(validator.validate(game.catalog)), "Unknown form parent was accepted")
	aspect.parent_id = parent
	var rule := SurfaceCatalog.all_reactions()[0]
	var old := rule.required_tags.duplicate()
	rule.required_tags = ["invalid_element"]
	check("Unknown surface reaction tag" in "\n".join(validator.validate(game.catalog)), "Unknown surface tags were not rejected")
	rule.required_tags.assign(old)
	var old_path := rule.entity_status_path
	rule.entity_status_path = "res://missing_status.tres"
	check("Unknown reaction entity status" in "\n".join(validator.validate(game.catalog)), "Unknown reaction status reference was accepted")
	rule.entity_status_path = old_path
	await fixture.close()
	if errors.is_empty(): print("Element family rules passed: catalogs, immunity, exact exposure, conductive moisture, steam and scoped mitigation")
	quit(0 if errors.is_empty() else 1)
