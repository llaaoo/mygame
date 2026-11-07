extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func cast(manager: SkillManager,index: int,actor: Player) -> bool:
	manager.combinations.cooldowns.clear()
	var ok:=manager.use_slot(index,actor,Vector2.RIGHT)
	if ok: manager.combinations.tick(1)
	return ok
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	var actor:=game.player
	actor.position=Vector2(-3500,2000)
	actor.mana_component.max_mp=1000; actor.mana_component.mp=1000
	var manager:=actor.skill_manager
	var controller:=manager.combinations
	var supplies:=controller.supplies
	var store:=game.session.inventory
	var buffs:=actor.get_node("BuffManager") as BuffManager
	for id in ["inscribe","focus","soul_harvest","ignite","pulse"]: manager.known_actions[id]=true
	for pair in [[0,"inscribe"],[1,"focus"],[2,"soul_harvest"],[3,"ignite"],[4,"pulse"]]: manager.equip_slot(pair[0],manager.pool.get_skill(pair[1]))
	var rune:=manager.get_slot(0).data
	var focus:=manager.get_slot(1).data
	var extract:=manager.get_slot(2).data
	check(focus.operation_id=="attune" and extract.operation_id=="extract","Current actors retained separate legacy preparation skills")
	manager.equip_slot(5,load("res://gameplay/abilities/data/echo_mark_data.tres"))
	check(manager.get_slot(5).data.get_id()=="focus","Echo mark did not migrate to attunement")
	store.receive("player","fire_stone",4); store.receive("player","ward_powder",2); store.receive("player","echo_ink",2); store.receive("player","ash",1)
	supplies.select_payload(rune,"ember",manager)
	supplies.configure_modifier(rune,"ash")
	var preview:=controller.preview(rune,actor)
	check(preview.material_costs=={"fire_stone":1,"ash":1} and preview.field_bonus>0,"Inscription lost its separate optional ash modifier")
	check(cast(manager,0,actor),"Material inscription refused")
	check(controller.field and controller.field.field_type=="fire" and controller.field.remaining>15 and supplies.modifiers.is_empty(),"Successful inscription did not commit its ash modifier exactly once")
	var field:=controller.field
	var charges:=field.charges
	supplies.select_payload(focus,"basic",manager)
	check(cast(manager,1,actor) and field.charges==charges and buffs.has_buff("focus"),"Pure attunement silently borrowed an existing rune")
	buffs.clear_all(); supplies.select_payload(focus,"attune_frost",manager)
	var mp:=actor.mana_component.mp
	check(not controller.preview(focus,actor).ready and not cast(manager,1,actor) and field.charges==charges and actor.mana_component.mp==mp,"Missing selected rune fell back to a different source")
	supplies.select_payload(focus,"echo",manager)
	check(cast(manager,1,actor) and buffs.has_buff("echo_ready") and store.count("player","echo_ink")==1 and field.charges==charges,"Echo attunement did not use ink independently of nearby runes")
	buffs.clear_all(); supplies.select_payload(focus,"attune_fire",manager)
	check(cast(manager,1,actor) and field.charges==charges-1 and buffs.has_buff("ember_focus"),"Explicit fire attunement did not consume its actual rune charge")
	buffs.clear_all(); supplies.select_payload(extract,"extract_fire",manager)
	check(cast(manager,2,actor) and field.charges==0 and buffs.get_stack_count("stored_fire")==1,"Rune extraction did not exchange one actual charge for temporary energy")
	check(store.count("player","fire_stone")==3,"Extracting rune energy manufactured a permanent material")
	controller.clear_field(); controller.cooldowns.clear()
	var ordinary:=controller.preview(manager.get_slot(3).data,actor)
	var released:=controller.preview(manager.get_slot(3).data,actor,true)
	check(ordinary.rule_id!="fire_energy_ignite" and released.rule_id=="fire_energy_ignite" and buffs.get_stack_count("stored_fire")==1,"Stored energy was consumed without a separate explicit release action")
	var ctx:=CastContext.simple(actor,Vector2.RIGHT,manager.get_slot(3).data); ctx.empower=true
	check(manager.use_source("slot_3",actor,ctx),"Manual energy release refused"); controller.tick(1)
	check(buffs.get_stack_count("stored_fire")==0,"Manual release did not consume one stored energy layer")
	for i in range(2):
		check(cast(manager,0,actor),"Re-inscription refused")
		check(cast(manager,2,actor),"Energy extraction refused")
		if i==0: check(cast(manager,2,actor),"Second charge could not be extracted")
	check(buffs.get_stack_count("stored_fire")==3,"Same energy family failed to stack to three")
	controller.cooldowns.clear(); mp=actor.mana_component.mp
	check(not manager.use_slot(2,actor,Vector2.RIGHT) and actor.mana_component.mp==mp,"Full temporary energy consumed more rune charges")
	buffs.tick(46)
	check(not buffs.has_buff("stored_fire"),"Temporary energy became permanent")
	controller.clear_field(); supplies.select_payload(rune,"ward_rune",manager)
	check(cast(manager,0,actor) and controller.field.field_type=="ward","Ward powder could not form a real ward rune")
	supplies.select_payload(extract,"extract_ward",manager)
	check(cast(manager,2,actor) and buffs.has_buff("stored_ward"),"Ward charge did not enter temporary storage")
	actor.get_node("BuffManager").clear_temporary()
	check(not buffs.has_buff("stored_ward"),"Region cleanup retained temporary energy")
	store.receive("player","soul_amulet",1); store.equip("player",store.find_owned("player","soul_amulet"))
	supplies.select_payload(extract,"soul_source",manager)
	check(buffs.stack_limit(controller.preview(extract,actor).skill.buff_resource)==5,"Canonical extraction disabled the existing soul-capacity equipment stat")
	check(SpellOperationCatalog.default_catalog().validation_errors().is_empty(),"Operation descriptors invalid")
	await fixture.close()
	if failures.is_empty(): print("PASS reaction sources: primary payload before conditions, optional ash, canonical attunement, explicit rune source, real charge extraction and temporary manual energy release")
	quit(0 if failures.is_empty() else 1)
