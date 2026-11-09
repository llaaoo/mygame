extends SceneTree
## Controlled contracts, including reverse-order evidence and real save/reentry.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var game: GrayriverGame
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 var catalog:=game.catalog
 var note:=catalog.fact("river.fire").definition as ExplorationDiscoveryData
 var before:=game.progress.serialize_save_data()
 check("东北方向" in catalog.discovery_text(note,game.progress),"Fire note sends player away from real archive entrance")
 var exit: ExplorationExitData=catalog.regions.camp.exits.filter(func(e): return e.target=="river_archive")[0]
 var original:=exit.pos; exit.pos=note.pos+Vector2(-500,0)
 check("西方向" in catalog.discovery_text(note,game.progress),"Navigation copied a direction instead of following the real passage")
 exit.pos=original
 check("东北方向" in catalog.record_text({"id":note.id,"text":"旧窖在西边"},game.progress) and game.progress.serialize_save_data()==before,"Old journal direction stayed stale or query mutated progress")
 note.navigation_hints[0].target_region="missing_region"
 var errors:=ExplorationContentValidator.new().validate(catalog)
 check(errors.any(func(e): return "Unknown navigation region" in e),"Invalid content reference accepted")
 note.navigation_hints[0].target_region="river_archive"
 var guard: ExplorationEncounterData=catalog.regions.camp.encounters.filter(func(e): return e.pos.distance_to(note.pos)<1000)[0]
 var post:=guard.pos; guard.pos=note.pos+Vector2(500,0)
 errors=ExplorationContentValidator.new().validate(catalog)
 check(errors.any(func(e): return "Reading interaction overlaps" in e),"Unsafe teaching placement accepted")
 guard.pos=post
 var seal:=catalog.fact("demo.bell.seal").definition as SpellPuzzleData
 var cleanser:=catalog.fact("demo.bell.cleanser").definition as SpellPuzzleData
 var needs:=game.progress.condition_query.claims_reason(seal.required_claims)
 check(cleanser.title in needs and not "图纸" in needs,"Missing mechanism misreported as blueprint")
 var prior:=cleanser.required_claims; cleanser.required_claims=PackedStringArray([seal.id])
 errors=ExplorationContentValidator.new().validate(catalog)
 check(errors.any(func(e): return "Cyclic objective prerequisite" in e),"Cyclic gate was not rejected")
 cleanser.required_claims=prior
 var next:=game.guidance.prerequisite_objective(seal.id)
 check(next.title==cleanser.title,"Quest guidance skipped blocked mechanism prerequisite")
 var quest: ExplorationQuestData=game.quests.filter(func(q): return q.id=="river_bell_inquiry")[0]
 check(quest.stage(game.progress)==ExplorationQuestData.Stage.UNDISCOVERED,"Unseen quest spoiled")
 await fixture.travel("river_bell")
 var entry:=catalog.fact("demo.bell.entry").definition as ExplorationDiscoveryData
 check(game.progress_service.discover(entry) and quest.stage(game.progress)==ExplorationQuestData.Stage.ACTIVE,"Local exploration failed to introduce quest")
 for id in ["demo.bell.cleanser","demo.bell.seal"]:
  var spec:=catalog.fact(id).definition as SpellPuzzleData
  var node: SpellWorldObject
  for child in game.region_root.get_children():
   if child is SpellWorldObject and child.spec==spec: node=child
  game.player.position=spec.pos-Vector2(40,0)
  game.survival.supplies.grant(spec.work_methods[0].material_costs)
  game.field_sites.inspect(node)
  check(game.player.field_work.start_selected(),"Paid timed work refused "+id)
  game.player.field_work.tick(spec.work_methods[0].duration)
  check(node.completed,"Timed work failed to commit "+id)
  game.player.field_work.close_panel(); game.ui.close_modal()
 await fixture.travel("river_bell_depths")
 check(game.progress_service.discover(catalog.fact("demo.bell.receipt").definition),"Receipt discovery failed")
 var core:=catalog.fact("demo.bell.core").definition as SpellPuzzleData
 game.survival.supplies.grant(core.work_methods[0].material_costs)
 check(game.progress_service.solve_puzzle(core,core.work_methods[0].id),"Core refused earned prerequisite")
 check(not game.progress.claims.has("demo.watch.signal") and quest.stage(game.progress)==ExplorationQuestData.Stage.READY and quest.title in game.progress_service.quest_feedback(core.id),"Reverse-order completion hidden behind unrelated introduction")
 check(game.hub.entries().any(func(e): return e.id==quest.id),"Ready quest missing from journal")
 await fixture.travel("camp",Vector2(-2900,2200))
 check(game.progress_service.claim_quest(quest) and not game.progress_service.claim_quest(quest),"Earned report refused or duplicated")
 game._save_progress(); await fixture.close(); game=await fixture.boot(true)
 quest=game.quests.filter(func(q): return q.id=="river_bell_inquiry")[0]
 check(quest.stage(game.progress)==ExplorationQuestData.Stage.REPORTED and not game.progress_service.claim_quest(quest) and not game.progress.claims.has("demo.watch.signal"),"Reentry lost report, duplicated reward or fabricated prerequisite")
 await fixture.close()
 if failures.is_empty(): print("PASS world feedback: reference-based navigation, old journal rendering, unsafe placements and cycles rejected, named prerequisites, reverse-order paid puzzle path, report once and disk reentry")
 quit(0 if failures.is_empty() else 1)
