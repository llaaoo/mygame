extends "res://tests/support/input_scene_probe.gd"
## Production UI vertical slice, explicit inventory/knowledge fixture, normal simulation/AI.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
const Awake:=preload("res://tests/support/awakened_actor_fixture.gd")
var casts:=0
var checks:=0
var evidence: Array[Dictionary]=[]
func verify(ok: bool,message: String) -> void:
 checks+=1; check(ok,message)
func tap(code: Key) -> void:
 await key(code,true); await key(code,false)
func point_click(point: Vector2) -> void:
 if DisplayServer.get_name()=="headless":
  await super.point_click(point); return
 # Native pointer input uses window pixels, including viewport scaling after resize.
 var pixel:=root.get_screen_transform()*point
 Input.warp_mouse(pixel)
 var motion:=InputEventMouseMotion.new(); motion.position=pixel; motion.global_position=pixel
 Input.parse_input_event(motion); Input.flush_buffered_events(); await frames(2)
 var press:=InputEventMouseButton.new(); press.position=pixel; press.global_position=pixel; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
 Input.parse_input_event(press); Input.flush_buffered_events(); await frames(2)
 press=press.duplicate(); press.pressed=false; Input.parse_input_event(press); Input.flush_buffered_events(); await frames(2)
func focus_back() -> void:
 var event:=InputEventKey.new(); event.keycode=KEY_TAB; event.physical_keycode=KEY_TAB; event.shift_pressed=true; event.pressed=true
 Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
 event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
