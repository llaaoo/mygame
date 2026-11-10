extends "res://tests/support/input_scene_probe.gd"
## New game, normal AI/stats, isolated save. No content or inventory grants.
func walk_to(point: Vector2) -> void:
 var held: Dictionary={}
 for step in range(240):
  var offset:=point-game.player.position
  if offset.length()<24: break
  var desired: Dictionary={KEY_A:offset.x< -15,KEY_D:offset.x>15,KEY_W:offset.y< -15,KEY_S:offset.y>15}
  for code in desired:
   if bool(held.get(code,false))==desired[code]: continue
   var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=desired[code]
   Input.parse_input_event(event)
  held=desired
  Input.flush_buffered_events(); await frames(1)
 for code in held:
  var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=false
  Input.parse_input_event(event)
 Input.flush_buffered_events(); await frames()
 check(game.player.position.distance_to(point)<65,"Natural input walk did not reach the handbook approach")
func run() -> void:
 root.size=Vector2i(1152,648)
 game=load("res://grayriver.tscn").instantiate()
 game.persistence_enabled=false
 root.add_child(game); current_scene=game
 await frames(30)
 game.ui.close_modal(); await frames(18)
 check(get_nodes_in_group("interactable").size()>15,"New-game region did not mount its actual interactions")
 var hud:=get_first_node_in_group("hud_ui")
 check(hud._actor_status.is_visible_in_tree() and hud._actor_status.context==game.player.actor_context,"Combat resource strip never bound to campaign actor")
 check(not game.ui._survival_label.get_parent().visible,"Healthy survival information still occupies the world HUD")
 check(not game.ui._terrain_label.get_parent().visible,"Dry ground information still occupies the world HUD")
 check(not hud.skill_bar._hint_panel.visible,"Idle spell summary still occupies the world HUD")
 await capture("01-world")
 await key(KEY_TAB,true); await key(KEY_TAB,false)
 check(not paused and game.player.ui_blocked and game.hub.page=="actions","Preparation navigation failed")
 await capture("02-expedition")
 await click("快捷栏编组"); await click("打开快捷栏编组")
 var pool:=game.player.skill_pool_ui
 check(pool._equip_slots.size()==13,"Binder lost mixed quickslots")
 # Selecting a card must keep target shortcuts in their independent scroll column.
 var card:=pool._skill_grid.get_child(0) as Control
 await point_click(card.get_global_rect().get_center())
 await frames()
 var last: Control=pool._equip_slots.back()
 var scroll:=last.get_parent().get_parent() as ScrollContainer
 scroll.ensure_control_visible(last); await frames()
 check(scroll.get_global_rect().encloses(last.get_global_rect()),"Final shortcut clipped after selecting a skill")
 check(pool._panel.get_global_rect().encloses(scroll.get_global_rect()),"Binder target column extends outside modal")
 await capture("03-quickslots")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 await key(KEY_M,true); await key(KEY_M,false)
 check(not paused and game.player.ui_blocked and is_instance_valid(game.ui.modal) and not game.player.material_wheel.visible,"M did not open only the map")
 await capture("04-map")
 await key(KEY_M,true); await key(KEY_M,false)
 check(not is_instance_valid(game.ui.modal) and not game.player.ui_blocked,"M did not toggle the map closed")
 await key(KEY_I,true); await key(KEY_I,false);await key(KEY_M,true); await key(KEY_M,false)
 check(is_instance_valid(game.ui.modal) and not game.inventory_screen.visible,"M failed to switch inventory to map")
 await key(KEY_M,true); await key(KEY_M,false)
 await key(KEY_K,true); await key(KEY_K,false);await key(KEY_M,true); await key(KEY_M,false)
 check(is_instance_valid(game.ui.modal) and not pool.visible,"M failed to switch loadout to map")
 await key(KEY_M,true); await key(KEY_M,false)
 await key(KEY_G,true); await key(KEY_G,false)
 check(game.player.material_wheel.visible and not paused and not game.player.ui_blocked,"Live selector input failed")
 await capture("05-source-overview")
 await key(KEY_G,true); await key(KEY_G,false)
 check(not game.player.material_wheel.visible and not is_instance_valid(game.ui.modal),"G did not close only the selector")
 await key(KEY_G,true); await key(KEY_G,false);await key(KEY_M,true); await key(KEY_M,false)
 check(is_instance_valid(game.ui.modal) and not game.player.material_wheel.visible,"M did not switch selector to map")
 await key(KEY_M,true); await key(KEY_M,false)
 # Reach the real handbook by walking; no fixture grants or teleport.
 await walk_to(Vector2(-3500,2390))
 await key(KEY_F,true); await key(KEY_F,false)
 check(game.progress.claims.has("river.handbook"),"Natural input did not read the town handbook")
 await capture("06-handbook")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 await key(KEY_K,true); await key(KEY_K,false)
 var learned: Control
 for label in pool._skill_grid.find_children("*","Label",true,false):
  if label.text=="喷洒介质": learned=label
 check(learned!=null,"Natural handbook did not expose spray in loadout")
 if learned:
  await point_click(learned.get_global_rect().get_center())
  var target_slot: Control=pool._equip_slots[pool._equip_sources.find("quick_e")]
  (target_slot.get_parent().get_parent() as ScrollContainer).ensure_control_visible(target_slot); await frames()
  await point_click(target_slot.get_global_rect().get_center())
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var before:=game.session.inventory.snapshot()
 await key(KEY_G,true); await key(KEY_G,false)
 await key(KEY_E,true); await key(KEY_E,false)
 var wheel:=game.player.material_wheel
 check(wheel.visible,"Learned operation missing from wheel")
 await capture("07-payloads")
 var target:=-1
 for i in range(wheel.entries.size()):
  if wheel.entries[i].get("choice",{}).get("payload","")=="resin": target=i
 check(target<0,"Unavailable resin bottle remained in the combat wheel")
 # Unavailable bottles are omitted; K retains the learned catalogue.
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 check(game.session.inventory.snapshot()==before,"Opening/cancelling payload consumed an item")
 await key(KEY_K,true); await key(KEY_K,false)
 var inscription: Control
 for label in pool._skill_grid.find_children("*","Label",true,false):
  if label.text=="喷洒介质": inscription=label
 check(inscription!=null,"Learned spray operation missing from binder")
 if inscription:
  await point_click(inscription.get_global_rect().get_center())
  await capture("08-learned-quickslots")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Small-window layout still contains modal body and close affordance.
 root.size=Vector2i(800,600); await frames()
 await key(KEY_TAB,true); await key(KEY_TAB,false)
 var panel:=game.ui._modal_panel
 check(root.get_visible_rect().encloses(panel.get_global_rect()),"Small-window menu extends outside viewport")
 await capture("09-small-window")
 game.ui.close_modal(); game.queue_free(); current_scene=null; await frames(6)
 if failures.is_empty(): print("PASS visual interface: natural new-game input, bound resources, contextual HUD, 13 accessible shortcuts, map and small-window shell; normal AI/stats")
 quit(0 if failures.is_empty() else 1)
