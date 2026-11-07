extends "res://tests/support/input_scene_probe.gd"
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var casts:=0
func card(title: String) -> void:
	var found: Control
	for label in game.player.skill_pool_ui._skill_grid.find_children("*","Label",true,false):
		if label.text==title: found=label; break
	check(found!=null,"Missing binder item: "+title)
	if not found: return
	var parent:=found.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(found)
		parent=parent.get_parent()
	await frames(); await point_click(found.get_global_rect().get_center())
func slot(source: String) -> void:
	var pool:=game.player.skill_pool_ui
	var panel:=pool._equip_slots[pool._equip_sources.find(source)]
	var parent:=panel.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(panel)
		parent=parent.get_parent()
	await frames(); await point_click(panel.get_global_rect().get_center())
func run() -> void:
	root.size=Vector2i(960,600)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	var actor:=game.player
	var manager:=actor.skill_manager
	var store:=game.session.inventory
	var supplies:=manager.combinations.supplies
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	actor.position=Vector2(-3500,2000); actor.get_node("Camera2D").reset_smoothing()
	game.progress.actions.merge({"fire_sigil":true,"frost_sigil":true,"water_call":true},true)
	game._apply_knowledge()
	manager.cast_committed.connect(func(_plan): casts+=1)
	manager.equip_source("quick_e",manager.pool.get_skill("ignite"))
	supplies.grant({"ration":2,"clean_water":1})
	await key(KEY_K,true); await key(KEY_K,false)
	await click("可用物品"); await card(supplies.title("ration")); await slot("slot_0")
	check(manager.shortcuts.binding("slot_0").get("item_id")=="ration" and manager.get_instance("quick_e")!=null,"Actual mouse binding did not keep E skill and 1 item independent")
	game.progress.actions["pulse"]=true; game._apply_knowledge()
	check(manager.shortcuts.binding("slot_0").get("item_id")=="ration","Learning a skill overwrote an occupied item shortcut")
	await capture("mixed-shortcut-binder")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	var mana:=actor.mana_component.mp
	await key(KEY_E,true); await key(KEY_E,false); await frames(40)
	check(casts==1 and actor.mana_component.mp==mana-4 and supplies.count("ration")==2,"E executed the 1 item or failed its own spell")
	await key(KEY_1,true); await key(KEY_1,false)
	check(actor.field_work.is_busy() and casts==1,"1 failed to use bound food or triggered E")
	await create_timer(1.7).timeout
	check(supplies.count("ration")==1 and actor.mana_component.mp==mana-4,"Food shortcut charged wrong resource/count")
	actor.field_work.close_panel()
	var fast_casts:=casts
	var fast:=InputEventKey.new(); fast.keycode=KEY_R; fast.physical_keycode=KEY_R; fast.pressed=true
	Input.parse_input_event(fast); fast=fast.duplicate(); fast.pressed=false; Input.parse_input_event(fast); Input.flush_buffered_events()
	await frames(40)
	check(casts==fast_casts+1 and actor.mana_component.mp==mana-8,"A complete tap in one input frame duplicated or swallowed a quick cast")
	# Equipment shortcuts refer to the chosen UID and share ordinary equipment restrictions.
	store.receive("player","river_sabre",1)
	var weapon:=store.find_owned("player","river_sabre")
	manager.shortcuts.bind_item("left","river_sabre",weapon)
	await key(KEY_Q,true); await key(KEY_Q,false)
	check(str(store.equipped("player").get(str(EquipmentData.SlotType.RIGHT_HAND),""))==weapon,"Q did not equip its bound real weapon")
	store.receive("player","river_spear",1)
	var spear:=store.find_owned("player","river_spear")
	manager.shortcuts.bind_item("left","river_spear",spear)
	var enemy:=game.active_enemies[0]
	var enemy_position:=enemy.position; enemy.position=actor.position+Vector2(400,0)
	await key(KEY_Q,true); await key(KEY_Q,false)
	check(str(store.equipped("player").get(str(EquipmentData.SlotType.RIGHT_HAND),""))==weapon,"Quickslot bypassed nearby-hostile equipment restriction")
	enemy.position=enemy_position
	# Two copies of one operation use different explicit media without mutating M.
	supplies.grant({"fire_stone":1,"frost_salt":1})
	var rune:=manager.pool.get_skill("inscribe")
	manager.equip_source("left",rune,{"payload":"ember","modifier":"","uid":""})
	manager.equip_source("quick_e",rune,{"payload":"frost","modifier":"","uid":""})
	supplies.select_payload(rune,"arcane",manager); supplies.configure_modifier(rune,"ash")
	var before_binding:=manager.shortcuts.binding("quick_e")
	check(not manager.equip_source("quick_e",rune,{"payload":"unknown_source"}) and manager.shortcuts.binding("quick_e")==before_binding,"Invalid fixed source changed an existing binding")
	var global_choice:=supplies.selected.duplicate(true)
	mana=actor.mana_component.mp
	var fire_cost:=manager.preview_source("left").cost
	var frost_cost:=manager.preview_source("quick_e").cost
	check(manager.preview_source("left").skill.field_type=="fire" and manager.preview_source("quick_e").skill.field_type=="frost","Source previews ignore per-slot media")
	await key(KEY_Q,true); await key(KEY_Q,false); await frames(60)
	check(manager.combinations.fields.any(func(field): return is_instance_valid(field) and field.field_type=="fire") and supplies.count("fire_stone")==0,"Q fixed fire rune failed to place/pay")
	var after_fire:=actor.mana_component.mp
	await key(KEY_E,true); await key(KEY_E,false)
	check(supplies.count("frost_salt")==1 and actor.mana_component.mp==after_fire,"Two slots bypassed a shared operation cooldown")
	await create_timer(rune.cooldown+.4).timeout
	await key(KEY_E,true); await key(KEY_E,false); await frames(60)
	check(manager.combinations.fields.any(func(field): return is_instance_valid(field) and field.field_type=="frost") and supplies.count("frost_salt")==0,"E fixed frost rune failed to place/pay")
	check(actor.mana_component.mp==mana-fire_cost-frost_cost and supplies.selected==global_choice,"Pinned media changed global M selection or paid hidden modifiers")
	# Rebinding the held throw cancels the original preparation, never uses the replacement.
	supplies.grant({"oil_bottle":2})
	manager.shortcuts.bind_item("slot_1","oil_bottle")
	var throw_mana:=actor.mana_component.mp
	await key(KEY_2,true)
	check(actor.actor_context.item_actions.aiming and supplies.count("oil_bottle")==2,"Held shortcut spent a bottle before release")
	await key(KEY_2,false); await create_timer(1.1).timeout
	check(supplies.count("oil_bottle")==1 and actor.mana_component.mp==throw_mana,"Throw shortcut release did not commit exactly one physical bottle")
	await key(KEY_2,true)
	check(actor.actor_context.item_actions.aiming and supplies.count("oil_bottle")==1,"Item shortcut failed held throw aiming")
	root.focus_exited.emit()
	check(not actor.actor_context.item_actions.busy(),"Window focus loss confirmed or retained a keyboard throw")
	await key(KEY_2,false)
	check(supplies.count("oil_bottle")==1,"Focus-loss release consumed an unthrown bottle")
	await key(KEY_2,true)
	manager.shortcuts.bind_item("slot_1","ration")
	check(not actor.actor_context.item_actions.busy(),"Changing a held shortcut did not cancel original item aim")
	await key(KEY_2,false); await frames(40)
	check(supplies.count("oil_bottle")==1 and supplies.count("ration")==1 and not actor.field_work.is_busy(),"Stale release spent throw or used replacement food")
	# A specific one-dose bottle must stop while its key is held; spare bottle stays full.
	supplies.grant({"venom_sprayer":2})
	var bottle:=store.ready_uid("player","venom_sprayer")
	store.spend_instance("player",bottle,"doses",2)
	var spare: String=""
	for row in store.entries("player.pocket"):
		if row.definition=="venom_sprayer" and row.uid!=bottle: spare=row.uid
	manager.shortcuts.bind_item("slot_3","venom_sprayer",bottle)
	await key(KEY_4,true); await create_timer(.9).timeout
	check(not actor.actor_context.spray.active and store.item(bottle)==null and store.item(spare).properties.doses==3,"Bound half bottle silently changed to a full spare or failed payment")
	await create_timer(.7).timeout
	check(store.item(spare).properties.doses==3,"Holding an exhausted bottle shortcut restarted spraying")
	await key(KEY_4,false)
	# A coat is an item, not a new spell. It modifies the actual equipped UID.
	supplies.grant({"fire_rag":1})
	manager.shortcuts.bind_item("slot_4","fire_rag")
	await key(KEY_5,true); await key(KEY_5,false); await create_timer(1.4).timeout
	check(supplies.count("fire_rag")==0 and store.item(weapon).properties.get("coating",{}).get("id")=="fire_rag","Item shortcut failed concrete weapon coating")
	# Utility keys use the same model and may carry skills too.
	manager.equip_source("item_0",manager.pool.get_skill("ignite"))
	var before_casts:=casts
	await key(KEY_7,true); await key(KEY_7,false); await frames(25)
	check(casts==before_casts+1 and supplies.count("ration")==1,"7 remained item-only or used the old independent belt")
	manager.shortcuts.clear("item_2")
	var bindings:=manager.serialize_skill_state()
	var inventory:=store.snapshot()
	game._save_progress()
	await capture("mixed-shortcut-world")
	await fixture.close()
	game=await fixture.boot(true)
	check(game.player.skill_manager.serialize_skill_state()==bindings,"Restart lost mixed bindings, fixed payloads, stale UID or cleared utility slot")
	check(game.session.inventory.snapshot()==inventory,"Restart refilled items or changed their UIDs/remaining properties")
	check(game.player.skill_manager.combinations.fields.is_empty() and not game.player.actor_context.spray.active and not game.player.actor_context.item_actions.busy(),"Restart restored transient fields or held actions")
	check(not game.session.snapshot().has("belt"),"New save still writes a second binding authority")
	await fixture.close()
	# Real v6 file: import old skill slots and separate belt once, without duplicating stock.
	var legacy:=SaveRepository.new().read("user://save_3.sav").data.duplicate(true)
	legacy.version=6
	var expedition: Dictionary=legacy.extensions.grayriver_frontier
	expedition.loadout={"left":{"skill_id":"inscribe","upgrades":{}},"right":{"skill_id":"ignite","upgrades":{}},"slot_0":{"skill_id":"ignite","upgrades":{}},"__configured":{}}
	expedition.foundation.erase("shortcut_schema")
	expedition.foundation.belt=[{"id":"oil_bottle","method":"throw"},{"id":"clean_water","method":"use"},{"id":"tea","method":"use"},{"id":"broth","method":"use"}]
	var legacy_inventory: Dictionary=expedition.foundation.inventory.duplicate(true)
	var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE); file.store_var(legacy,false); file.close()
	game=await fixture.boot(true)
	check(game.player.skill_manager.get_instance("quick_e")==null and game.player.skill_manager.get_instance("slot_0").data.get_id()=="ignite","v6 loadout invented an E copy or changed numeric skills")
	check(game.player.skill_manager.shortcuts.binding("item_0").get("item_id")=="oil_bottle" and game.session.inventory.snapshot()==legacy_inventory,"v6 belt import lost binding or regenerated stock")
	game.player.skill_manager.shortcuts.clear("item_0")
	game._save_progress(); await fixture.close()
	game=await fixture.boot(true)
	check(game.player.skill_manager.shortcuts.binding("item_0").is_empty(),"Legacy belt reimported after player cleared a migrated slot")
	check(SaveRepository.new().read("user://save_3.sav").data.version==7,"Mixed shortcuts did not upgrade the real save version")
	await fixture.close()
	if failures.is_empty(): print("PASS unified quickslots: real E skill/1 food, UID equipment policy, independent rune media/shared cooldown, stale throw release, half-bottle stop, coating, 7 skill and persisted mixed bindings")
	quit(0 if failures.is_empty() else 1)
