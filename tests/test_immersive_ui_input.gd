extends "res://tests/test_ui_vertical_input.gd"
## Controlled positions/stock/corpse/exposure; real inputs, normal AI and saved UID state.
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 GameRuntime.instance.set_process(true)
 for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; var store:=game.session.inventory
 var handbook:=game.catalog.fact("river.handbook").definition as ExplorationDiscoveryData
 actor.position=handbook.pos+Vector2(0,30); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await tap(KEY_F); await frames(6)
 verify(game.progress.claims.has(handbook.id) and is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("inspection",false),"F reading did not preserve discovery and use a lightweight drawer")
 if not is_instance_valid(game.ui.modal): await fixture.close(); quit(1); return
 for extent in [Vector2i(960,540),Vector2i(1440,900)]:
  root.content_scale_size=extent; root.size=extent; GameUIStyle.set_text_scale(1.25,root); await frames(8)
  var panel:=game.ui._modal_panel
  verify(root.get_visible_rect().encloses(panel.get_global_rect()) and panel.size.x<extent.x*.46,"Reading drawer crowds the world or leaves the viewport")
  verify(not panel.get_global_rect().has_point(actor.get_global_transform_with_canvas().origin),"Reading panel covers the player's actual screen position")
  var clock:=store.clock_seconds; await frames(12)
  verify(not paused and actor.ui_blocked and store.clock_seconds>clock,"Light reading changed simulation or lost input ownership")
  var reading:=panel.find_child("InspectionReading",true,false) as ScrollContainer
  await point_click(reading.get_global_rect().get_center())
  var before_scroll:=reading.scroll_vertical
  var overflowing:=reading.get_v_scroll_bar().max_value>reading.size.y+1
  if extent.y==540: verify(overflowing,"The small-window fixture no longer exercises overflow reading")
  await pointer_button(MOUSE_BUTTON_WHEEL_DOWN,true); await pointer_button(MOUSE_BUTTON_WHEEL_DOWN,false); await frames(4)
  verify(reading.scroll_vertical>before_scroll if overflowing else reading.scroll_vertical==0,"Mouse wheel cannot scroll overflow or shifts fully visible reading")
  await capture("reading-"+str(extent.x))
 await tap(KEY_TAB)
 verify(root.gui_get_focus_owner()!=null and game.ui.modal.is_ancestor_of(root.gui_get_focus_owner()),"Reading keyboard focus escapes into world controls")
 await focus_back()
 verify(root.gui_get_focus_owner()!=null and game.ui.modal.is_ancestor_of(root.gui_get_focus_owner()),"Reverse focus escapes the lightweight modal")
 var sequence:=actor.actor_context.actions._attack_sequence
 await point_click(Vector2(100,root.get_visible_rect().size.y*.7)); await frames(5)
 verify(not is_instance_valid(game.ui.modal) and not actor.ui_blocked and sequence==actor.actor_context.actions._attack_sequence,"Outside dismissal leaked a weapon gesture")
 await tap(KEY_F); await frames(4)
 actor.health_component.health_changed.emit(actor.health_component.hp,actor.health_component.max_hp); await frames(2)
 verify(is_instance_valid(game.ui.modal),"A cap/health refresh was mistaken for accepted damage")
 actor.take_damage(1); await frames(3)
 verify(not is_instance_valid(game.ui.modal) and not actor.ui_blocked,"Real damage did not return light inspection to the world")
 actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
 var guard: Enemy
 for enemy in game.active_enemies:
  if enemy.get_meta("frontier_claim","")=="river.enemy.camp.forest.3": guard=enemy; break
 verify(guard!=null,"Corpse fixture could not find its actual original wearer")
 if not guard: await fixture.close(); quit(1); return
 var source_id:=str(guard.get_meta("frontier_claim"))
 var weapon:=str(store.equipped(source_id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
 var coat:=str(store.equipped(source_id).get(str(EquipmentData.SlotType.CHEST),""))
 store.set_properties(weapon,{"coating":{"id":"fire_rag","expires_at":store.clock_seconds+600}})
 guard.position=actor.position+Vector2(0,35); guard.take_damage(1000); await frames(8)
 verify(weapon in game.loot.corpses[source_id].gear.display_uids and coat in game.loot.corpses[source_id].gear.display_uids,"Corpse lost its actual worn UID projection")
 await tap(KEY_F); await frames(8)
 verify(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("quick_loot","")==source_id,"F did not open the real corpse in quick loot")
 await capture("quick-loot")
 var held_button:=button_by_identity({"ui_action":"quick_take","item_uid":weapon})
 await create_timer(1.2).timeout
 verify(is_instance_valid(held_button) and held_button==button_by_identity({"ui_action":"quick_take","item_uid":weapon}),"A coating timer tick replaces a live quick-loot target")
 await click_identity({"ui_action":"quick_take","item_uid":weapon}); await frames(6)
 verify(store.locate(weapon)=="player.pack" and not store.coating_state(weapon).is_empty(),"Quick loot lost the selected weapon UID/coating or took a different item")
 var coat_source:=store.locate(coat); var original_coat:=store.item(coat).snapshot()
 store.receive_into("player.pack","water_sprayer",100); await frames(4)
 await tap(KEY_T); await frames(5)
 verify(store.locate(coat)==coat_source and store.item(coat).snapshot()==original_coat,"A full pack removed or replaced uncollected armor")
 store.remove_from("player.pack","water_sprayer",1); await frames(4)
 await click_identity({"ui_action":"quick_take","item_uid":coat}); await frames(6)
 verify(store.locate(coat)=="player.pack","Quick loot did not recover the same armor after making space")
 await tap(KEY_ESCAPE); await tap(KEY_I); await select_item(weapon); await click("装备这件"); await frames(6)
 await capture("illustrated-weapon")
 await select_item(coat); await click("装备这件"); await frames(6)
 var screen:=game.inventory_screen
 verify(weapon in screen._portrait._visual.display_uids and coat in screen._portrait._visual.display_uids,"Inventory character does not show real recovered equipment")
 verify(screen._item_art.uses_illustration and screen._item_art.texture is AtlasTexture,"Selected coat does not use its dedicated illustration cell")
 await capture("illustrated-equipment")
 await tap(KEY_ESCAPE)
 var buffs:=actor.get_node("BuffManager") as BuffManager
 buffs.buildup.add(WeaponEnchantment.definition("venom"),40)
 var burning:=WeaponEnchantment.definition("flame").status.duplicate() as Buff
 burning.duration=30 # Controlled display fixture, long enough for native captures.
 buffs.apply_buff(burning)
 var field:=FireSigil.new(); field.caster=actor; field.field_type="fire"; field.position=actor.position+Vector2(0,20); field.configure_budget(90,20)
 game.region_root.add_child(field); actor.skill_manager.combinations.fields.append(field); await frames(10)
 var status:=game.get_node("HUDLayer")._actor_status as ActorStatusView
 verify(status.buildup_label.visible and status.buildup_label.text.contains("未生效") and status.buildup_label.text.contains("中毒"),"Partial exposure is indistinguishable from an active status")
 verify(StatusPresentation.harmful_text(buffs).contains("燃烧") and StatusPresentation.harmful_text(buffs).contains("已生效"),"Active damage-over-time status is missing from the shared status language")
 verify(status.enchantment_label.text.begins_with("涂层") and field._label.text.contains("余能"),"Weapon coating and ground energy are confused with personal buffs")
 for extent in [Vector2i(960,540),Vector2i(1440,900)]:
  root.content_scale_size=extent; root.size=extent; await frames(8)
  var hud:=game.get_node("HUDLayer")
  var resources:=hud.get_node("MarginContainer/HUDRoot/StatusPanel") as Control
  var effects:=hud.get_node("MarginContainer/HUDRoot/RightStatusStack") as Control
  verify(not resources.get_global_rect().intersects(hud.skill_bar.get_parent().get_global_rect()) and not effects.get_global_rect().intersects(resources.get_global_rect()),"Live exposure/coating/status widgets overlap resources or quickslots")
  var active:=hud.buff_ui as BuffStatusUI
  verify(active.is_visible_in_tree() and root.get_visible_rect().encloses(active.get_global_rect()),"Active status icons are hidden or positioned outside the world HUD")
  var prompt:=game.frontier_hud.interact.get_parent() as Control
  if prompt.is_visible_in_tree() and hud.skill_bar._hint_panel.is_visible_in_tree(): verify(not prompt.get_global_rect().intersects(hud.skill_bar._hint_panel.get_global_rect()),"Nearby interaction hides the selected spell form/cost")
  print("STATUS_LAYOUT ",str(extent)," resources=",resources.get_global_rect()," stack=",effects.get_global_rect()," buffs=",active.get_global_rect()," visible=",active.is_visible_in_tree()," entries=",active._rows.size())
  await capture("combat-status-"+str(extent.x))
 var before:=field.remaining
 verify(field.consume(actor,field.revision,123456),"Controlled field trigger could not consume its original budget")
 await frames(4)
 verify(field.remaining<before-20 and field._label.text.contains(str(ceili(field.remaining))),"Field display did not follow trigger consumption plus natural expiry")
 buffs.remove_status("burning")
 await tap(KEY_I); await select_item(weapon); await click("更多"); await click("丢弃整叠"); await frames(6)
 var ground_id:=store.locate(weapon)
 verify(ground_id in store.ground_ids(game.region_id) and not store.coating_state(weapon).is_empty(),"Dropping the shown weapon lost its actual identity or coating")
 await tap(KEY_ESCAPE); await capture("ground-item")
 await tap(KEY_F); await frames(5)
 verify(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("quick_ground","")==ground_id,"Ground item F still forces full inventory management")
 await capture("quick-ground")
 store.remove_from("player.pack","water_sprayer",1)
 await click_identity({"ui_action":"quick_take","item_uid":weapon}); await frames(6)
 verify(store.locate(weapon)=="player.pack","Quick ground recovery changed or lost the original weapon")
 if is_instance_valid(game.ui.modal): await tap(KEY_ESCAPE)
 var saved:=store.item(weapon).snapshot(); var armor:=store.item(coat).snapshot()
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true)
 verify(game.session.inventory.item(weapon).snapshot()==saved and game.session.inventory.item(coat).snapshot()==armor,"Cold reentry replaced illustrated item identities, upgrades or coating deadlines")
 await fixture.close()
 var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
 if not output.is_empty():
  var file:=FileAccess.open(output.path_join("immersive-ui.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Controlled positions, moved/fatally damaged original wearer, stock, exposure and field; real keyboard/pointer, normal AI/time, actual UID transfers and cold reentry. Not a natural playthrough."},"  "))
 if failures.is_empty(): print("PASS immersive UI: %d checks, light reading/loot/ground, actual damage dismissal, source capacity and UID/coating, dedicated illustrations, real wear and distinct exposure/status/coating/field budget, disk reentry"%checks)
 quit(0 if failures.is_empty() else 1)
