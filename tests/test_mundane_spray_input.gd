extends "res://tests/support/input_scene_probe.gd"
## Normal AI at a distant safe location; explicit knowledge, bottle and reagents
## isolate mundane use from magical reinforcement. Awakening is a test fixture.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
const Awake:=preload("res://tests/support/awakened_actor_fixture.gd")
var notices: Array[String]=[]
var casts: Array[CastPlan]=[]
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self);game=await fixture.boot()
	GameRuntime.instance.set_process(true)
	var actor:=game.player;actor.position=Vector2(-4000,800);actor.get_node("Camera2D").reset_smoothing()
	for enemy in game.active_enemies:enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var context:=actor.actor_context;var store:=context.items;var manager:=actor.skill_manager
	manager.known_actions.disperse=true
	var action:=manager.pool.get_skill("disperse")
	check(store.receive_into("player.pocket","water_sprayer",1)==1,"Missing ordinary bottle fixture")
	check(store.receive_into("player.pocket","venom_extract",2)==2,"Missing explicit reinforcement reagent fixture")
	var uid:=store.ready_uid("player","water_sprayer")
	var plain: Dictionary={"payload":"water","uid":uid,"modifier":""}
	var enhanced: Dictionary={"payload":"water","uid":uid,"modifier":"venom_extract"}
	check(manager.shortcuts.equip_skill("quick_e",action,plain),"Cannot bind ordinary spray")
	manager.cast_committed.connect(func(plan: CastPlan):casts.append(plan))
	context.actions.action_refused.connect(func(text: String):notices.append(text))
	check(not actor.mana_component.can_cast() and actor.mana_component.mp==0,"Fresh campaign must have no usable magic")
	var plan:=manager.combinations.preview(action,actor,false,plain)
	check(plan.ready and not plan.requires_magic and plan.cost==0 and plan.cost_label().contains("1剂"),"Ordinary preview incorrectly requires awakening or MP")
	check(plan.status_conditions.is_empty() and plan.infusions.is_empty() and plan.field==null,"Ordinary preview consumed magical preparation")
	var options:=QuickslotMaterials.usable_options(actor,"quick_e")
	check(options.any(func(row):return row.choice==plain and not row.requires_magic and row.cost==0),"Combat selector omitted legal zero-mana ordinary spray")
	check(not options.any(func(row):return row.choice.get("modifier","")=="venom_extract"),"Combat selector exposed unawakened magical reinforcement")
	var mastery:=actor.mastery_manager.get_mastery(SkillMastery.School.DESTRUCTION)
	var before_level:=mastery.level;var before_xp:=mastery.xp
	await aim_world(actor.position+Vector2(120,0))
	await key(KEY_E,true)
	var deadline:=Time.get_ticks_msec()+1500
	while int(store.item(uid).properties.doses)==3 and Time.get_ticks_msec()<deadline:await frames(1)
	await key(KEY_E,false)
	check(int(store.item(uid).properties.doses)==2 and actor.mana_component.mp==0,"Actual unawakened E failed one real dose at zero MP")
	check(casts.is_empty() and manager.spell_forms.affinity.is_empty() and mastery.level==before_level and mastery.xp==before_xp,"Mundane spraying granted casting practice or changed intelligent spell following")
	await capture("mundane-spray-zero-mana")
	manager.shortcuts.set_selection("quick_e",enhanced)
	plan=manager.combinations.preview(action,actor,false,enhanced)
	check(plan.requires_magic and not plan.ready and plan.reason.contains("觉醒"),"Explicit magical reagent bypassed awakening in preview")
	var stock:=store.count("player","venom_extract");var before:=notices.size()
	await key(KEY_E,true);await key(KEY_E,false)
	check(not context.spray.active and int(store.item(uid).properties.doses)==2 and store.count("player","venom_extract")==stock and actor.mana_component.mp==0,"Rejected reinforcement consumed resources or silently downgraded")
	check(notices.size()==before+1 and game.ui.message.text.contains("觉醒"),"Actual unawakened reinforcement did not give one clear HUD rejection")
	await capture("mundane-spray-reinforcement-locked")
	var empowered:=manager.combinations.preview(action,actor,true,plain)
	check(empowered.requires_magic and not empowered.ready,"Explicit magical empowerment was downgraded to mundane use")
	await create_timer(.85).timeout
	check(Awake.awaken(actor),"Could not establish explicit awakened test actor")
	plan=manager.combinations.preview(action,actor,false,enhanced)
	check(plan.ready and plan.requires_magic and plan.cost>0 and plan.material_costs.get("venom_extract",0)==1,"Awakened reinforcement lost its real reagent/MP cost")
	var cost:=plan.cost
	actor.mana_component.mp=cost
	before=notices.size()
	await key(KEY_E,true)
	deadline=Time.get_ticks_msec()+1600
	while context.spray.active and Time.get_ticks_msec()<deadline:await frames(1)
	await key(KEY_E,false)
	check(int(store.item(uid).properties.doses)==1 and store.count("player","venom_extract")==stock-1 and actor.mana_component.mp==0,"Failed second magical pulse refunded the first or spent extra dose/reagent/MP")
	check(casts.size()==1 and casts[0].requires_magic and not manager.spell_forms.affinity.is_empty() and (mastery.level>before_level or mastery.xp>before_xp),"Committed magical reinforcement failed casting facts, practice or following")
	check(notices.size()==before+1 and game.ui.message.text.contains("法力不足"),"Depleted magical reinforcement did not report exactly one mana rejection")
	await capture("mundane-spray-reinforcement-mana")
	await fixture.close()
	if failures.is_empty():print("PASS mundane spray input: unawakened real E at zero MP, physical dose conservation, no magical practice/following, explicit reinforcement refusal without fallback, awakened reagent/MP commit and failed next pulse; normal distant AI, controlled supplies/awakening fixture")
	quit(0 if failures.is_empty() else 1)
