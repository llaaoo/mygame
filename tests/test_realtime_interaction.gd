extends "res://tests/support/input_scene_probe.gd"
## Real keys/mouse, normal AI and default stats; explicit knowledge/stock/position fixture.
var commits: Array[Dictionary]=[]
func mouse(button: MouseButton,pressed: bool,point: Vector2) -> void:
 var event:=InputEventMouseButton.new(); event.button_index=button; event.pressed=pressed; event.position=point; event.global_position=point
 Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
func choose(payload: String,uid := "") -> void:
 var wheel:=game.player.material_wheel
 var index:=-1
 for i in range(wheel.entries.size()):
  if wheel.entries[i].get("choice",{}).get("payload","")==payload: index=i; break
 check(index>=0,"Missing wheel payload: "+payload)
 if index<0: return
 while wheel.page!=index/wheel.page_size():
  await mouse(MOUSE_BUTTON_WHEEL_DOWN,true,wheel._ring.position+Vector2(180,180))
 var point:=wheel.entry_point(index)
 if not uid.is_empty():
  var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await frames()
  for attempt in range(8):
   if wheel.entries[index].choice.get("uid","")==uid: break
   await mouse(MOUSE_BUTTON_WHEEL_DOWN,true,point)
 await point_click(point)
func item_click(uid: String) -> void:
 var screen:=game.inventory_screen
 var tile:=screen._grid.get_node_or_null("Item_"+uid.replace(".","_")) as Control
 check(tile!=null,"Missing inventory tile: "+uid)
 if not tile: return
 (screen._grid.get_parent() as ScrollContainer).ensure_control_visible(tile); await frames()
 await point_click(tile.get_global_rect().get_center())
func set_quantity(value: int) -> void:
 var line:=game.inventory_screen._quantity.get_line_edit()
 await point_click(line.get_global_rect().get_center())
 var all:=InputEventKey.new(); all.keycode=KEY_A; all.physical_keycode=KEY_A; all.ctrl_pressed=true; all.pressed=true
 root.push_input(all,true); all=all.duplicate(); all.pressed=false; root.push_input(all,true); await frames()
 for character in str(value): await key(KEY_0+int(character),true,character.unicode_at(0)); await key(KEY_0+int(character),false)
 await key(KEY_ENTER,true); await key(KEY_ENTER,false)
func drag_item(uid: String,target: Control) -> void:
 var tile:=game.inventory_screen._grid.get_node("Item_"+uid.replace(".","_")) as Control
 (tile.get_parent().get_parent() as ScrollContainer).ensure_control_visible(tile); await frames()
 var from:=tile.get_global_rect().get_center(); var to:=target.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new(); motion.position=from; motion.global_position=from; root.push_input(motion,true); await frames()
 var button:=InputEventMouseButton.new(); button.position=from; button.global_position=from; button.pressed=true; button.button_index=MOUSE_BUTTON_LEFT
 root.push_input(button,true); await frames()
 for step in range(1,7):
  motion=InputEventMouseMotion.new(); motion.position=from.lerp(to,step/6.0); motion.global_position=motion.position; motion.relative=(to-from)/6
  motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion,true); await frames(2)
 button=button.duplicate(); button.position=to; button.global_position=to; button.pressed=false; root.push_input(button,true); await frames(10)
