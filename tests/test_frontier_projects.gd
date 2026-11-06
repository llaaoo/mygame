extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var errors: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: errors.append(message); push_error(message)
func frames(n:=3) -> void:
 for i in range(n): await process_frame
func run() -> void:
 var fixture:=Fixture.new(self)
 var game:=await fixture.boot(true)
 var camp_id: String="river.enemy.camp.bridge_keeper"
 # Migrate a pre-upgrade save in which the story actor was already defeated.
 game.progress.claims[camp_id]=true
 await fixture.travel("river_mine")
 check(game.progress.claims.has("river.bridge_settled"),"Legacy defeated character left an impossible story objective")
 var exit: ExplorationExitData=game.current_data.exits[1]
 check(not exit.claims_satisfied(game.progress),"Side tunnel opened before reconstruction")
 var site: DeliverySiteData=game.current_data.delivery_sites[0]
 var node: ExplorationInteractable
 for child in game.region_root.get_children():
  if child is ExplorationInteractable and child.title==site.title: node=child
 game.player.position=node.position
 game.survival.supplies.grant({"charcoal":2,"crystal":1})
 game.deliveries.inspect(node,site)
 var work:=game.player.field_work
 # The clickable button invokes the same timed, interruptible operation.
 work.panel.start_button.pressed.emit()
 check(work.is_busy(),"Clicking work start did not start the live operation")
 game.player.position+=Vector2(30,0)
 work.tick(.1)
 check(not work.is_busy() and game.survival.supplies.count("charcoal")==2 and not game.progress.claims.has(site.id),"Interrupted reconstruction spent material or unlocked passage")
 game.player.position=node.position
 game.deliveries.inspect(node,site)
 work.panel.start_button.pressed.emit()
 work.tick(4)
 check(exit.claims_satisfied(game.progress) and game.survival.supplies.count("crystal")==0,"Reconstruction did not consume actual material or unlock exit")
 game._use_exit(exit)
 await frames(6)
 check(game.region_id=="camp" and game.player.position.distance_to(Vector2(1100,-2050))<1,"Tunnel did not reach actual lake shore")
 var beacon: SpellWorldObject
 for child in game.region_root.get_children():
  if child is SpellWorldObject and child.spec.id=="river.north_beacon": beacon=child
 check(not game.progress.claims.has("river.north_beacon"),"Beacon auto-completed")
 SurfaceManager.instance.force_set_surface(SurfaceManager.cell_at(beacon.position),"burning",5,"project_test")
 beacon.tick(1)
 check(not beacon.completed,"Beacon accepted less than authored fire hold")
 beacon.tick(1)
 check(beacon.completed and game.progress.claims.has("river.north_beacon"),"Actual sustained fire did not relight beacon")
 var station: SurvivalStationData
 for candidate in game.current_data.survival_stations:
  if candidate.id=="river.north_cook": station=candidate
 check(station!=null and game.region_root.get_children().any(func(child): return child.has_meta("survival_station") and child.get_meta("survival_station")==station),"Relit beacon did not mount the usable camp pot")
 check(not beacon.finish("beacon_fuel"),"Relit beacon completed twice")
 # New cast preference changes press/release handling, never prepares combinations.
 game.ui.close_modal()
 game.player.field_work.close_panel()
 var controller:=game.player.input_controller
 FrontierControls.quick_cast=true
 Input.action_press("skill")
 var actions: Array[Action]=[]
 controller._poll_universal_cast(actions,"right","skill")
 check(actions.size()==1 and actions[0].params.quick_cast and not actions[0].cast_context.empower,"Quick casting did not preserve explicit empowerment")
 Input.action_release("skill")
 await frames()
 FrontierControls.quick_cast=false
 Input.action_press("skill")
 actions.clear()
 controller._poll_universal_cast(actions,"right","skill")
 check(actions.size()==1 and not actions[0].params.quick_cast,"Release-to-cast preference ignored")
 Input.action_release("skill")
 await frames()
 FrontierControls.quick_cast=true
 game._save_progress()
 game.progress.story_actors.clear()
 game.reload_progress()
 await frames(8)
 check(game.progress.claims.has("river.mine_shore") and game.progress.claims.has("river.north_beacon"),"F9 lost permanent construction outcomes")
 await fixture.close()
 if errors.is_empty(): print("PASS frontier projects: legacy migration, pointer work, real fire, permanent shortcut/pot, cast preference and F9")
 quit(0 if errors.is_empty() else 1)
