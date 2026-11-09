extends "res://tests/support/input_scene_probe.gd"
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var casts:=0
func visible_text(fragment: String) -> bool:
 for node in root.find_children("*","Control",true,false):
  if node.is_visible_in_tree() and (node is Label or node is RichTextLabel) and str(node.text).contains(fragment): return true
 return false
func scroll(step: MouseButton) -> void:
 var point:=Vector2(550,300)
 if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
 var motion:=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true); await frames()
 var event:=InputEventMouseButton.new(); event.position=point; event.button_index=step; event.pressed=true
 root.push_input(event,true); await frames()
 event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames()
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 GameRuntime.instance.set_process(true)
 var actor:=game.player; var store:=game.session.inventory; var manager:=actor.skill_manager
 actor.position=Vector2(-3100,1840); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 store.receive("player","metal_scrap",1)
 store.receive("player","charcoal",1)
 store.receive("player","sap",4)
 game.survival.supplies.known_recipes["arrows"]=true
 await key(KEY_F,true); await key(KEY_F,false)
 await click("木杆箭"); await click("加工：木杆箭")
 check(store.count("player","arrow")==6 and visible_text("产出 ×6 · 持有 6"),"Arrow recipe did not show real output ID/count after actual manufacture")
 check(visible_text("当前口袋") and visible_text("背包"),"Craft result omitted output location/readiness")
 await capture("crafted-arrow-readiness")
 await click("整理：木杆箭")
 check(game.inventory_screen.visible and store.item(game.inventory_screen.selected)!=null and store.item(game.inventory_screen.selected).definition_id=="arrow" and not paused,"Craft-to-inventory navigation lost the real output or paused world")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_F,true); await key(KEY_F,false)
 var sap:=store.count("player","sap"); var coins:=store.count("player","coin")
 await click("树液 ×%d · 1币"%sap)
 await click("出售一件 · 1币")
 check(store.count("player","sap")==sap-1 and visible_text("树液"),"Sale failed or selection disappeared")
 await click("出售一件 · 1币")
 check(store.count("player","sap")==sap-2,"Second sale required reselecting the stack")
 await capture("retained-trade-selection")
 await click("出售整叠")
 check(store.count("player","sap")==0 and store.count("player","coin")==coins+sap,"Batch trade lost items or charged incorrect total")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Journal follows the actual note read and retains a specific entry.
 var handbook: ExplorationInteractable
 for node in game.region_root.get_children():
  if node is ExplorationInteractable and node.title.contains("手册"): handbook=node; break
 check(handbook!=null,"Handbook fixture not found")
 if handbook:
  actor.position=handbook.position+Vector2(0,30); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
  await key(KEY_F,true); await key(KEY_F,false)
  await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
  await key(KEY_J,true); await key(KEY_J,false)
  check(game.hub.page=="knowledge" and game.hub.selected=="river.handbook","J did not locate the actual newly read handbook")
  await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Controlled known actions and material stock; subsequent requests use real input.
 for operation in SpellOperationCatalog.default_catalog().operations: game.progress.actions[operation.action.get_id()]=true
 game._apply_knowledge()
 var rune:=manager.pool.get_skill("inscribe")
 var focus:=SpellOperationCatalog.default_catalog().operation("attune").action
 store.receive("player","fire_stone",2)
 manager.equip_source("slot_4",rune,{"payload":"ember","modifier":"","uid":""})
 manager.equip_source("quick_e",focus,{"mode":"auto"})
 manager.cast_committed.connect(func(_plan): casts+=1)
 actor.position=Vector2(-3500,2280); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_5,true); await key(KEY_5,false); await frames(75)
 check(casts==1 and manager.selection_for_source("quick_e").get("payload","")=="attune_fire","Real inscription did not update automatic follow-up form")
 await key(KEY_E,true); await key(KEY_E,false); await frames(40)
 check(casts==2 and actor.get_node("BuffManager").has_buff("ember_focus"),"E did not execute the real following attunement")
 await create_timer(focus.cooldown+.3).timeout
 var snapshot:=store.snapshot(); var mana:=actor.mana_component.mp
 await scroll(MOUSE_BUTTON_WHEEL_DOWN)
 check(manager.shortcuts.selection("quick_e").get("payload")=="basic" and casts==2 and actor.mana_component.mp==mana and store.snapshot()==snapshot,"World scroll did not fix a form, or cast/spent resources")
 await scroll(MOUSE_BUTTON_WHEEL_UP)
 check(manager.shortcuts.selection("quick_e").get("payload","")=="attune_fire","World scroll did not return to the executable fire form")
 await key(KEY_M,true); await key(KEY_M,false); await key(KEY_E,true); await key(KEY_E,false); await frames(20)
 check(actor.material_wheel.visible and not actor.material_wheel.entries.is_empty() and actor.material_wheel.entries.all(func(row: Dictionary): return row.is_empty() or row.ready and row.variant_id!="auto"),"Live wheel failed to show only currently executable concrete forms")
 await capture("automatic-follow-and-wheel")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 await create_timer(rune.cooldown+.4).timeout
 await key(KEY_5,true)
 var pending_mana:=actor.mana_component.mp; var pending_stock:=store.count("player","fire_stone")
 await scroll(MOUSE_BUTTON_WHEEL_DOWN)
 await key(KEY_5,false); await frames(80)
 check(casts==2 and actor.mana_component.mp==pending_mana and store.count("player","fire_stone")==pending_stock and manager.combinations.pending.is_empty(),"Changing a prepared form replayed release or committed old material")
 # Missing material must produce visible refusal rather than silently fail.
 store.pay("player",{"fire_stone":store.count("player","fire_stone")})
 manager.shortcuts.set_selection("slot_4",{"payload":"ember","modifier":"","uid":""})
 await key(KEY_5,true); await key(KEY_5,false)
 check(game.ui.message.text.contains("材料") and game.ui.message.text.contains("口袋"),"Cast refusal did not surface material location in the global notice")
 root.size=Vector2i(960,540); await frames(6)
 await key(KEY_I,true); await key(KEY_I,false)
 check(game.inventory_screen.visible and not paused,"Small inventory paused or failed to open")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 check(not actor.ui_blocked,"Small-window Escape failed to return to world")
 await fixture.close()
 if failures.is_empty(): print("PASS flow input: real manufacture/readiness/navigation, repeat/batch sale, contextual J, automatic attunement, world wheel/no stale release, visible refusal and small-window return")
 quit(0 if failures.is_empty() else 1)
