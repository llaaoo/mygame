extends SceneTree
const Fixture := preload("res://tests/support/grayriver_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message); push_error(message)
func frames(n := 4) -> void:
	for i in range(n): await process_frame
func find_enemy(game: GrayriverGame, id: String) -> Enemy:
	for enemy in game.active_enemies:
		if enemy.get_meta("frontier_claim","") == id: return enemy
	return null

func run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	var id := "river.enemy.camp.bridge_keeper"
	var guard := find_enemy(game,id)
	var gear := guard.get_node("EquipmentManager") as EquipmentManager
	var visual := guard.get_node("EquipmentVisual") as ActorEquipmentVisual
	check(guard.get_node("Sprite2D").self_modulate.a == 0,"Atlas still depicts unowned baked equipment")
	check(gear.get_all_equipped() == visual.items and gear.get_equipment(EquipmentData.SlotType.LEFT_HAND).id == "river_shield","Wearer appearance does not read its real equipment")
	# A changed runtime loadout must be recovered, not the original template.
	gear.equip(game.catalog.equipment.river_spear)
	check(visual.items.any(func(item): return item.id == "river_spear"),"Equipment swap did not update wearer appearance")
	var snapshot := GrayriverLoot.snapshot(guard)
	check(not snapshot.equipment.has("river_sabre") and snapshot.equipment.has("river_spear"),"Death snapshot was generated from a template")
	game.player.position = guard.position + Vector2(30,0)
	guard.take_damage(1000)
	await frames()
	check(game.progress.loot_records[id].equipment == snapshot.equipment and game.progress.loot_records[id].materials == snapshot.materials,"Death lost real carried contents")
	check(not game.region_root.get_children().any(func(node): return node is HealthPickup or node is ManaPickup),"Physical loot still created random restorative pickups")
	var corpse := game.loot.corpses[id] as GrayriverLootCorpse
	check(corpse.gear.items.size() == snapshot.equipment.size(),"Corpse does not show recoverable equipment")
	check("未取战利品" in game.presenter.journal_text() and "断桥守望者" in game.presenter.journal_text(),"Unclaimed corpse absent from the journey log")
	game.player.position += Vector2(500,0)
	check(game.loot.take(id) == 0,"Remote looting accepted")
	game.player.position = corpse.position
	# Capacity failures must leave exact remainders on the corpse.
	var inventory := game.player.inventory
	var blocker := ItemData.new()
	blocker.id = "loot_test_blocker"
	inventory.add_item(blocker,inventory.capacity)
	check(game.loot.take(id,"equipment","river_spear") == 0 and game.progress.loot_records[id].equipment.river_spear == 1,"Full inventory destroyed or duplicated equipment")
	var note: ExplorationDiscoveryData
	for entry in game.current_data.discoveries:
		if entry.id == "river.focus": note = entry
	check(game.progress_service.discover(note) and game.equipment_service.count("soul_amulet") == 0 and game.equipment_service.has_pending_rewards(note),"Full inventory lost a discovery's pending equipment")
	inventory.remove_item(blocker,1)
	check(game.loot.take(id,"equipment","river_spear") == 1 and game.equipment_service.count("river_spear") == 1,"Partial retrieval failed")
	check(not corpse.gear.items.any(func(item): return item.id == "river_spear") and not game.progress.loot_records[id].equipment.has("river_spear"),"Taken spear remains visible on the corpse")
	inventory.remove_item(blocker,inventory.capacity)
	check(game.progress_service.discover(note) and game.equipment_service.count("soul_amulet") == 1 and not game.equipment_service.has_pending_rewards(note),"Revisiting discovery did not deliver retained equipment")
	check(not game.progress_service.discover(note) and game.equipment_service.count("soul_amulet") == 1,"Discovery source awarded its equipment twice")
	var observed_totals: Array[int] = []
	var watch := func(): observed_totals.append(game.survival.supplies.count("charcoal")+int(game.progress.loot_records[id].materials.get("charcoal",0)))
	game.survival.supplies.changed.connect(watch)
	check(game.loot.take(id) > 0 and game.loot.take(id) == 0,"Repeat retrieval duplicated contents")
	game.survival.supplies.changed.disconnect(watch)
	check(observed_totals == [2],"Transfer published a duplicated source/destination balance before both sides committed")
	var hunter := find_enemy(game,"river.enemy.camp.forest.4")
	game.player.position = hunter.position
	hunter.take_damage(1000)
	await frames()
	var hunter_id := "river.enemy.camp.forest.4"
	game.survival.supplies.grant({"clean_water":SurvivalCatalog.WATER_CAPACITY})
	check(game.loot.take(hunter_id,"materials","clean_water") == 0 and game.progress.loot_records[hunter_id].materials.clean_water == 1,"Full waterskin lost remaining water")
	game.survival.supplies.pay({"clean_water":1})
	check(game.loot.take(hunter_id,"materials","clean_water") == 1,"Waterskin space did not permit later retrieval")
	# Used materials are absent; the gear is still present on a dead caster.
	var mage := find_enemy(game,"river.enemy.camp.road.2")
	var sm := mage.skill_manager
	sm.combinations.supplies.configure("focus","ward_powder")
	var source := mage.character_brain.find_source("focus")
	check(sm.use_source(source,mage,CastContext.simple(mage,Vector2.LEFT,sm.get_instance(source).data)),"Caster could not spend real carried powder")
	sm.combinations.tick(2)
	check(sm.combinations.supplies.count("ward_powder") == 0,"Caster never consumed its carried material")
	game.player.position = mage.position
	mage.take_damage(1000)
	await frames()
	var mage_id := "river.enemy.camp.road.2"
	check(not game.progress.loot_records[mage_id].materials.has("ward_powder") and game.progress.loot_records[mage_id].equipment.has("cadence_gloves"),"Spent materials refilled at death")
	# Identical copies are counted separately, including the equipped copy.
	var second := find_enemy(game,"river.enemy.camp.forest.3")
	game.player.position = second.position
	second.take_damage(1000)
	await frames()
	check(game.loot.take("river.enemy.camp.forest.3","equipment","river_coat") == 1 and game.equipment_service.count("river_coat") == 2,"Duplicate coats collapsed into one ownership flag")
	check(game.player.inventory_panel._can_change_equipment(),"Safe wilderness did not permit manual equipment changes")
	game.player.position = Vector2(-3500,2100)
	check(game.equipment_service.equip("river_coat") and game.player.inventory.get_item_count(game.catalog.equipment.river_coat) == 1,"Equipping erased a second copy")
	check((game.player.get_node("EquipmentVisual") as ActorEquipmentVisual).items.any(func(item): return item.id == "river_coat"),"Player does not show the recovered coat")
	var peer := load("res://entities/enemy/enemy.tscn").instantiate() as Enemy
	peer.character_definition = load("res://content/characters/explorer.tres")
	peer.rewards_enabled = false
	game.region_root.add_child(peer)
	peer.process_mode = Node.PROCESS_MODE_DISABLED
	(peer.get_node("EquipmentManager") as EquipmentManager).equip(game.catalog.equipment.river_coat)
	check(ActorCombatModel.incoming_damage(peer,25) == ActorCombatModel.incoming_damage(game.player,25),"Recovered armor uses different NPC/player reduction")
	var peer_hp := peer.health_component.hp
	var player_hp := game.player.health_component.hp
	peer.take_damage(25)
	game.player.take_damage(25)
	check(peer_hp-peer.health_component.hp == 23 and player_hp-game.player.health_component.hp == 23,"Actual damage path did not apply shared armor reduction")
	peer.queue_free()
	game._save_progress()
	var saved := game.progress.serialize_save_data()
	check(game.progress.validate_save_data(saved),"Loot save failed shape validation")
	var invalid := saved.duplicate(true)
	invalid.loot_records[id].equipment = {"unknown_gear":1}
	check(not game.progress.validate_save_data(invalid),"Unknown saved loot equipment accepted")
	invalid = saved.duplicate(true)
	invalid.equipment_counts.river_coat = -1
	check(not game.progress.validate_save_data(invalid),"Negative owned quantity accepted")
	var before: Dictionary = saved.loot_records.duplicate(true)
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.progress.loot_records == before and game.equipment_service.count("river_coat") == 2,"Cold load lost exact corpse remainders or duplicate equipment")
	check(game.loot.corpses.has(id) and find_enemy(game,id) == null,"Load resurrected the owner or discarded the corpse")
	check((game.player.get_node("EquipmentManager") as EquipmentManager).get_equipment(EquipmentData.SlotType.CHEST).id == "river_coat","Recovered equipment loadout did not restore")
	# Death and regional travel preserve unclaimed contents.
	game.player.health_component.hp = 1
	game.player.health_component.invincible = false
	game.player.take_damage(1000)
	await fixture.travel("camp")
	check(game.progress.loot_records == before,"Player death erased or refilled corpses")
	await fixture.travel("river_mine")
	await fixture.travel("camp")
	check(game.progress.loot_records == before,"Regional travel changed corpse contents")
	game.replay_encounters()
	await frames(10)
	fixture.freeze_enemies()
	guard = find_enemy(game,id)
	check(guard != null and not guard.rewards_enabled,"Reset encounters do not preserve no-reward policy")
	guard.take_damage(1000)
	await frames()
	check(game.progress.loot_records == before,"Rehearsal minted new loot or refilled an emptied corpse")
	var old := ExplorationProgress.new()
	old.deserialize_save_data({"equipment_owned":{"keeper_ring":true}})
	check(old.equipment_counts.get("keeper_ring") == 1 and old.loot_records.is_empty(),"Legacy ownership did not migrate without fabricated corpses")
	await fixture.close()
	if errors.is_empty(): print("Grayriver loot passed: actual equipment appearance, runtime snapshot, real consumption, capacity remainders, duplicate copies, armor parity, cold save/load, death, regional travel and reset protection")
	quit(0 if errors.is_empty() else 1)
