extends "res://tests/support/input_scene_probe.gd"
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
## Real selector/rest controls; normal AI with explicitly staged position, knowledge and stock.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var casts := 0
func move_pointer(point: Vector2) -> void:
 var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point
 root.push_input(event,true); await frames(2)
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; var manager:=actor.skill_manager; var store:=game.session.inventory
 actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing(); await frames(6)
 manager.equip_source("right",manager.pool.get_skill("ignite"),{"payload":"","modifier":"","uid":""})
 manager.cast_committed.connect(func(_plan): casts+=1)
 var stock:=store.material_amounts("player"); var mp:=actor.mana_component.mp
 var attack:=actor.actor_context.actions._attack_sequence
 await key(KEY_G,true); await key(KEY_G,false); await key(KEY_R,true); await key(KEY_R,false)
 var wheel:=actor.material_wheel
 check(wheel.visible and wheel._compact_mode and not wheel._ring.visible and wheel.entries.size()==1,"One legal form did not open a compact manual selector")
 check(not wheel.selector_rect().intersects(wheel._detail_host.get_global_rect()),"Compact details cover the selected form")
 await capture("compact-single-form")
 await point_click(wheel.entry_point(0))
 check(not wheel.visible and casts==0 and store.material_amounts("player")==stock and actor.mana_component.mp==mp and actor.actor_context.actions._attack_sequence==attack,"Compact confirmation cast, paid or leaked an attack")
 # A held form whose readiness disappears must retain its place and reject release.
 await pointer_button(MOUSE_BUTTON_MIDDLE,true); await key(KEY_R,true); await key(KEY_R,false)
 await move_pointer(wheel.entry_point(0))
 var selection:=manager.shortcuts.selection("right")
 actor.mana_component.mp=0
 await create_timer(.3).timeout; await frames(2)
 check(wheel._compact_mode and wheel.page_size()==1 and wheel.entries[0].is_empty() and wheel.hovered==-1,"Losing readiness changed compact layout or substituted a form")
 await pointer_button(MOUSE_BUTTON_MIDDLE,false)
 check(not wheel.visible and manager.shortcuts.selection("right")==selection and casts==0,"Held stale compact release changed the selection or cast")
 actor.mana_component.mp=actor.mana_component.max_mp
 # More choices retain the radial presentation, even after live stock loss.
 game.progress.actions["fire_sigil"]=true; game._apply_knowledge()
 manager.equip_source("left",manager.pool.get_skill("inscribe"))
 for id in ["fire_stone","frost_salt","storm_dust"]: store.receive_into("player.pocket",id,1)
 await key(KEY_G,true); await key(KEY_G,false); await key(KEY_Q,true); await key(KEY_Q,false)
 check(wheel.entries.size()>=4 and not wheel._compact_mode and wheel._ring.visible,"Four legal forms did not retain the radial selector")
 var lost:=-1
 for i in range(wheel.entries.size()):
  if wheel.entries[i].get("choice",{}).get("payload","")=="frost": lost=i
 check(lost>=0,"Actual frost material missing from radial choices")
 if lost>=0:
  await move_pointer(wheel.entry_point(lost)); store.pay("player",{"frost_salt":1})
  await create_timer(.3).timeout; await frames(2)
  check(not wheel._compact_mode and wheel.entries[lost].is_empty() and wheel.hovered==-1,"Readiness loss rebuilt the radial layout beneath a pointer")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Rest presents game time and interruptible preparation separately; its rules are opt-in.
 actor.position=Vector2(-3500,2100); actor.get_node("Camera2D").reset_smoothing(); await frames(6)
 var clock:=store.clock_seconds
 await key(KEY_F,true); await key(KEY_F,false)
 var panel:=actor.field_work.panel
 check(panel.visible and panel._summary.text.contains("1 小时（游戏时间）") and panel._preparation.text.contains("准备") and panel._preparation.text.contains("秒"),"Rest hides game hours behind preparation seconds")
 check(panel.start_button.disabled and panel._reason.text.begins_with("无法开始：") and not panel.text.visible,"Missing rest supplies were not clear or detailed rules opened by default")
 await capture("rest-summary")
 await point_click(panel.details_toggle.get_global_rect().get_center())
 check(panel.text.visible and panel.details_toggle.button_pressed,"Real detailed-rules toggle did not expand the rest explanation")
 await frames(8)
 check(store.clock_seconds>clock and not paused and casts==0,"Selector/rest controls paused simulation or cast")
 await capture("rest-time-and-supplies")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 await key(KEY_K,true); await key(KEY_K,false)
 var labels:=actor.skill_pool_ui._skill_grid.find_children("*","Label",true,false)
 check(labels.any(func(label):return label.text.contains("MP")) and not labels.any(func(label):return label.text.contains("0 路")),"Loadout cards show empty upgrade-route counts instead of useful costs")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Explicitly stage a narrow logical canvas, independently of OS window scaling.
 # Standalone native execution also proves the requested physical window can resize.
 var original_canvas:=root.content_scale_size
 root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600);await frames(6)
 store.receive_into("player.pocket","frost_salt",1)
 await key(KEY_G,true);await key(KEY_G,false);await key(KEY_Q,true);await key(KEY_Q,false)
 check(not wheel._compact_mode and root.get_visible_rect().encloses(wheel.selector_rect()),"Narrow radial selector escaped the logical viewport")
 check(not wheel.selector_rect().intersects(wheel._source_host.get_global_rect()) and not wheel.selector_rect().intersects(wheel._detail_host.get_global_rect()),"Narrow metadata covers radial choices")
 await capture("radial-narrow")
 await key(KEY_R,true);await key(KEY_R,false)
 check(wheel._compact_mode and root.get_visible_rect().encloses(wheel.selector_rect()),"Narrow compact selector escaped the logical viewport")
 await capture("compact-narrow")
 await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
 root.content_scale_size=original_canvas
 await fixture.close()
 if failures.is_empty(): print("PASS selector feedback input: compact explicit choice, stale held release, radial identity under stock loss, readable live rest timing/cost/rejection and opt-in details, useful loadout cards; controlled knowledge/stock/position")
 quit(0 if failures.is_empty() else 1)
