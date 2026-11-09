extends "res://tests/support/input_scene_probe.gd"
## Controlled fixture; actual input for responsive work, loot and canonical gear.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot()
 game.survival.supplies.grant({"ration":3,"clean_water":3})
 for resolution in [Vector2i(1152,648),Vector2i(960,600),Vector2i(1280,720)]:
  root.size=resolution; await frames(8)
  var rest: ExplorationInteractable
  for node in game.region_root.get_children():
   if node is ExplorationInteractable and node.get_meta("survival_rest",false): rest=node
  check(rest!=null,"Real rest station missing")
  game.player.position=rest.position; await frames()
  await key(KEY_F,true); await key(KEY_F,false)
  var work:=game.player.field_work; var panel:=work.panel
  check(panel.visible,"F failed to inspect rest station")
  panel.display("长说明测试。".repeat(200))
  await frames(8)
  check(root.get_visible_rect().encloses(panel._panel.get_global_rect()),"Work card exceeds viewport "+str(resolution))
  check(panel._panel.get_global_rect().encloses(panel.selector.get_global_rect()) and panel._panel.get_global_rect().encloses(panel.start_button.get_global_rect()),"Long text displaced work controls")
  check(panel._scroll.get_v_scroll_bar().max_value>panel._scroll.size.y,"Work explanation cannot scroll")
  await capture("work-"+str(resolution.x))
  await point_click(panel.start_button.get_global_rect().get_center())
  check(work.is_busy() and not paused,"Mouse start failed or paused world")
  await point_click(panel.cancel_button.get_global_rect().get_center())
  check(not work.is_busy() and not paused,"Mouse cancel failed")
  work.close_panel()
  game.loot.grant_cache("feedback.loot","长帮助文字测试",game.player.position,{"charcoal":1})
  game.hub.open("loot","cache.feedback.loot"); await frames(8)
  var shell: ExpeditionScreen
  for node in game.ui.modal.find_children("*","HBoxContainer",true,false):
   if node is ExpeditionScreen: shell=node
  var footer: VBoxContainer=shell.footer
  var help:=footer.get_child(0) as Label
  var button:=footer.get_child(1) as Button
  check(help.size.x>300 and help.size.y<80 and root.get_visible_rect().encloses(button.get_global_rect()),"Loot helper squeezed to vertical glyphs or hid pickup")
  await capture("loot-"+str(resolution.x))
  await point_click(button.get_global_rect().get_center()); await frames()
  game.ui.close_modal()
 var id: String=game.catalog.equipment.keys()[0]
 check(game.equipment_service.receive(id,1)==1,"Equipment fixture full")
 var uid:=game.session.inventory.find_owned("player",id)
 game.player.position=Vector2(-3300,-1200)
 game.equipment_service.show_detail(id); await frames(8)
 check(game.inventory_screen.visible and game.inventory_screen.selected==uid,"Discovery detail kept a second equipment UI")
 await click("装备这件"); await frames()
 var definition:=game.catalog.equipment[id] as EquipmentData
 check(game.session.inventory.equipped("player").get(str(definition.slot_type),"")==uid,"Safe wilderness gear click failed")
 await capture("canonical-gear")
 game.inventory_screen.close()
 game.inventory_screen.open_item(id,uid); await frames()
 check(game.inventory_screen.selected==uid and game.session.inventory.locate(uid)=="player.gear","Equipment detail lost worn UID")
 var foe: Enemy=game.active_enemies[0]
 var post:=foe.position; foe.position=game.player.position+Vector2(40,0)
 await frames(15)
 var rejected:=game.inventory_actions.unequip_reason(definition.slot_type)
 var before:=game.session.inventory.snapshot()
 var remove: Button
 for node in game.inventory_screen._details.get_children():
  if node is Button and node.text=="卸下装备": remove=node
 check(not rejected.is_empty() and remove.disabled and not game.inventory_actions.unequip(definition.slot_type).accepted and game.session.inventory.snapshot()==before,"Danger preview/commit disagree or rejected gear operation mutates UID")
 foe.position=post; await frames(15)
 check(game.inventory_actions.unequip_reason(definition.slot_type).is_empty(),"Safe gear permission stayed stale")
 game.inventory_screen.close()
 game.inventory_screen.open("all"); game.inventory_screen._search.text="不存在的物品筛选"; game.inventory_screen._invalidate(); await frames(10)
 var empty:=game.inventory_screen._grid.get_node_or_null("EmptyInventory") as Label
 check(empty!=null and empty.size.x>=220 and empty.size.y<80,"Empty inventory became a single-glyph column")
 await capture("empty-inventory")
 game.inventory_screen.close(); await fixture.close()
 if failures.is_empty(): print("PASS feedback input: F rest, live mouse start/cancel, bounded scroll/selector at three resolutions, loot footer, wilderness discovery→physical UID gear UI, readable empty bag")
 quit(0 if failures.is_empty() else 1)
