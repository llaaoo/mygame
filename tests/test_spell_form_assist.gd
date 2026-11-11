extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true)
 check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
 var actor:=game.player; var manager:=actor.skill_manager; var store:=game.session.inventory
 var catalog:=SpellOperationCatalog.default_catalog()
 for operation in catalog.operations: game.progress.actions[operation.action.get_id()]=true
 game._apply_knowledge()
 var rune:=catalog.operation("inscribe").action
 var focus:=catalog.operation("attune").action
 var extract:=catalog.operation("extract").action
 var project:=catalog.operation("project").action
 manager.equip_source("left",rune,{"payload":"ember","modifier":"","uid":""})
 manager.equip_source("quick_e",focus,{"mode":"auto"})
 manager.equip_source("right",extract,{"mode":"auto"})
 manager.equip_source("item_0",project,{"mode":"auto"})
 manager.equip_source("item_1",focus,{"payload":"attune_frost","modifier":"","uid":""})
 var instance:=manager.get_instance("quick_e")
 var pinned:=manager.shortcuts.selection("item_1")
 check(manager.spell_forms.affinity.is_empty(),"Fresh game restored a transient element")
 check(not manager.shortcuts.set_selection("quick_e",{"mode":"auto","uid":"item.1"}),"Auto mode accepted a hidden UID override")
 store.receive("player","fire_stone",1)
 var before:=store.count("player","fire_stone")
 check(manager.use_source("left",actor,CastContext.simple(actor,Vector2.RIGHT,rune)),"Manual fire rune refused")
 manager.combinations.tick(1)
 for i in range(5): await process_frame
 check(manager.spell_forms.affinity=="fire" and store.count("player","fire_stone")==before-1,"Only committed casting should set element and pay material")
 check(manager.selection_for_source("quick_e").get("payload","")=="attune_fire" and manager.selection_for_source("right").get("payload","")=="extract_fire" and manager.selection_for_source("item_0").get("payload","")=="charged_fireball","Follow-up operations did not resolve to the fire family")
 check(manager.shortcuts.selection("item_1")==pinned,"Element assistance overwrote a fixed slot")
 check(manager.combinations.fields.size()==1,"Assistance created an extra field")
 var snapshot:=store.snapshot(); var mana:=actor.mana_component.mp
 var cooldowns:=manager.combinations.cooldowns.duplicate(true)
 check(QuickslotMaterials.select(actor,"quick_e",{"payload":"attune_frost","modifier":"","uid":""}),"Manual form override refused")
 check(not manager.preview_source("quick_e").ready and manager.selection_for_source("quick_e").get("payload","")=="attune_frost","Missing frost field silently fell back to available fire")
 check(QuickslotMaterials.select(actor,"quick_e",{"mode":"auto"}),"Could not restore automatic selection")
 check(manager.get_instance("quick_e")==instance and manager.combinations.cooldowns==cooldowns and store.snapshot()==snapshot and actor.mana_component.mp==mana,"Selection consumed resources, rebuilt skill or reset cooldown")
 check(manager.preview_source("quick_e").ready,"Auto fire attunement did not use the real field")
 check(manager.use_source("quick_e",actor,CastContext.simple(actor,Vector2.RIGHT,focus)),"Following attunement refused")
 manager.combinations.tick(1)
 check(actor.get_node("BuffManager").has_buff("ember_focus"),"Following attunement failed to apply its real status")
 # A refused request cannot change the last committed family or create conditions.
 manager.equip_source("slot_1",rune,{"payload":"frost","modifier":"","uid":""})
 store.pay("player",{"frost_salt":store.count("player","frost_salt")})
 check(not manager.use_source("slot_1",actor,CastContext.simple(actor,Vector2.RIGHT,rune)) and manager.spell_forms.affinity=="fire","Refused frost cast changed the committed family")
 var bindings:=manager.serialize_skill_state()
 manager.restore_skill_state(bindings)
 check(manager.spell_forms.affinity.is_empty() and manager.shortcuts.selection("quick_e")=={"mode":"auto"},"In-place load restored a stale element or lost the mode")
 game._save_progress(); var inventory:=store.snapshot()
 await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true)
 manager=game.player.skill_manager
 check(manager.shortcuts.selection("quick_e")=={"mode":"auto"} and manager.shortcuts.selection("item_1")==pinned,"Real save/re-entry lost auto mode or fixed choice")
 check(manager.spell_forms.affinity.is_empty() and manager.combinations.fields.is_empty() and game.session.inventory.snapshot()==inventory,"Re-entry restored transient casting context/fields or refilled materials")
 await fixture.close()
 if failures.is_empty(): print("PASS spell form assist: committed family, independent fixed slots, real field/status/payment, no fallback/reset, validated mode and real save/re-entry")
 quit(0 if failures.is_empty() else 1)
