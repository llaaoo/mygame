extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 var fixture:=Fixture.new(self)
 var game: GrayriverGame=await fixture.boot(true)
 var actor:=game.player; var manager:=actor.skill_manager
 game.progress.actions["water_call"]=true; game._apply_knowledge()
 var water:=manager.pool.get_skill("water_call")
 manager.equip_source("left",water); manager.equip_source("quick_e",water)
 var left:=manager.get_instance("left")
 var stock:=game.session.inventory
 stock.receive("player","frost_salt",2); stock.receive("player","storm_dust",2)
 # Old global compatibility state must not override explicit per-slot choices.
 manager.combinations.supplies.configure("water_call","venom_extract")
 check(QuickslotMaterials.select(actor,"left",{"payload":"","modifier":"frost_salt","uid":""}),"Water modifier could not be selected per slot")
 check(QuickslotMaterials.select(actor,"quick_e",{"payload":"","modifier":"storm_dust","uid":""}),"Second water source could not select a different modifier")
 var frost:=manager.preview_source("left")
 var storm:=manager.preview_source("quick_e")
 check(frost.ready and storm.ready and frost.material_costs=={"frost_salt":1} and storm.material_costs=={"storm_dust":1} and frost.cost==7 and storm.cost==9,"Basic action slot choices shared global material or wrong costs")
 check("ice" in frost.skill.surface_payload_tags and "lightning" in storm.skill.surface_payload_tags,"Water variants lost their actual surface behavior")
 var before:=stock.count("player","frost_salt")
 var point:=actor.position+Vector2(90,0)
 check(manager.use_source("left",actor,CastContext.at_position(actor,point,water)),"Per-slot ice water cast refused")
 manager.combinations.tick(1)
 for i in range(4): await process_frame
 check(stock.count("player","frost_salt")==before-1 and stock.count("player","storm_dust")==2 and SurfaceManager.instance.surface_at(point).state=="frozen","Per-slot cast paid the other slot or failed to create real ice")
 check(manager.get_instance("left")==left,"Changing only material rebuilt the skill instance")
 check(QuickslotMaterials.select(actor,"left",{"payload":"","modifier":"","uid":""}),"Explicit no-modifier selection refused")
 check(manager.preview_source("left").material_costs.is_empty() and manager.preview_source("quick_e").material_costs=={"storm_dust":1},"No-modifier choice inherited global selection or changed another slot")
 var binding:=manager.shortcuts.snapshot()
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true)
 check(game.player.skill_manager.shortcuts.snapshot()==binding,"Basic modifier choices did not survive real save/re-entry")
 check(game.player.skill_manager.preview_source("left").material_costs.is_empty() and game.player.skill_manager.preview_source("quick_e").material_costs=={"storm_dust":1},"Reload fell back to old global material state")
 await fixture.close()
 if failures.is_empty(): print("PASS slot materials: basic-action modifiers, independent sources, actual ice/payment, explicit no-material option, instance preservation and real save/re-entry")
 quit(0 if failures.is_empty() else 1)
