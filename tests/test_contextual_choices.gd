extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func has(rows: Array[Dictionary],payload: String,modifier := "") -> bool:
	return rows.any(func(row): return row.choice.get("payload","")==payload and row.choice.get("modifier","")==modifier)
func run() -> void:
	var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true)
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	var actor:=game.player; var manager:=actor.skill_manager; var store:=game.session.inventory
	var catalog:=SpellOperationCatalog.default_catalog()
	for operation in catalog.operations: game.progress.actions[operation.action.get_id()]=true
	game.progress.actions["water_call"]=true
	for rule in manager.combinations.rules: game.progress.spell_rules[rule.id]=true
	game._apply_knowledge()
	var rune:=catalog.operation("inscribe").action
	var focus:=catalog.operation("attune").action
	manager.equip_source("left",rune,{"payload":"ember","modifier":"","uid":""})
	manager.equip_source("quick_e",focus,{"mode":"auto"})
	manager.equip_source("slot_1",manager.pool.get_skill("water_call"))
	store.receive_into("player.pocket","fire_stone",2)
	store.receive_into("player.pocket","resin",1)
	store.receive_into("player.pocket","ward_powder",1)
	store.receive_into("player.pocket","frost_salt",2)
	store.receive_into("player.pocket","storm_dust",2)
	var stock:=store.snapshot(); var mana:=actor.mana_component.mp
	var rows:=QuickslotMaterials.usable_options(actor,"left")
	check(has(rows,"arcane") and has(rows,"ember"),"Wheel failed to distinguish free, supplied and missing-material runes")
	check(rows.all(func(row): return row.ready and row.choice.get("mode","")!="auto"),"Catalogue or unavailable form leaked into combat choices")
	check(store.snapshot()==stock and actor.mana_component.mp==mana,"Readiness query consumed a resource")
	check(manager.use_source("left",actor,CastContext.simple(actor,Vector2.RIGHT,rune)),"Real fire rune preparation refused")
	manager.combinations.tick(1)
	for i in range(4): await process_frame
	rows=QuickslotMaterials.usable_options(actor,"quick_e")
	check(has(rows,"basic") and has(rows,"attune_fire") and not has(rows,"attune_frost"),"Ordinary and available field forms did not coexist, or a missing field remained")
	check(has(QuickslotMaterials.usable_options(actor,"right"),"","") and has(QuickslotMaterials.usable_options(actor,"right"),"","resin"),"Fire field plus real resin did not offer both ordinary and material-modified casting")
	check(has(rows,"basic","ward_powder") and has(rows,"attune_fire","ward_powder"),"Operation effect compatibility hid valid material-modified forms")
	var home:=actor.position; actor.position+=Vector2(1000,0)
	check(not has(QuickslotMaterials.usable_options(actor,"quick_e"),"attune_fire"),"Out-of-range field remained selectable")
	check(not QuickslotMaterials.select(actor,"quick_e",{"payload":"attune_fire","modifier":"","uid":""},true),"Stale field choice bypassed confirmation validation")
	actor.position=home
	rows=QuickslotMaterials.usable_options(actor,"slot_1")
	check(has(rows,"","") and has(rows,"","frost_salt") and has(rows,"","storm_dust"),"Base and actual material modifiers did not coexist")
	stock=store.snapshot(); mana=actor.mana_component.mp
	check(QuickslotMaterials.select(actor,"slot_1",{"payload":"","modifier":"frost_salt","uid":""},true),"Ready material form could not be pinned")
	check(store.snapshot()==stock and actor.mana_component.mp==mana,"Selecting a ready form spent materials or mana")
	store.pay("player",{"frost_salt":store.count("player","frost_salt")})
	check(not has(QuickslotMaterials.usable_options(actor,"slot_1"),"","frost_salt"),"Consumed material remained selectable")
	var pinned:=manager.shortcuts.selection("slot_1")
	check(not QuickslotMaterials.select(actor,"slot_1",pinned,true) and manager.shortcuts.selection("slot_1")==pinned,"Missing material silently switched the selected source")
	check(QuickslotMaterials.options(actor,"slot_1").any(func(row): return row.choice==pinned and not row.ready),"K preparation catalogue lost unavailable learned forms")
	var ordinary:=manager.combinations.preview(focus,actor,false,{"payload":"basic","modifier":"","uid":""})
	manager.shortcuts.set_selection("quick_e",{"payload":"basic","modifier":"ward_powder","uid":""})
	var modified:=manager.preview_source("quick_e")
	check(modified.ready and modified.material_costs=={"ward_powder":1} and modified.cost==ordinary.cost+2 and modified.skill.buff_duration>=ordinary.skill.buff_duration+4,"Material form preview did not match the existing buff and cost rules")
	var before_cast:=actor.mana_component.mp
	check(manager.use_source("quick_e",actor,CastContext.simple(actor,Vector2.RIGHT,focus)),"Ready modified operation could not execute")
	manager.combinations.tick(1)
	check(store.count("player","ward_powder")==0 and actor.mana_component.mp==before_cast-modified.cost and actor.get_node("BuffManager").has_buff(modified.skill.buff_resource.status_id),"Modified operation failed to consume its actual material or apply its advertised buff")
	actor.mana_component.mp=0
	check(QuickslotMaterials.usable_options(actor,"slot_1").is_empty(),"Unaffordable forms remained in the combat wheel")
	actor.actor_context.martial.learn("staff_sweep")
	manager.restore_skill_state({"quick_e":{"kind":"technique","technique_id":"staff_sweep"}})
	check(manager.shortcuts.binding("quick_e").is_empty() and actor.actor_context.martial.route_equipped("staff_sweep","power"),"Legacy hotkey migration lost knowledge or left a direct-art shortcut")
	check(not manager.shortcuts.bind_technique("quick_e","staff_sweep"),"Retired hotkey API still installed a technique")
	await fixture.close()
	if failures.is_empty(): print("PASS contextual choices: real field and material alternatives, no duplicate auto/no-op modifier, mana/source/range/stock readiness, read-only query and stale confirmation, full preparation catalogue")
	quit(0 if failures.is_empty() else 1)