func select_item(uid: String) -> void:
 var screen:=game.inventory_screen
 var tile:=screen._tiles.get(uid) as Control
 verify(tile!=null,"Missing owned UID tile: "+uid)
 if not tile: return
 screen._grid_scroll.ensure_control_visible(tile); await frames()
 await point_click(tile.get_global_rect().get_center())
 verify(screen.selected==uid,"Physical pointer did not select intended UID: "+uid)
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 GameRuntime.instance.set_process(true)
 for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
 var manager:=actor.skill_manager; var store:=game.session.inventory
 manager.cast_committed.connect(func(_plan): casts+=1)
 var hud:=game.get_node("HUDLayer")
 var bar: SkillBar=hud.skill_bar
 await frames(8)
 verify(bar._sources==QuickslotLoadout.SOURCES,"The HUD does not own all 13 independent sources in order")
 verify(not hud.mana_bar.get_parent().visible,"Ordinary traveler sees a fake mana row")
 # Click is a read-only intent. Explicit mouse use still reaches the same real executor.
 store.receive_into("player.pocket","ration",3)
 var count:=store.count("player","ration")
 manager.shortcuts.bind_item("item_0","ration")
 var attack:=actor.actor_context.actions._attack_sequence
 await point_click(bar._panels[9].get_global_rect().get_center())
 verify(actor.material_wheel.visible and actor.material_wheel._inspection and not actor.ui_blocked,"Item click did not open a live inspector")
 verify(not actor.field_work.is_busy() and store.count("player","ration")==count and actor.actor_context.actions._attack_sequence==attack,"Inspecting an item used it or leaked a weapon gesture")
 await capture("item-inspection")
 await tap(KEY_ESCAPE)
 verify(not actor.material_wheel.visible and not actor.ui_blocked,"Inspection cancellation retained input ownership")
 # A pinned bottle is never silently substituted if lost.
 store.receive_into("player.pocket","water_sprayer",2)
 var bottle:=store.ready_uid("player","water_sprayer")
 manager.shortcuts.bind_item("quick_e","water_sprayer",bottle)
 await point_click(bar._panels[1].get_global_rect().get_center()); await frames(8)
 verify(actor.material_wheel._inspection_text.text.contains(store.state_text(bottle)),"Inspector lost exact bottle state")
 var other:="player.pack"
 verify(game.inventory_actions.transfer(bottle,other,1).accepted,"Bottle fixture could not leave the pocket")
 await frames(15)
 verify(not QuickslotView.item_state(actor,manager.shortcuts.binding("quick_e")).ready and manager.shortcuts.binding("quick_e").uid==bottle,"Lost source was replaced by another bottle")
 await tap(KEY_ESCAPE)
 var uid:=store.find_owned("player","charcoal")
 if uid.is_empty(): store.receive_into("player.pack","charcoal",6); uid=store.find_owned("player","charcoal")
 store.receive("player","river_sabre",1)
 var weapon:=store.find_owned("player","river_sabre")
 var inventory:=game.inventory_screen
 for extent in [Vector2i(960,540),Vector2i(960,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  root.content_scale_size=extent; root.size=extent; await frames(6)
  GameUIStyle.set_text_scale(1.25,root)
  await tap(KEY_I); await select_item(weapon)
  verify(inventory.visible and root.get_visible_rect().encloses(inventory._panel.get_global_rect()),"Large-font inventory leaves viewport: "+str(extent))
  await click("比较"); await frames(4)
  var comparison:=inventory._details.find_child("EquipmentComparison",true,false)
  verify(comparison!=null and comparison.get_meta("candidate_id","")==store.item(weapon).definition_id,"Comparison lost selected equipment identity")
  if comparison:
   var weight_rows:=comparison.get_children().filter(func(n): return n.has_meta("stat_key") and n.get_meta("stat_key")=="weight")
   verify(weight_rows.size()==1 and is_equal_approx(float(weight_rows[0].get_meta("after")),store.equipment_definition(weapon).weight),"Comparison weight does not project the real instance definition")
  verify(inventory._grid.columns==1 and inventory._tiles[weapon]._title.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"Inventory default is not the prototype left-aligned list")
  verify(inventory._columns.global_position.y-inventory._panel.global_position.y<150,"Inventory header consumes the content area")
  await click("绑定快捷槽"); await frames(4)
  var bind:=inventory._binding_host.get_node_or_null("QuickBind/Bind_quick_e") as Button
  var last:=inventory._binding_host.get_node_or_null("QuickBind/Bind_item_3") as Button
  if not bind or not last:
   await capture("failed-binding"); await fixture.close(); quit(1); return
  await capture("binding-"+str(extent.x)+"x"+str(extent.y)+"-125")
  verify(root.get_visible_rect().encloses(last.get_global_rect()) and root.get_visible_rect().encloses(bind.get_global_rect()) and bind.size.x>=40 and bind.size.y>=40,"13-slot binding picker cropped or undersized: "+str(extent))
  verify(inventory._detail_actions.get_global_rect().position.y>=inventory._detail_scroll.get_global_rect().end.y,"Main actions overlap reading content")
  var clock:=GameRuntime.instance.simulation_runtime.elapsed_time
  await frames(6)
  verify(not paused and actor.ui_blocked and GameRuntime.instance.simulation_runtime.elapsed_time>clock,"Full inventory paused simulation")
  await tap(KEY_TAB)
  var first:=root.gui_get_focus_owner()
  verify(first!=null,"Page has no reachable keyboard focus")
  await tap(KEY_TAB)
  verify(inventory.visible and not is_instance_valid(game.ui.modal) and root.gui_get_focus_owner()!=first,"Tab changed page instead of moving focus")
  await focus_back()
  verify(root.gui_get_focus_owner()==first,"Shift+Tab did not return to previous focus")
  await point_click(bind.get_global_rect().get_center()); await frames(6)
  verify(manager.shortcuts.binding("quick_e").get("uid","")==weapon and not inventory._binding_open and casts==0,"In-place binding cast, stayed expanded or lost physical UID")
  await capture("comparison-"+str(extent.x)+"x"+str(extent.y)+"-125")
  var item_before:=store.item(weapon).snapshot()
  await point_click(inventory._grid_toggle.get_global_rect().get_center()); await frames(8)
  verify(inventory._grid_mode and inventory.selected==weapon and store.item(weapon).snapshot()==item_before,"View toggle changed selection or physical item")
  await point_click(inventory._grid_toggle.get_global_rect().get_center()); await frames(8)
  verify(not inventory._grid_mode and inventory._grid.columns==1,"List toggle failed")
  var binding:=manager.shortcuts.binding("quick_e")
  await click("绑定快捷槽"); await tap(KEY_ESCAPE)
  verify(inventory.visible and not inventory._binding_open and manager.shortcuts.binding("quick_e")==binding,"Esc did not close only uncommitted picker")
  await select_item(uid)
  await point_click(inventory._search.get_global_rect().get_center()); await key(KEY_E,true,101); await key(KEY_E,false)
  verify(inventory.visible and inventory._search.text=="e" and casts==0,"Typing in search navigated/cast")
  await capture("inventory-"+str(extent.x)+"x"+str(extent.y)+"-125")
  await tap(KEY_ESCAPE); await tap(KEY_I)
  verify(inventory._search.text=="e" and inventory.selected==uid,"Reopening inventory lost selected UID/search")
  await tap(KEY_ESCAPE)
  verify(root.get_visible_rect().encloses(bar.get_parent().get_global_rect()),"13-slot HUD leaves viewport: "+str(extent))
  verify(not bar.get_parent().get_global_rect().intersects(hud.get_node("MarginContainer/HUDRoot/StatusPanel").get_global_rect()),"Resources overlap shortcut targets: "+str(extent))
  evidence.append({"requested_window":extent,"actual_window":root.size,"logical_viewport":root.get_visible_rect().size,"font_scale":1.25,"hud_sources":bar._sources.size(),"binding_last_rect":str(last.get_global_rect()) if is_instance_valid(last) else "picker closed after explicit binding"})
  await capture("world-"+str(extent.x)+"x"+str(extent.y))
  # Start each size from a clean view context, not a leftover search filter.
  inventory._view_context.clear()
 # Real form selection, shared plan, invalidation, and old key release protection.
 GameUIStyle.set_text_scale(1.0,root); root.content_scale_size=Vector2i(1152,648); root.size=Vector2i(1152,648)
 verify(Awake.awaken(actor),"Awakened form fixture failed")
 manager.known_actions.ignite=true
 manager.equip_source("right",manager.pool.get_skill("ignite"),{"payload":"","modifier":"","uid":""})
 await tap(KEY_G); await tap(KEY_R); await frames(8)
 var wheel:=actor.material_wheel
 verify(wheel.visible and not wheel.entries.is_empty(),"Learned action has no real current form")
 var mp:=actor.mana_component.mp; var stock:=store.material_amounts("player")
 await point_click(wheel.entry_point(0)); await frames(8)
 verify(not wheel.visible and casts==0 and actor.mana_component.mp==mp and store.material_amounts("player")==stock,"Selecting a form paid or cast")
 verify(bar._hint_panel.visible and bar._combination_hint.text.contains("固定") and bar._combination_hint.text.contains("MP"),"Current form/cost vanishes after selection")
 await capture("current-form-world")
 actor.mana_component.mp=0; await frames(15)
 verify(bar._hint_panel.visible and bar._combination_hint.text.contains("法力"),"Current source failure silently disappeared")
 await tap(KEY_G); await tap(KEY_R); await frames(5)
 verify(wheel.visible and wheel.entries.all(func(row):return row.is_empty()),"Unavailable source became a free fallback")
 await tap(KEY_ESCAPE)
 # Full menus cancel an actual charge and do not replay its old release.
 actor.mana_component.mp=actor.mana_component.max_mp
 manager.known_actions.charged_fireball=true
 manager.equip_source("right",manager.pool.get_skill("charged_fireball"))
 mp=actor.mana_component.mp; var committed:=casts
 await key(KEY_R,true)
 verify(actor.casting._charging_source=="right","Real held R did not begin the explicit charge fixture")
 await tap(KEY_I); await key(KEY_R,false); await tap(KEY_ESCAPE); await frames(8)
 verify(not actor.ui_blocked and not paused and actor.casting._charging_source.is_empty() and casts==committed and actor.mana_component.mp==mp,"Closing inventory replayed a cancelled charge or consumed mana")
 manager.equip_source("right",manager.pool.get_skill("ignite"),{"payload":"","modifier":"","uid":""})
 var saved:=manager.shortcuts.snapshot(); var doses:int=store.item(bottle).properties.doses
 game._save_progress(); await fixture.close(); game=await fixture.boot(true)
 if game.player.skill_manager.shortcuts.snapshot()!=saved: print("Expected UI bindings: ",saved,"\nRestored UI bindings: ",game.player.skill_manager.shortcuts.snapshot())
 verify(game.player.skill_manager.shortcuts.snapshot()==saved and game.session.inventory.item(bottle).properties.doses==doses,"Disk reload lost bindings or exact bottle remainder")
 await fixture.close()
 var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
 if not output.is_empty():
  var file:=FileAccess.open(output.path_join("ui-vertical.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sizes":evidence,"scope":"Actual Godot UI with controlled inventory/knowledge/position, normal AI/time; not a natural journey or target hardware benchmark"},"  "))
 if failures.is_empty(): print("PASS UI vertical slice: %d checks, 13 sources, live item inspection, exact UID failure, typed comparison, fixed actions, binding/cancel/focus/context, 4 large-text sizes, form preview and disk reload"%checks)
 quit(0 if failures.is_empty() else 1)
