extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot(true)
	_check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var service := game.equipment_service
	var player := game.player
	var manager: EquipmentManager = player.get_node("EquipmentManager")
	var sm := player.skill_manager
	var controller := sm.combinations
	var buffs: BuffManager = player.get_node("BuffManager")
	_check(not service.equip("keeper_ring"), "Unowned equipment could be equipped")
	var original_hp := player.health_component.max_hp
	var grant: ExplorationDiscoveryData
	for entry in game.catalog.regions.archive.discoveries:
		if entry.id == "pulse_knowledge": grant = entry
	game._change_region("archive")
	_check(game.progress_service.discover(grant) and game.progress.equipment_owned.get("keeper_ring", false), "Discovery did not grant fixed equipment")
	var ring: EquipmentData = game.catalog.equipment.keeper_ring
	_check(player.inventory.get_item_count(ring) == 1, "Fixed reward did not use the existing inventory")
	_check(not game.progress_service.discover(grant) and player.inventory.get_item_count(ring) == 1, "Repeated discovery duplicated equipment")
	_check(not service.equip("keeper_ring"), "Equipment changed outside camp")
	game._change_region("camp")
	player.global_position = Vector2(12000, 12000)
	_check(service.equip("keeper_ring") and manager.get_equipment(ring.slot_type) == ring and player.inventory.get_item_count(ring) == 0, "Equipment service did not move ownership between backpack/loadout")
	sm.restrict_actions = false
	sm.equip_slot(0, sm.pool.get_skill("fire_sigil"))
	var plan := controller.preview(sm.get_slot(0).data, player)
	_check(plan.placement_radius == 120 and plan.placement_duration == 21 and plan.cost == 9, "Keeper ring did not change field parameters/cost tradeoff")
	_check(sm.use_slot(0, player, Vector2.RIGHT), "Equipment field preparation failed")
	controller.tick(1)
	_check(controller.field.radius == 120 and controller.field.remaining == 21, "Actual field disagreed with equipment preview")
	service.show_detail("keeper_ring")
	_check(is_instance_valid(game.ui.modal) and not paused and game.player.ui_blocked, "Equipment comparison panel did not open")
	game.ui.close_modal()

	# Test authored loadout choices and cap reduction using real profile resources.
	for id in game.catalog.equipment:
		game.progress.equipment_owned[id] = true
	controller.clear_field()
	_check(service.equip("soul_amulet"), "Soul amulet rejected")
	var soul_skill := sm.pool.get_skill("soul_harvest")
	for i in range(6): buffs.apply_buff(soul_skill.buff_resource, player, soul_skill)
	_check(buffs.get_stack_count("soul_charge") == 5 and buffs.stack_limit(soul_skill.buff_resource) == 5 and player.health_component.max_hp == original_hp - 15, "Soul amulet capacity/life tradeoff incorrect")
	var source := SoulRemnant.new()
	game.region_root.add_child(source)
	source.global_position = player.global_position + Vector2(190, 0)
	buffs.consume_status("soul_charge", 1)
	_check(controller.preview(soul_skill, player).ready, "Soul amulet range did not reach the remnant")
	_check(service.unequip(EquipmentData.SlotType.AMULET), "Amulet unequip failed")
	_check(buffs.get_stack_count("soul_charge") == 3 and buffs.stack_limit(soul_skill.buff_resource) == 3 and not controller.preview(soul_skill, player).ready and player.health_component.max_hp == original_hp, "Unequip did not clamp capacity or remove range/life changes")

	_check(service.equip("covenant_ring") and manager.get_equipment(EquipmentData.SlotType.RING).id == "covenant_ring" and player.inventory.get_item_count(ring) == 1, "Same-slot artifacts stacked or displaced item was lost")
	var ember := sm.pool.get_skill("ember_focus")
	if not ember: ember = load("res://gameplay/abilities/data/ember_focus_result.tres")
	var context := CastContext.simple(player, Vector2.RIGHT, ember)
	_check(sm.executor.execute(ember, context), "Boon cast for equipment test failed")
	_check(is_equal_approx(buffs.capture_status("ember_focus").remaining, 7.5), "Covenant ring did not shorten newly gained releasable boon")
	buffs.remove_status("soul_charge")
	sm.equip_slot(1, sm.pool.get_skill("ignite"))
	var retained := controller.preview(sm.get_slot(1).data, player)
	var released := controller.preview(sm.get_slot(1).data, player, true)
	_check(retained.cost == 4 and released.cost == 9 and released.skill.damage > retained.skill.damage and released.consumed_boons.has("余烬战意"), "Covenant ring did not apply its explicit release cost/damage tradeoff")
	_check(service.equip("cadence_gloves"), "Cadence gloves rejected")
	var quick := controller.preview(sm.get_slot(0).data, player)
	_check(is_equal_approx(quick.preparation, 0.64) and quick.cost == 9, "Cadence preparation/cost did not use shared planning")
	controller.reset_session()
	_check(sm.use_slot(0, player, Vector2.RIGHT), "Swap-interruption preparation failed")
	var mp := player.mana_component.mp
	_check(service.equip("keeper_ring"), "Camp swap failed")
	controller.tick(1)
	_check(controller.pending.is_empty() and controller.field == null and player.mana_component.mp == mp, "Equipment swap changed a prepared cast silently or charged it")

	# Existing inventory UI must enforce the same camp restriction.
	game._change_region("archive")
	var inventory_ui := player.inventory_panel
	var slot_item := manager.get_equipment(EquipmentData.SlotType.RING)
	inventory_ui._on_equip_clicked(EquipmentData.SlotType.RING)
	_check(manager.get_equipment(EquipmentData.SlotType.RING) == slot_item, "Inventory UI bypassed camp equipment boundary")
	game._change_region("camp")
	_check(service.equip("soul_amulet") and service.equip("covenant_ring"), "Final saved build rejected")
	_check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Build save failed")
	var saved := SaveManager.instance.read_extension(MVPGame.SAVE_SLOT, MVPGame.SECTION)
	_check(saved.equipment_owned.size() == 4 and saved.equipment_loadout.get(str(EquipmentData.SlotType.RING)) == "covenant_ring", "Build ownership/loadout was not persisted")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	player = game.player
	manager = player.get_node("EquipmentManager")
	_check(manager.get_equipment(EquipmentData.SlotType.RING).id == "covenant_ring" and manager.get_equipment(EquipmentData.SlotType.AMULET).id == "soul_amulet" and player.health_component.max_hp == original_hp - 15, "Fresh scene did not restore the authored build without attribute drift")
	_check(player.inventory.get_item_count(game.catalog.equipment.keeper_ring) == 1 and player.inventory.get_item_count(game.catalog.equipment.covenant_ring) == 0, "Restored build duplicated or lost backpack items")
	var old := ExplorationProgress.new()
	old.deserialize_save_data({"claims": {"pulse_knowledge": true}})
	_check(old.equipment_owned.is_empty() and old.equipment_loadout.is_empty(), "Legacy missing equipment fields did not default safely")
	game.progress = old
	game.equipment_service.restore()
	_check(game.progress.equipment_owned.get("keeper_ring", false) and manager.get_all_equipped().is_empty(), "Previously claimed discovery did not gain its new artifact safely")
	await fixture.close()
	if failures.is_empty(): print("Expedition builds passed: fixed rewards/inventory, camp policy, field/boon/soul profiles, swap cancellation and fresh disk restore")
	quit(0 if failures.is_empty() else 1)