func run() -> void:
 root.size=Vector2i(1152,648)
 game=load("res://grayriver.tscn").instantiate(); game.persistence_enabled=true
 root.add_child(game); current_scene=game; await frames(30); game.ui.close_modal()
 var actor:=game.player
 var sm:=actor.skill_manager
 var store:=game.session.inventory
 game.progress.actions.merge({"fire_sigil":true,"poison_cloud":true},true)
 game.progress.spell_rules["fire_sigil_fireball"]=true; game._apply_knowledge()
 store.receive("player","fire_stone",2); store.receive("player","frost_salt",2)
 store.receive("player","venom_sprayer",2); store.receive("player","water_sprayer",1); store.receive("player","charcoal",6); store.receive("player","river_shield",1)
 sm.equip_source("left",sm.pool.get_skill("inscribe")); sm.equip_source("quick_e",sm.pool.get_skill("disperse"))
 var instance:=sm.get_instance("left")
 sm.cast_committed.connect(func(plan: CastPlan): commits.append({"label":plan.effect_label,"cost":plan.cost,"source":plan.source}))
 check(actor.health_component.max_hp==100 and actor.mana_component.max_mp==60 ,"UI fixture changed default caps or regeneration")
 store.receive("player","river_sabre",1)
 var blade:=store.find_owned("player","river_sabre")
 check(game.inventory_actions.equip(blade).accepted,"Guard fixture could not equip an actual blade")
 # M click mode changes one source only, without casts, costs or instance recreation.
 var stock:=store.snapshot(); var mp:=actor.mana_component.mp
 var attack_sequence:=actor.actor_context.actions._attack_sequence
 await key(KEY_G,true); await key(KEY_G,false); await key(KEY_Q,true); await key(KEY_Q,false)
 check(actor.material_wheel.visible and not paused and not actor.ui_blocked,"Wheel blocked world or took full-menu input ownership")
 await choose("ember")
 check(actor.actor_context.actions._attack_sequence==attack_sequence and actor.actor_context.actions.stamina.current==100,"Confirming the wheel leaked a physical attack or stamina cost")
 check(not actor.material_wheel.visible and sm.shortcuts.selection("left").payload=="ember","Mouse wheel selection did not configure Q")
 check(commits.is_empty() and store.snapshot()==stock and actor.mana_component.mp==mp and sm.get_instance("left")==instance,"Selecting material cast/paid or replaced its skill instance")
 await key(KEY_Q,true); await key(KEY_Q,false); await create_timer(1.0).timeout
 check(store.count("player","fire_stone")==1 and commits.size()==1,"Q did not inscribe with the selected real stone")
 await key(KEY_R,true); await key(KEY_R,false); await create_timer(.55).timeout
 check(commits.size()==2 and commits.back().cost==12 and "火球" in str(commits.back().label),"Fire field + R did not produce paid fireball feedback")
 await capture("01-fire-combination")
 # K can prepare an unavailable form, but changing it never bypasses shared cooldown.
 check(QuickslotMaterials.select(actor,"left",{"payload":"frost","modifier":"","uid":""}),"Preparation selection refused")
 check(not sm.use_source("left",actor,CastContext.simple(actor,Vector2.RIGHT,sm.get_instance("left").data)),"Changing material bypassed the shared inscription cooldown")
 QuickslotMaterials.select(actor,"left",{"payload":"ember","modifier":"","uid":""})
 await create_timer(sm.get_cooldown("left")+.1).timeout
 # Middle-button hold mode can target a shortcut while guarding; its old release never casts.
 var center:=root.get_visible_rect().size*.5
 await mouse(MOUSE_BUTTON_RIGHT,true,Vector2(650,320))
 await mouse(MOUSE_BUTTON_MIDDLE,true,center)
 await key(KEY_Q,true); await key(KEY_Q,false)
 var wheel:=actor.material_wheel
 var index:=0
 for i in range(wheel.entries.size()):
  if wheel.entries[i].get("choice",{}).get("payload","")=="frost": index=i
 var point:=wheel.entry_point(index)
 var move:=InputEventMouseMotion.new(); move.position=point; move.global_position=point; root.push_input(move,true); await frames()
 check(actor.actor_context.actions.guarding and actor.get_mouse_direction().is_equal_approx(wheel.opening_direction),"Opening selector dropped held guard or changed defense direction")
 var hud:=get_first_node_in_group("hud_ui")
 check(wheel._detail_host.get_global_rect().position.x>=hud.get_node("MarginContainer/HUDRoot/StatusPanel").get_global_rect().end.x,"Wheel description obscures combat resources")
 check(wheel._detail_host.get_global_rect().end.y<=hud.get_node("MarginContainer/HUDRoot/SkillBarPanel").get_global_rect().position.y,"Wheel description obscures shortcut cooldowns")
 await capture("02-material-wheel")
 await mouse(MOUSE_BUTTON_MIDDLE,false,point); await mouse(MOUSE_BUTTON_RIGHT,false,point)
 check(sm.shortcuts.selection("left").payload=="frost" and commits.size()==2 and sm.get_instance("left")==instance,"Hold-confirm recast, reset, or changed the wrong source")
 # Confirming a selector and pressing its shortcut in one input frame is one new cast.
 if sm.get_cooldown("right")>0: await create_timer(sm.get_cooldown("right")+.05).timeout
 await key(KEY_G,true); await key(KEY_G,false); await key(KEY_R,true)
 var finish_key:=InputEventKey.new(); finish_key.keycode=KEY_R; finish_key.physical_keycode=KEY_R; finish_key.pressed=false
 Input.parse_input_event(finish_key)
 var basic_point:=wheel.entry_point(0)
 var confirm:=InputEventMouseButton.new(); confirm.button_index=MOUSE_BUTTON_LEFT; confirm.position=basic_point; confirm.global_position=basic_point; confirm.pressed=true
 Input.parse_input_event(confirm); confirm=confirm.duplicate(); confirm.pressed=false; Input.parse_input_event(confirm)
 finish_key=finish_key.duplicate(); finish_key.pressed=true; Input.parse_input_event(finish_key); Input.flush_buffered_events()
 var old_count:=commits.size(); await frames(35)
 await key(KEY_R,false)
 check(commits.size()==old_count+1,"Fresh shortcut after same-frame selector close was swallowed or duplicated")
 # Exact-bottle choice; a partial pulse remains paid after opening the selector.
 var poison:=store.ready_uid("player","venom_sprayer")
 var water:=store.ready_uid("player","water_sprayer")
 await key(KEY_G,true); await key(KEY_G,false); await key(KEY_E,true); await key(KEY_E,false); await choose("venom",poison)
 check(sm.shortcuts.selection("quick_e").uid==poison,"Spray selector did not pin the visible bottle")
 await key(KEY_E,true); await create_timer(.6).timeout
 await key(KEY_G,true); await key(KEY_G,false)
 var spent_doses: int=store.item(poison).properties.doses if store.item(poison) else 0
 await key(KEY_E,false); await frames(14)
 check(spent_doses<3 and (int(store.item(poison).properties.doses) if store.item(poison) else 0)==spent_doses,"Opening selector refunded or continued the old spray")
 var other_poison: String=""
 for row in store.entries("player.pocket"):
  if row.definition=="venom_sprayer" and row.uid!=poison: other_poison=row.uid; break
 check(not other_poison.is_empty(),"Missing second same-type bottle fixture")
 await choose("venom",other_poison)
 check(sm.shortcuts.selection("quick_e").uid==other_poison and int(store.item(other_poison).properties.doses)==3,"Grouped bottle scroll did not select the explicit second UID")
 check((int(store.item(poison).properties.doses) if store.item(poison) else 0)==spent_doses,"Switching bottles changed the old partial remainder")
 await key(KEY_G,true); await key(KEY_G,false)
 await choose("water",water)
 check(sm.shortcuts.selection("quick_e").uid==water and sm.shortcuts.selection("left").payload=="frost","Selecting another bottle changed the wrong shortcut")
 # Full screen does not stop actor recovery, status clocks or AI.
 actor.actor_context.actions.interrupt(.55)
 await key(KEY_I,true); await key(KEY_I,false)
 var screen:=game.inventory_screen
 var clock:=store.clock_seconds
 await create_timer(.8).timeout
 check(screen.visible and actor.ui_blocked and not paused and actor.actor_context.actions.mode=="idle" and store.clock_seconds>clock+.5,"Full inventory froze recovery or the world clock")
 var shield:=store.find_owned("player","river_shield")
 await drag_item(shield,screen._portrait.slots[EquipmentData.SlotType.LEFT_HAND])
 check(shield in store.equipped("player").values(),"Real drag did not equip the matching paper-doll slot")
 var coal:=store.ready_uid("player","charcoal")
 await item_click(coal); await set_quantity(2)
 await point_click(screen._quantity.get_line_edit().get_global_rect().get_center())
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 check(not screen.visible and not actor.ui_blocked,"Focused quantity field trapped Escape instead of returning to combat")
 await key(KEY_I,true); await key(KEY_I,false)
 await item_click(coal); await set_quantity(2); await click("移至背包"); await frames(10)
 check(store.count_in("player.pocket","charcoal")==4 and store.count_in("player.pack","charcoal")==2,"Bulk quantity input did not move exactly two materials")
 var tile:=screen._grid.get_node("Item_"+coal.replace(".","_")) as Control
 var point_context:=tile.get_global_rect().get_center()
 var context_event:=InputEventMouseButton.new(); context_event.position=point_context; context_event.global_position=point_context; context_event.button_index=MOUSE_BUTTON_RIGHT; context_event.pressed=true
 root.push_input(context_event,true); await frames(); context_event=context_event.duplicate(); context_event.pressed=false; root.push_input(context_event,true); await frames()
 check(screen._popup.visible,"Right-click did not open the item context menu")
 await key(KEY_DOWN,true); await key(KEY_DOWN,false); await key(KEY_DOWN,true); await key(KEY_DOWN,false); await key(KEY_ENTER,true); await key(KEY_ENTER,false)
 await frames(10)
 check(store.count("player","charcoal")==5,"Keyboard context action failed to drop exactly one material")
 await capture("03-paper-doll")
 check(screen._portrait.slots.size()==9,"Paper doll lost an equipment slot")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Real mouse drop frees capacity and F opens the same persisted ground container.
 await key(KEY_I,true); await key(KEY_I,false)
 await item_click(water); await click("丢弃整叠"); await frames(12)
 var ground:=store.locate(water)
 check(ground.begins_with("ground.") and not QuickslotView.item_state(actor,{"item_id":"water_sprayer","uid":water}).ready,"Mouse drop did not remove the selected physical bottle")
 await capture("04-ground-drop")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 await key(KEY_F,true); await key(KEY_F,false)
 check(screen.visible and screen.ground_id==ground and not paused,"F did not open nearby ground loot in real time")
 await item_click(water); await click("尽量取走这一叠"); await frames(12)
 check(store.locate(water)=="player.pocket" and int(store.item(water).properties.doses)==3,"Mouse pickup replaced/refilled the unspent bottle")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Observe a real authored guard with normal AI attack through an open inventory.
 var enemy: Enemy
 for candidate in game.active_enemies:
  if candidate.get_meta("frontier_claim","")=="river.enemy.camp.forest.3": enemy=candidate; break
 check(enemy!=null,"Normal-AI menu exposure guard missing")
 var base:=actor.position
 # Check the short dodge at acceptance, away from AI interruption; the enemy
 # exposure sample below remains normal AI. Four rendered frames may outlast .35s.
 var origin:=actor.position
 var world_clock:=store.clock_seconds
 var before_selection:=commits.size()
 await key(KEY_G,true); await key(KEY_G,false); await key(KEY_Q,true); await key(KEY_Q,false)
 await key(KEY_A,true); await choose("ember"); await key(KEY_A,false)
 check(actor.position.distance_to(origin)>8 and store.clock_seconds>world_clock and commits.size()==before_selection,"Combat wheel froze movement/time or cast while selecting")
 await key(KEY_G,true); await key(KEY_G,false)
 var dodge:=InputEventKey.new(); dodge.keycode=KEY_SPACE; dodge.physical_keycode=KEY_SPACE; dodge.pressed=true
 var stamina_before:=actor.actor_context.actions.stamina.current
 Input.parse_input_event(dodge); Input.flush_buffered_events(); await frames(1)
 check(not actor.material_wheel.visible and actor.actor_context.actions.mode=="dodge" and actor.actor_context.actions.stamina.current<stamina_before,"Live wheel did not yield to a paid dodge at acceptance")
 await key(KEY_SPACE,false)
 await create_timer(.45).timeout
 if enemy:
  # A close-range exposure fixture avoids measuring approach/coating preparation
  # or carrying an in-flight dodge into a different location. AI remains unchanged.
  actor.position=enemy.position-Vector2(45,0); actor.get_node("Camera2D").reset_smoothing(); await frames(4)
  var health:=actor.health_component.hp
  await key(KEY_I,true); await key(KEY_I,false)
  await create_timer(2.8).timeout
  check(screen.visible and actor.health_component.hp<health and not paused,"Opening inventory protected the player from normal AI")
  print("REALTIME_UI_AI_DAMAGE ",health-actor.health_component.hp)
  await capture("05-live-menu-under-attack")
  await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
  actor.position=base; actor.get_node("Camera2D").reset_smoothing()
 # Save/re-entry records per-shortcut sources and exact bottle identity.
 game._save_progress()
 var selection:=sm.shortcuts.snapshot()
 game.queue_free(); current_scene=null; await frames(8)
 game=load("res://grayriver.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(30); game.ui.close_modal()
 check(game.player.skill_manager.shortcuts.snapshot()==selection,"Save/re-entry lost per-shortcut wheel selections")
 root.size=Vector2i(800,600); await frames(); await key(KEY_I,true); await key(KEY_I,false)
 check(root.get_visible_rect().encloses(game.inventory_screen._panel.get_global_rect()),"Small inventory extends outside viewport: %s / %s min=%s"%[game.inventory_screen._panel.get_global_rect(),root.get_visible_rect(),game.inventory_screen._panel.get_minimum_size()])
 await capture("06-small-inventory")
 game.inventory_screen.close(); game.queue_free(); current_scene=null; await frames(6)
 if failures.is_empty(): print("PASS realtime interaction: real click/hold selectors, independent slots, fire combo feedback, shared cooldown, pinned spray/payment, guard, recovery/world clocks, mouse ground items, normal AI damage, saved sources and small-window inventory")
 print("COMBO_COMMITS ",JSON.stringify(commits))
 quit(0 if failures.is_empty() else 1)
