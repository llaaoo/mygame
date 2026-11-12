extends "res://tests/support/input_scene_probe.gd"
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
## Real menu input in an explicit inventory fixture, with normal AI/simulation.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var casts:=0
func select_skill(id: String) -> void:
 var data:=game.player.skill_manager.pool.get_skill(id)
 var label: Label
 for node in game.player.skill_pool_ui._skill_grid.find_children("*","Label",true,false):
  if node.text==data.display_name: label=node; break
 check(label!=null,"Missing learned skill card: "+id)
 if label: await point_click(label.get_global_rect().get_center())
func select_item(uid: String) -> void:
 var tile:=game.inventory_screen._tiles.get(uid) as Control
 check(tile!=null,"Missing real UID tile: "+uid)
 if not tile: return
 (game.inventory_screen._grid.get_parent() as ScrollContainer).ensure_control_visible(tile)
 await frames(); await point_click(tile.get_global_rect().get_center())
func right_click(point: Vector2) -> void:
 var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
 root.push_input(motion,true); await frames()
 var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_RIGHT; event.pressed=true
 root.push_input(event,true); await frames()
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames()
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 game.player.skill_manager.cast_committed.connect(func(_plan): casts+=1)
 # Explicit discovery/grants exercise real UI ownership, not a natural new-game reward path.
 game.progress_service.discover(game.catalog.fact("river.handbook").definition)
 game.survival.supplies.grant({"ration":3,"charcoal":3})
 game.session.inventory.receive("player","river_sabre",1)
 var store:=game.session.inventory
 var weapon:=store.find_owned("player","river_sabre")
 var food:=store.ready_uid("player","ration")
 var actor:=game.player; var manager:=actor.skill_manager
 for resolution in [Vector2i(1152,648),Vector2i(960,540),Vector2i(1280,720)]:
  root.size=resolution; await frames(8)
  await key(KEY_I,true); await key(KEY_I,false)
  var screen:=game.inventory_screen
  check(screen.visible and screen._navigation.visible and root.get_visible_rect().encloses(screen._panel.get_global_rect()),"Inventory chrome outside viewport: "+str(resolution))
  await select_item(food); await frames(8)
  await capture("inventory-"+str(resolution.x))
  await click_identity({"ui_action":"menu_route","page":"loadout"}); await frames(8)
  var pool:=actor.skill_pool_ui
  check(pool.visible and pool._navigation.visible and root.get_visible_rect().encloses(pool._panel.get_global_rect()),"Shared navigation failed to reach loadout")
  var last:=pool._equip_slots.back() as Control
  var ancestor:=last.get_parent()
  while ancestor and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
  var slots:=ancestor as ScrollContainer
  slots.ensure_control_visible(last); await frames()
  check(slots.get_global_rect().encloses(last.get_global_rect()),"Last shortcut cannot be reached at "+str(resolution))
  await capture("loadout-"+str(resolution.x))
  await click_identity({"ui_action":"menu_route","page":"quests"}); await frames(8)
  check(is_instance_valid(game.ui.modal) and game.hub.page=="quests" and root.get_visible_rect().encloses(game.ui._modal_panel.get_global_rect()),"Journal chrome outside viewport")
  await capture("journal-"+str(resolution.x))
  await click_identity({"ui_action":"menu_route","page":"map"}); await frames(8)
  check(root.get_visible_rect().encloses(game.ui._modal_panel.get_global_rect()),"Map chrome outside viewport")
  var map: GrayriverMap
  for node in game.ui.modal.find_children("*","Control",true,false):
   if node is GrayriverMap: map=node
  check(map!=null and root.get_visible_rect().encloses(map.get_global_rect()),"Map canvas cropped outside viewport")
  for node in game.ui.modal.find_children("*","Button",true,false):
   if node.text in ["定位当前位置","清除路标"]: check(root.get_visible_rect().encloses(node.get_global_rect()),"Map action cropped below screen")
  await capture("map-"+str(resolution.x))
  await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
  check(not paused and not actor.ui_blocked,"Navigation close did not return to live world")
 root.size=Vector2i(1152,648); await frames(8)
 await key(KEY_I,true); await key(KEY_I,false); await select_item(food)
 var screen:=game.inventory_screen
 await click("绑定快捷槽"); await frames(4)
 await point_click(screen._binding_host.get_node("QuickBind/Bind_quick_e").get_global_rect().get_center()); await frames(8)
 check(manager.shortcuts.binding("quick_e").get("item_id","")=="ration","Direct item shortcut binding failed")
 await select_item(weapon)
 await click("装备这件"); await frames(8)
 check(weapon in store.equipped("player").values(),"Mouse equipment did not update physical portrait UID")
 await click("绑定快捷槽"); await frames(4)
 await point_click(screen._binding_host.get_node("QuickBind/Bind_slot_0").get_global_rect().get_center()); await frames(8)
 check(manager.shortcuts.binding("slot_0").get("uid","")==weapon and manager.shortcuts.binding("quick_e").get("item_id","")=="ration","E/1 item binding collided or lost UID")
 await capture("quick-bind")
 await select_item(food)
 await point_click(screen._search.get_global_rect().get_center())
 await key(KEY_NONE,true,"烤".unicode_at(0)); await key(KEY_NONE,false)
 await key(KEY_E,true,101); await key(KEY_E,false)
 check(screen.visible and screen._search.text=="烤e" and casts==0,"Search typing navigated or cast an action")
 await key(KEY_M,true,109);await key(KEY_M,false)
 check(screen.visible and screen._search.text=="烤em" and not is_instance_valid(game.ui.modal),"Typing M in inventory search opened the map")
 await click_identity({"ui_action":"menu_route","page":"quests"}); await click_identity({"ui_action":"menu_route","page":"inventory"}); await frames(8)
 check(screen.visible and screen.selected==food and screen._search.text=="烤em","Navigation discarded search/selected UID context")
 await click_identity({"ui_action":"menu_route","page":"loadout"}); await select_skill("ignite")
 var before_stock:=store.material_amounts("player")
 await key(KEY_E,true); await key(KEY_E,false)
 check(manager.shortcuts.binding("quick_e").get("skill_id","")=="ignite" and manager.shortcuts.binding("slot_0").get("uid","")==weapon,"Keyboard binding failed or overwrote another slot")
 var retained:=manager.shortcuts.snapshot()
 await key(KEY_1,true); await key(KEY_1,false)
 check(manager.shortcuts.snapshot()==retained,"No selection silently rebound a shortcut")
 await select_skill("water_call"); await key(KEY_1,true); await key(KEY_1,false)
 check(manager.shortcuts.binding("slot_0").get("skill_id","")=="water_call" and manager.shortcuts.binding("quick_e").get("skill_id","")=="ignite" and casts==0 and store.material_amounts("player")==before_stock,"Menu keyboard binding cast/consumed or merged E and 1")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var hud:=get_first_node_in_group("hud_ui")
 var sequence:=actor.actor_context.actions._attack_sequence
 await point_click(hud.skill_bar._panels[hud.skill_bar._sources.find("quick_e")].get_global_rect().get_center())
 check(actor.material_wheel.visible and actor.material_wheel.source=="quick_e","HUD slot did not open exact source selection")
 var wheel:=actor.material_wheel
 var source_button: Button
 for node in wheel._source_list.get_children():
  if node is Button and node.text.begins_with("1 "): source_button=node
 check(source_button!=null,"Wheel lacks mouse-accessible source buttons")
 if source_button: await point_click(source_button.get_global_rect().get_center())
 check(wheel.visible and wheel.source=="slot_0" and actor.actor_context.actions._attack_sequence==sequence and casts==0,"Source list click closed wheel or leaked world attack/cast")
 check(not wheel.selector_rect().intersects(wheel._detail_host.get_global_rect()),"Wheel detail overlaps a radial choice")
 await capture("mouse-source-wheel")
 var clock:=GameRuntime.instance.simulation_runtime.elapsed_time
 await frames(25)
 check(GameRuntime.instance.simulation_runtime.elapsed_time>clock and not paused,"Preparation UI stopped simulation")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var facing:=actor.actor_context.actions.facing
 await right_click(hud.skill_bar._panels[hud.skill_bar._sources.find("quick_e")].get_global_rect().get_center())
 check(wheel.visible and wheel.source=="quick_e" and wheel.opening_direction.is_equal_approx(facing) and not actor.actor_context.actions.guarding and casts==0,"HUD right-click lost defensive direction, stuck guard or cast")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 root.size=Vector2i(960,540); await frames(10)
 check(not hud.get_node("MarginContainer/HUDRoot/StatusPanel").get_global_rect().intersects(hud.skill_bar.get_parent().get_global_rect()),"Resources and combat shortcuts overlap at 960px")
 await capture("world-960")
 var saved:=manager.shortcuts.snapshot(); game._save_progress(); await fixture.close()
 game=await fixture.boot(true)
 check(game.player.skill_manager.shortcuts.snapshot()==saved and game.session.inventory.item(weapon)!=null and weapon in game.session.inventory.equipped("player").values(),"Reload lost UI-created bindings or real UID")
 await fixture.close()
 if failures.is_empty(): print("PASS interface navigation: five shared routes/three viewports, reachable final slot, direct item UID binding, E/1 keyboard binding without casts, retained context, exact HUD source, mouse wheel source selection, live time, no HUD overlap and disk restoration")
 quit(0 if failures.is_empty() else 1)
