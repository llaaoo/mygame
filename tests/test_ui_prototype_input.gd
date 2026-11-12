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
 for extent in [Vector2i(960,540),Vector2i(960,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  var size_tag:=str(extent.x)+("-540" if extent.y==540 else "")+"-125"
  root.content_scale_size=extent; root.size=extent; GameUIStyle.set_text_scale(1.25,root); await frames(6)
  await tap(KEY_I); await select_item(weapon); await frames(8)
  assert_header(screen._panel)
  var panes: Array[Control]=[screen._gear_scroll,screen._bag,screen._detail_column]
  for index in range(panes.size()):
   verify(panes[index].size.x>=180 and panes[index].size.x<=screen._columns.size.x*.52,"Inventory pane is cramped or dominates its neighbors: "+str(extent))
   if index>0: verify(panes[index].global_position.x>=panes[index-1].get_global_rect().end.x+8,"Inventory columns lost their breathing room")
  verify(screen._panel.size.x<=1600,"Wide-screen menu stretches beyond a readable working area")
  if extent.x>=1440:
   var head:=screen._portrait.slots[EquipmentData.SlotType.HEAD]
   var chest:=screen._portrait.slots[EquipmentData.SlotType.CHEST]
   verify(absf(head.global_position.y-chest.global_position.y)<1 and head.get_global_rect().end.x<chest.global_position.x,"Wide gear list wastes height instead of pairing readable equipment slots")
  verify(is_instance_valid(screen._item_art) and screen._item_art.item_id==store.item(weapon).definition_id and screen._item_art.get_meta("item_uid")==weapon and screen._item_art.size.y>=96 and screen._item_art.texture!=null,"Selected item has no dedicated, correctly sourced artwork area")
  var visible_words:=screen._panel.find_children("*","Label",true,false).filter(func(n): return n.is_visible_in_tree()).map(func(n): return n.text)
  verify(visible_words.all(func(t):return not t.contains("世界继续运行") and not t.contains("世界持续运行") and not t.contains("只读装备定义")),"Inventory repeats simulation/developer instructions instead of showing the traveler’s belongings")
  verify(screen._tiles[weapon]._title.get_theme_font("font") is FontVariation,"Inventory fell back to engine font instead of prototype Noto")
  var timer:=RegEx.new(); timer.compile("剩余([0-9]+)秒")
  var match_time:=timer.search(screen._state_label.text)
  var coating:=store.coating_state(weapon)
  var remaining: float=float(coating.get("expires_at",0))-store.clock_seconds
  verify(screen._state_label.visible and screen._state_label.text.begins_with(store.definitions.fire_rag.display_name) and match_time!=null and absf(float(match_time.get_string(1))-remaining)<=1,"Equipment detail lost exact coating identity or its live remaining time")
  var unchanged:=store.item(weapon).snapshot()
  if screen._sort.is_visible_in_tree():
   await point_click(screen._sort.get_global_rect().get_center()); await tap(KEY_DOWN); await tap(KEY_DOWN); await tap(KEY_ENTER); await frames(8)
   verify(screen._sort.selected==1 and screen.selected==weapon and store.item(weapon).snapshot()==unchanged,"Sorting lost selected instance or changed inventory")
  await capture("item-layout-"+size_tag)
  await click("比较"); await frames(6)
  var compared:=screen._details.find_child("EquipmentComparison",true,false) as Control
  verify(compared!=null and compared.global_position.y>=screen._detail_scroll.global_position.y-1 and compared.global_position.y<screen._detail_scroll.get_global_rect().end.y,"Compare opens below the reading viewport instead of revealing its heading")
  await capture("inventory-list-"+size_tag)
  await point_click(screen._grid_toggle.get_global_rect().get_center()); await frames(8)
  verify(screen._grid_mode and screen.selected==weapon,"Grid view lost selected UID")
  await capture("inventory-grid-"+size_tag)
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
    var first: Rect2=actor.skill_pool_ui._equip_slots.front().get_global_rect()
    var last: Rect2=actor.skill_pool_ui._equip_slots.back().get_global_rect()
    verify(absf((first.position.x+last.end.x)*.5-panel.get_global_rect().get_center().x)<2,"Loadout binding row is visually off-center")
   elif code==KEY_P:
    var views:=panel.find_children("*","Control",true,false).filter(func(n): return n is CharacterProgressionScreen)
    verify(views.size()==1,"Progression layout fixture is missing")
    if views.size()==1:
     var view:=views[0] as CharacterProgressionScreen
     verify(view._branch_scroll.size.x>=180 and view._detail_scroll.size.x>=260,"Progression navigation or reading area is too narrow")
     var bounds:=Rect2()
     for node in view._perk_buttons.values():
      bounds=node.get_rect() if bounds.size==Vector2.ZERO else bounds.merge(node.get_rect())
     verify(absf(bounds.get_center().x-view._canvas.size.x*.5)<2,"Perk graph is stranded at the edge of its canvas")
   await capture("page-"+str(code)+"-"+size_tag)
   await tap(KEY_ESCAPE); await frames(4)
   verify(not actor.ui_blocked,"Closing a shared page retained world input")
  var hud:=game.get_node("HUDLayer")
  verify(absf(hud.health_bar.get_global_rect().position.x-hud._actor_status.stamina_bar.get_global_rect().position.x)<1 and absf(hud.health_bar.size.x-hud._actor_status.stamina_bar.size.x)<1,"Resource tracks do not align across health and stamina")
  var quick:=hud.skill_bar.get_parent() as Control
  verify(absf(quick.get_global_rect().get_center().x-extent.x*.5)<=1,"13-slot bar is not centered on viewport")
  var targets: Array=hud.skill_bar._panels
  verify(targets.size()==13 and targets[12].get_global_rect().end.x<extent.x,"Shortcut targets leave viewport")
  await capture("hud-"+size_tag)
  screen._view_context.clear()
 # Representative service/work layouts mount the existing presenter, then use real inputs.
 root.content_scale_size=Vector2i(1440,900); root.size=Vector2i(1440,900); await frames(6)
 actor.position=Vector2(-3100,1835); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 for extent in [Vector2i(960,540),Vector2i(1440,900)]:
  root.content_scale_size=extent; root.size=extent; await frames(6)
  game.workshop.show_crafts(); await frames(10); assert_header(game.ui._modal_panel,"crafting")
  var folios:=game.ui._modal_panel.find_children("*","Control",true,false).filter(func(n):return n is ExpeditionScreen)
  verify(folios.size()==1 and folios[0].get_node("Navigation").size.x>=176,"Workshop description is squeezed into a sliver")
  await capture("crafting-"+str(extent.x)+"-125"); await tap(KEY_ESCAPE)
 root.content_scale_size=Vector2i(1440,900); root.size=Vector2i(1440,900); await frames(6)
 var merchant:=game.session.actor_for_id(TownServices.MERCHANT) as ServiceNPC
 actor.position=merchant.position+Vector2(-35,0); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
 var reason:=game.town_services.reason()
 verify(reason.is_empty(),"Shop visual fixture could not open real service: "+reason)
 game.town_services.show(); await frames(10); assert_header(game.ui._modal_panel,"trade")
 for quantity in game.ui._modal_panel.find_children("*","SpinBox",true,false):
  verify(quantity.size.x<=240,"Trade quantity input expands like a full-width text editor")
 await capture("trade-1440-125")
 if is_instance_valid(game.ui.modal): await tap(KEY_ESCAPE)
 GameUIStyle.set_text_scale(1.0,root); actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
 await tap(KEY_I); await select_item(weapon); await click("比较"); await frames(8)
 assert_header(screen._panel); await capture("inventory-list-1440-100"); await tap(KEY_ESCAPE)
 await capture("hud-1440-100")
 await tap(KEY_I); await select_item(weapon); await click("装备这件"); await frames(10)
 verify(weapon in store.equipped("player").values() and weapon in screen._portrait._visual.display_uids,"Paper doll does not reflect the same real equipped weapon")
 verify(screen._portrait._body.scale.x>=3 and screen._portrait._preview.size.y>=190,"Equipped character preview is too small to inspect gear")
 screen._detail_scroll.ensure_control_visible(screen._item_art); await frames(6)
 await capture("equipped-character-1440-100")
 var bottle:=store.ready_uid("player","water_sprayer")
 await select_item(bottle); await frames(6)
 verify(screen._item_art.item_id=="water_sprayer" and screen._item_art.get_meta("item_uid")==bottle,"Changing item retains the previous weapon artwork")
 await capture("item-art-bottle-1440-100")
 await tap(KEY_ESCAPE)
 await fixture.close()
 var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
 if not output.is_empty():
  var file:=FileAccess.open(output.path_join("ui-prototype.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Controlled Godot scene, real keyboard/pointer, normal AI/time; service/crafting presenters mounted explicitly. No natural playthrough, commercial hardware or audio claim."},"  "))
 if failures.is_empty(): print("PASS prototype UI: %d checks; readable single-row headers, real instance sorting/grid/compare, fixed 13-slot binder, centered HUD, 6 live pages and real service/work layouts"%checks)
 quit(0 if failures.is_empty() else 1)
