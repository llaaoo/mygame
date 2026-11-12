extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var errors: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: errors.append(message); push_error(message)
func frames(n:=3) -> void:
 for i in range(n): await process_frame
func check_preset_boss(game: GrayriverGame,expected_hp: int,stage: String) -> Enemy:
 var boss:=game.session.actor_for_id("river.enemy.river_prison.river_prison.3") as Enemy
 check(is_instance_valid(boss),"Missing preset prison boss: "+stage)
 if not is_instance_valid(boss): return null
 check(boss.character_definition==null and boss.get_node_or_null("ManaComponent")==null,"Preset boss acquired a shared body template/capability: "+stage)
 check(boss.max_hp==280 and boss.health_component.max_hp==280 and boss.attack_damage==15 and is_equal_approx(boss.move_speed,90),"Preset boss lost its encounter-authored HP/damage/speed: "+stage)
 check(boss.health_component.hp==expected_hp,"Preset boss lost its actual wounded HP: "+stage)
 return boss
func run() -> void:
 var fixture:=Fixture.new(self)
 var game:=await fixture.boot(true)
 var bridge:=game.stories.actors["river.enemy.camp.bridge_keeper"] as Enemy
 game.player.position=bridge.position+Vector2(25,0)
 check(bridge.story_truce and bridge._get_current_target()==null,"Named character attacks before player can negotiate")
 check(not game.stories.act(bridge,"evidence"),"Evidence bypass accepted")
 game.survival.supplies.grant({"ration":3})
 var before:=game.survival.supplies.count("ration")
 var stock:=bridge.skill_manager.combinations.supplies.count("ration")
 check(game.stories.act(bridge,"food"),"Real food toll rejected")
 check(game.survival.supplies.count("ration")==before-1 and bridge.skill_manager.combinations.supplies.count("ration")==stock+1,"Toll not conserved across both inventories")
 check(game.progress.claims.has("river.bridge_settled") and not game.active_enemies.has(bridge),"Peace left hostile threat or missing outcome")
 check(not game.stories.act(bridge,"food"),"Repeat settlement charged again")
 check(game.equipment_service.count("river_sabre")==0,"Diplomacy conjured equipment")
 game.ui.close_modal()
 game.guidance.pin("river_road_people")
 var progress:=game.progress.serialize_save_data()
 check(game.progress.validate_save_data(progress),"New campaign state fails save validation")
 var bad:=progress.duplicate(true)
 bad.story_actors["river.enemy.camp.bridge_keeper"].materials.ration=-1
 check(not game.progress.validate_save_data(bad),"Corrupt NPC stock accepted")
 await fixture.travel("river_mine")
 var mine:=game.stories.actors["river.enemy.river_mine.quartermaster"] as Enemy
 game.player.position=mine.position+Vector2(25,0)
 game.survival.supplies.grant({"ration":8})
 var crystal:=game.survival.supplies.count("crystal")
 check(game.stories.act(mine,"trade") and game.stories.act(mine,"trade") and not game.stories.act(mine,"trade"),"Trade did not exhaust actual stock")
 check(game.survival.supplies.count("crystal")==crystal+2,"Trade generated wrong quantity")
 game.ui.close_modal()
 await fixture.travel("camp")
 bridge=game.stories.actors["river.enemy.camp.bridge_keeper"]
 check(bridge.story_truce and not game.active_enemies.has(bridge) and bridge.skill_manager.combinations.supplies.count("ration")==stock+1,"Peace/toll refilled or reset on region return")
 await fixture.travel("river_mine")
 mine=game.stories.actors["river.enemy.river_mine.quartermaster"]
 game.player.position=mine.position
 check(mine.skill_manager.combinations.supplies.count("crystal")==0 and not game.stories.act(mine,"trade"),"Travel replenished trader stock")
 check(not game.stories.act(mine,"evidence"),"Empty stock paid a second claim")
 # Player chose trading instead of reclaiming: battle remains a possible resolution.
 check(game.stories.act(mine,"fight"),"Explicit hostility rejected")
 mine.take_damage(9999)
 await frames()
 var corpse: Dictionary=game.progress.loot_records["river.enemy.river_mine.quartermaster"]
 check(not corpse.materials.has("crystal") and corpse.materials.ration==4,"Traded stock refilled on death or real payment vanished")
 check(game.progress.claims.has("river.mine_settled"),"Combat path did not settle quest")
 game.loot.inspect("river.enemy.river_mine.quartermaster")
 await frames()
 var cast_count: Array[int]=[0]
 game.player.skill_manager.equip_slot(0,game.player.skill_manager.pool.get_skill("ignite"))
 game.player.skill_manager.cast_committed.connect(func(_plan): cast_count[0]+=1)
 var key:=InputEventKey.new()
 key.keycode=KEY_E; key.physical_keycode=KEY_E; key.pressed=true
 Input.parse_input_event(key); await frames()
 check(cast_count[0]==0 and game.equipment_service.count("river_survey_spear")==0,"E cast or took loot through modal ownership")
 key=key.duplicate(); key.pressed=false; Input.parse_input_event(key); await frames()
 key=InputEventKey.new()
 key.keycode=KEY_T
 key.physical_keycode=KEY_T
 key.pressed=true
 Input.parse_input_event(key)
 await frames()
 check(game.equipment_service.count("river_survey_spear")==1,"T failed to retrieve loot through live modal input ownership")
 key.pressed=false
 Input.parse_input_event(key)
 game.ui.close_modal()
 await fixture.travel("river_prison")
 var preset_boss:=check_preset_boss(game,280,"first visit")
 if is_instance_valid(preset_boss):
  preset_boss.take_damage(40)
  check(preset_boss.health_component.hp==240,"Preset boss fixture did not take real damage")
 var veteran:=game.stories.actors["river.enemy.river_prison.veteran"] as Enemy
 game.player.position=veteran.position
 check(not game.stories.act(veteran,"surrender"),"Healthy veteran surrendered without condition")
 veteran.health_component.hp=1
 check(game.stories.act(veteran,"surrender") and not veteran.rewards_enabled,"Wounded surrender did not resolve combat")
 game.ui.close_modal()
 await fixture.travel("camp",Vector2(-3500,2100))
 for tab in FrontierHub.TABS:
  game.hub.open(tab)
  await frames()
  if tab in ["equipment","supplies"]:
   check(game.inventory_screen.visible and game.inventory_screen.mode==tab and game.player.ui_blocked and not paused,"Unified inventory route missing: "+tab)
   check(game.inventory_screen._portrait.size.x>=240 and game.inventory_screen._grid.size.x>100,"Paper doll / inventory columns collapsed")
  else:
   check(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("frontier_page")==tab,"Hub tab missing: "+tab)
   check(game.hub._rows.size.x>100 and game.hub._detail.size.x>100,"Hub columns collapsed")
 game.hub.open("equipment")
 game.inventory_screen._search.text="不可能匹配的物品"
 await frames(20)
 check(game.inventory_screen._rows().is_empty(),"Search retained mismatched physical inventory")
 game.inventory_screen.close()
 # Searchable UI and old modal can replace each other without stale resize callbacks.
 game.show_map()
 await frames()
 var map:=game.ui.modal.find_children("*","Control",true,false).filter(func(node): return node is GrayriverMap)[0] as GrayriverMap
 var point:=Vector2(1000,-2000)
 check(map.unproject(map.project(point)).distance_to(point)<.01,"Map projection does not invert")
 game.guidance.set_waypoint(point)
 check(game.guidance.tracked().position==point,"Waypoint not tracked")
 game.ui.close_modal()
 game.player.input_controller.request_shortcut("item_0",true)
 check(game.player.field_work.is_busy(),"Quick supply belt did not start interruptible eating")
 game.player.field_work.cancel("test")
 game.player.field_work.close_panel()
 # Save and boot into the same persistent campaign: finite stock and choices survive.
 game._save_progress()
 await fixture.close()
 game=await fixture.boot(true)
 check(game.progress.tracked_quest=="river_road_people" and not game.progress.waypoint.is_empty(),"Tracking preferences lost on reload")
 await fixture.travel("river_prison")
 check_preset_boss(game,240,"cold save/reentry")
 veteran=game.stories.actors["river.enemy.river_prison.veteran"]
 check(veteran.story_truce and veteran.health_component.hp==1 and not game.active_enemies.has(veteran),"Reload forgot wounded survivor or peace")
 game.player.position=veteran.position
 check(game.stories.act(veteran,"fight"),"Survivor could not be deliberately antagonized")
 await fixture.travel("camp")
 await fixture.travel("river_prison")
 check_preset_boss(game,240,"region return after betrayal")
 veteran=game.stories.actors["river.enemy.river_prison.veteran"]
 check(not veteran.story_truce and not veteran.rewards_enabled and game.active_enemies.has(veteran),"Betrayal reload restored rewards or lost hostility")
 await fixture.close()
 if errors.is_empty(): print("PASS frontier expedition: diplomacy, conserved stock, save/load, hub and guidance")
 quit(0 if errors.is_empty() else 1)
