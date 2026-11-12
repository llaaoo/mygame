extends "res://tests/test_ui_vertical_input.gd"
## Screenshot/layout contract for approved prototype. Real input, real domain data.
func assert_header(panel: Control,context := "") -> void:
 verify(panel!=null,"Prototype page did not open: "+context)
 if not panel: return
 if not root.get_visible_rect().encloses(panel.get_global_rect()):
  print("PARITY_LAYOUT ",panel.get_global_rect()," minimum ",panel.get_combined_minimum_size())
 verify(root.get_visible_rect().encloses(panel.get_global_rect()),"Prototype menu leaves viewport: "+context)
 var header:=panel.find_child("MenuHeader",true,false) as HBoxContainer
 verify(header!=null and header.size.y<80,"Shared single-row prototype header is missing or too tall")
 if not header: return
 for button in header.find_children("*","Button",true,false):
  if button.is_visible_in_tree():
   verify(panel.get_global_rect().encloses(button.get_global_rect()) and button.size.x>=40,"Header clips a navigation/return target: "+button.text)
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot()
 GameRuntime.instance.set_process(true)
 for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
 var store:=game.session.inventory
 store.receive("player","river_sabre",1)
 var weapon:=store.find_owned("player","river_sabre")
 store.receive("player","charcoal",6)
 store.receive_into("player.pocket","water_sprayer",2)
 store.set_properties(weapon,{"coating":{"id":"fire_rag","expires_at":store.clock_seconds+600}})
 var screen:=game.inventory_screen
 for extent in [Vector2i(960,720),Vector2i(1440,900)]:
  root.content_scale_size=extent; root.size=extent; GameUIStyle.set_text_scale(1.25,root); await frames(6)
  await tap(KEY_I); await select_item(weapon); await frames(8)
  assert_header(screen._panel)
  verify(screen._tiles[weapon]._title.get_theme_font("font") is FontVariation,"Inventory fell back to engine font instead of prototype Noto")
  var timer:=RegEx.new(); timer.compile("剩余([0-9]+)秒")
  var match_time:=timer.search(screen._state_label.text)
  var coating:=store.coating_state(weapon)
  var remaining: float=float(coating.get("expires_at",0))-store.clock_seconds
  verify(screen._state_label.visible and screen._state_label.text.begins_with(store.definitions.fire_rag.display_name) and match_time!=null and absf(float(match_time.get_string(1))-remaining)<=1,"Equipment detail lost exact coating identity or its live remaining time")
  var unchanged:=store.item(weapon).snapshot()
  await point_click(screen._sort.get_global_rect().get_center()); await tap(KEY_DOWN); await tap(KEY_DOWN); await tap(KEY_ENTER); await frames(8)
  verify(screen._sort.selected==1 and screen.selected==weapon and store.item(weapon).snapshot()==unchanged,"Sorting lost selected instance or changed inventory")
  await click("比较"); await frames(6)
  await capture("inventory-list-"+str(extent.x)+"-125")
  await point_click(screen._grid_toggle.get_global_rect().get_center()); await frames(8)
  verify(screen._grid_mode and screen.selected==weapon,"Grid view lost selected UID")
  await capture("inventory-grid-"+str(extent.x)+"-125")
  await point_click(screen._grid_toggle.get_global_rect().get_center()); await tap(KEY_ESCAPE)
  for code in [KEY_K,KEY_P,KEY_J,KEY_M,KEY_TAB]:
   await tap(code); await frames(12)
   var panel: Control=actor.skill_pool_ui._panel if code==KEY_K else game.ui._modal_panel
   assert_header(panel,str(code))
   var clock:=GameRuntime.instance.simulation_runtime.elapsed_time
   await frames(4)
   verify(not paused and actor.ui_blocked and GameRuntime.instance.simulation_runtime.elapsed_time>clock,"Shared page stopped the world")
   if code==KEY_K:
    verify(actor.skill_pool_ui._equip_slots.size()==13,"Prototype loadout lost independent binding slots")
    for tile in actor.skill_pool_ui._equip_slots:
     verify(panel.get_global_rect().encloses(tile.get_global_rect()),"Fixed binding row is not reachable")
   await capture("page-"+str(code)+"-"+str(extent.x)+"-125")
   await tap(KEY_ESCAPE); await frames(4)
   verify(not actor.ui_blocked,"Closing a shared page retained world input")
  var hud:=game.get_node("HUDLayer")
  verify(absf(hud.health_bar.get_global_rect().position.x-hud._actor_status.stamina_bar.get_global_rect().position.x)<1 and absf(hud.health_bar.size.x-hud._actor_status.stamina_bar.size.x)<1,"Resource tracks do not align across health and stamina")
  var quick:=hud.skill_bar.get_parent() as Control
  verify(absf(quick.get_global_rect().get_center().x-extent.x*.5)<=1,"13-slot bar is not centered on viewport")
  var targets: Array=hud.skill_bar._panels
  verify(targets.size()==13 and targets[12].get_global_rect().end.x<extent.x,"Shortcut targets leave viewport")
  await capture("hud-"+str(extent.x)+"-125")
  screen._view_context.clear()
 # Representative service/work layouts mount the existing presenter, then use real inputs.
 root.content_scale_size=Vector2i(1440,900); root.size=Vector2i(1440,900); await frames(6)
 actor.position=Vector2(-3100,1835); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 game.workshop.show_crafts(); await frames(10); assert_header(game.ui._modal_panel,"crafting")
 await capture("crafting-1440-125"); await tap(KEY_ESCAPE)
 var merchant:=game.session.actor_for_id(TownServices.MERCHANT) as ServiceNPC
 actor.position=merchant.position+Vector2(-35,0); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
 var reason:=game.town_services.reason()
 verify(reason.is_empty(),"Shop visual fixture could not open real service: "+reason)
 game.town_services.show(); await frames(10); assert_header(game.ui._modal_panel,"trade")
 await capture("trade-1440-125")
 if is_instance_valid(game.ui.modal): await tap(KEY_ESCAPE)
 GameUIStyle.set_text_scale(1.0,root); actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
 await tap(KEY_I); await select_item(weapon); await click("比较"); await frames(8)
 assert_header(screen._panel); await capture("inventory-list-1440-100"); await tap(KEY_ESCAPE)
 await capture("hud-1440-100")
 await fixture.close()
 var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
 if not output.is_empty():
  var file:=FileAccess.open(output.path_join("ui-prototype.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Controlled Godot scene, real keyboard/pointer, normal AI/time; service/crafting presenters mounted explicitly. No natural playthrough, commercial hardware or audio claim."},"  "))
 if failures.is_empty(): print("PASS prototype UI: %d checks; readable single-row headers, real instance sorting/grid/compare, fixed 13-slot binder, centered HUD, 6 live pages and real service/work layouts"%checks)
 quit(0 if failures.is_empty() else 1)
