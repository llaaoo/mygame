extends SceneTree
## Controlled integration: traversal, actual puzzle event/work paths and save
## transactions. This does not measure blind-play time or normal AI difficulty.
const Fixture := preload("res://tests/support/grayriver_fixture.gd")
var game: GrayriverGame
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func site(id: String) -> SpellWorldObject:
 for node in game.region_root.get_children():
  if node is SpellWorldObject and node.spec.id==id: return node
 return null
func read(id: String) -> void:
 for entry in game.current_data.discoveries:
  if entry.id!=id: continue
  game.player.position=entry.pos
  check(game.progress_service.discover(entry), "Discovery failed: "+id)
  return
 check(false,"Missing discovery "+id)
func clear_fixture() -> void:
 for actor in game.active_enemies.duplicate(): actor.take_damage(1000)
func frames() -> void:
 for i in range(5): await process_frame
func run() -> void:
 var invalid:=GrayriverDefinition.data()
 invalid.regions[-1].exits[0]["required_claims"]=["demo.cistern.decision"]
 check(GrayriverValidator.validate(invalid).any(func(e): return "return route must be unconditional" in e),"Locked escape route passed authoring validation")
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 var finale: ExplorationQuestData=game.quests.filter(func(q): return q.id=="river_demo_finale")[0]
 check(not finale.available(game.progress) and not game.hub.entries().any(func(e): return e.id==finale.id),"Unfound finale spoiled new-game quest list")
 read("demo.route_brief")
 check(finale.available(game.progress),"Brief did not unlock expedition")
 await fixture.travel("river_archive"); clear_fixture(); read("demo.dispatch"); read("river.dossier")
 var cases := [
  ["river_watch",["demo.watch.entry"],["demo.watch.windgate"]],
  ["river_watch_vault",["demo.watch.warning"],["demo.watch.relay","demo.watch.signal"]],
  ["river_bell",["demo.bell.entry"],["demo.bell.cleanser","demo.bell.seal"]],
  ["river_bell_depths",["demo.bell.receipt"],["demo.bell.core"]],
  ["river_cistern",["demo.cistern.entry"],["demo.cistern.intake"]],
  ["river_cistern_depths",["demo.cistern.warning"],["demo.cistern.cooler","demo.cistern.lock"]]]
 var used_work:=0; var used_magic:=0
 for row in cases:
  await fixture.travel(row[0]); clear_fixture(); await frames()
  for id in row[1]: read(id)
  for id in row[2]:
   var node:=site(id); check(node!=null,"Missing connected puzzle "+id)
   game.player.position=node.position-Vector2(40,0)
   if used_work<=used_magic:
    var method: FieldWorkMethod=node.spec.work_methods[0]
    game.survival.supplies.grant(method.material_costs)
    var before:=game.session.inventory.material_amounts("player")
    game.field_sites.inspect(node)
    check(game.player.field_work.start_selected(),"Live work refused "+id)
    game.player.field_work.tick(method.duration)
    check(node.completed,"Timed work did not commit "+id)
    for key in method.material_costs:
     check(game.survival.supplies.count(key)<=int(before.get(key,0))-method.material_costs[key]+int(node.spec.materials.get(key,0)),"Work cost missing "+id)
    used_work+=1
   else:
    var route: SpellPuzzleRoute=node.spec.routes[0]
    for tag in route.steps:
     CombatExecutor.report_hit(game.player,node,0,node.position,null,[tag])
    if not route.required_surface.is_empty():
     SurfaceManager.instance.force_set_surface(SurfaceManager.cell_at(node.position),route.required_surface,10)
     node.tick(route.hold_seconds)
    check(node.completed,"Actual hit/surface path failed "+id)
    used_magic+=1
   check(game.progress.claims.has(id),"Puzzle world fact missing "+id)
   check(not game.ui.message.text.contains("营地可直达此处"),"Dungeon stair falsely promised a direct camp shortcut")
   var before_stock:=game.session.inventory.snapshot()
   check(not game.progress_service.solve_puzzle(node.spec,node.spec.work_methods[0].id) and game.session.inventory.snapshot()==before_stock,"Repeated puzzle charged/rewarded "+id)
   game.player.field_work.close_panel(); game.ui.close_modal()
  check(game.current_data.exits.any(func(e): return e.claims_satisfied(game.progress)),"No consumable-free retreat from "+row[0])
 # The final choice cannot be changed for a second consequence/reward.
 var event: ExplorationWorldEventData=game.current_data.events[0]
 check(game.progress_service.choose_world_event(event,event.choices[1]),"Final choice refused")
 check(not game.progress_service.choose_world_event(event,event.choices[0]) and game.progress.claims.has("demo.pressure_contained") and not game.progress.claims.has("demo.water_restored"),"Mutually exclusive outcomes duplicated")
 # Full water capacity keeps reward remainder in a real source with stable UID.
 game.survival.supplies.grant({"clean_water":4})
 game.loot.grant_cache("demo.test_cache","Overflow fixture",game.player.position,{"clean_water":6})
 var cache: Dictionary=game.progress.loot_records["cache.demo.test_cache"]
 check(cache.materials.get("clean_water",0)==6,"Full waterskin destroyed reward")
 var uid: String=game.loot.instance_entries("cache.demo.test_cache")[0].uid
 game.survival.supplies.pay({"clean_water":1}); game.player.position=GrayriverDefinition.vector(cache.position)
 check(game.loot.take("cache.demo.test_cache")==1 and cache.materials.clean_water==5,"Later partial collection lost remainder")
 game._save_progress(); await fixture.close(); game=await fixture.boot(true)
 check(game.region_id=="river_cistern_depths" and game.progress.claims.has("demo.cistern.decision") and game.progress.choices[event.id]=="contain","Save/reentry lost final decision or floor")
 check(game.loot.instance_entries("cache.demo.test_cache")[0].uid==uid and game.progress.loot_records["cache.demo.test_cache"].materials.clean_water==5,"Reentry refilled reward or replaced UID")
 check(game.active_enemies.is_empty(),"Dungeon enemies refilled on save/reentry")
 check(game.guidance.overworld_point("river_watch_vault")==Vector2(1650,-3060) and game.guidance.overworld_point("river_bell_depths")==Vector2(-4160,-900),"Lower floor map marker used local parent coordinates")
 var goal:=game.guidance.objective("demo.watch.signal")
 check(game.guidance.route_target(goal)!=Vector2.INF,"Lower floor has no multi-region route back to other expedition")
 await fixture.travel("camp",Vector2(-2900,2200))
 check(not game.region_root.get_children().any(func(n): return n.has_meta("survival_station") and n.get_meta("survival_station").id=="demo.restored_water"),"Contain branch received restore station")
 check(site("demo.maintenance_cache")!=null,"Contain consequence cache not connected")
 finale=game.quests.filter(func(q): return q.id=="river_demo_finale")[0]
 check(not game.progress_service.claim_quest(finale),"Finale bypassed original prison clear")
 await fixture.travel("river_prison"); clear_fixture(); await frames()
 await fixture.travel("camp",Vector2(-2900,2200))
 check(game.progress_service.claim_quest(finale),"Earned final report refused")
 await frames()
 check(game.progress.claims.has("demo.ending_seen") and is_instance_valid(game.ui.modal),"Final report did not display persistent ending")
 game.ui.close_modal(); game._save_progress(); await fixture.close(); game=await fixture.boot(true)
 check(game.progress.claims.has("demo.ending_seen") and not game.progress_service.claim_quest(finale),"Ending/reward replayed after reentry")
 await fixture.close()
 # Independent fresh campaign exercises the other irreversible consequence.
 for path in ["user://save_3.sav","user://save_3.sav.bak"]:
  DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 game=await fixture.boot(false)
 await fixture.travel("river_cistern_depths"); clear_fixture()
 event=game.current_data.events[0]
 for id in event.required_claims: game.progress.claims[id]=true
 check(game.progress_service.choose_world_event(event,event.choices[0]),"Restore branch refused")
 check(not game.current_data.exits[-1].claims_satisfied(game.progress),"Restore branch also received shortcut")
 await fixture.travel("camp")
 check(game.region_root.get_children().any(func(n): return n.has_meta("survival_station") and n.get_meta("survival_station").id=="demo.restored_water"),"Restore consequence station not mounted")
 await fixture.close()
 if failures.is_empty(): print("PASS Grayriver demo: six connected floors, paid timed work and hit/surface routes, consumable-free retreats, exclusive world outcome, full-capacity UID remainder, persistent clear/ending and multi-floor guidance")
 quit(0 if failures.is_empty() else 1)
