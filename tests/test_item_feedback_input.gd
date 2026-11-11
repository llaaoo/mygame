extends "res://tests/support/input_scene_probe.gd"
## Input/transaction fixture: explicit safe position, gear, knowledge and supplies.
## All authored AI runs normally; distant placement isolates feedback from combat.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var notices: Array[String]=[]
func notice(text: String) -> void:notices.append(text)
func feedback(fragment: String,before: int) -> void:
	check(notices.size()==before+1,"Expected exactly one feedback for "+fragment+", got "+str(notices.slice(before)))
	check(game.ui.message.text.contains(fragment),"Player HUD did not show "+fragment+": "+game.ui.message.text)
func settle_feedback() -> void:
	await create_timer(.85).timeout
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self);game=await fixture.boot()
	GameRuntime.instance.set_process(true)
	var actor:=game.player;actor.position=Vector2(-4000,800);actor.get_node("Camera2D").reset_smoothing()
	for enemy in game.active_enemies:enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var context:=actor.actor_context;var store:=context.items;var manager:=actor.skill_manager
	manager.known_actions.disperse=true
	store.receive("player","river_sabre",1);store.receive("player","river_spear",1)
	var blade:=store.find_owned("player","river_sabre");var spear:=store.find_owned("player","river_spear")
	store.equip("player",blade)
	check(store.receive_into("player.pocket","fire_rag",4)==4,"Missing coating fixture supplies")
	check(store.receive_into("player.pocket","venom_bottle",3)==3,"Missing throwing fixture supplies")
	check(store.receive_into("player.pocket","water_sprayer",3)==3,"Missing individual spray fixture supplies")
	manager.shortcuts.bind_item("left","fire_rag")
	manager.shortcuts.bind_item("right","venom_bottle")
	context.actions.action_refused.connect(notice)
	await aim_world(actor.position+Vector2(150,0))
	var stock:=store.count("player","fire_rag");var before:=notices.size()
	await key(KEY_Q,true);await key(KEY_Q,false)
	await create_timer(1.3).timeout
	check(store.coating(blade)!=null and store.count("player","fire_rag")==stock-1,"Actual Q failed to commit exactly one coating")
	check(notices.size()==before,"Successful item completion reported a cancellation")
	# A physical input cancels preparation before any rag is committed.
	stock=store.count("player","fire_rag");before=notices.size()
	await key(KEY_Q,true);await key(KEY_Q,false);await key(KEY_D,true);await key(KEY_D,false)
	feedback("移动",before)
	await capture("item-feedback-movement")
	check(not context.item_actions.busy() and store.count("player","fire_rag")==stock,"Moving cancellation spent its uncommitted rag")
	await settle_feedback()
	# Damage uses the real shared hit pipeline, not a controller cancellation call.
	before=notices.size();await key(KEY_Q,true);await key(KEY_Q,false)
	actor.health_component.invincible=false
	CombatExecutor.report_hit(game.active_enemies[0],actor,1,actor.position,null,["physical"],"feedback.damage",0)
	await frames()
	feedback("受伤",before)
	await capture("item-feedback-damage")
	check(not context.item_actions.busy() and store.count("player","fire_rag")==stock,"Damage cancellation consumed a rag")
	await settle_feedback()
	# A controlled ownership mutation invalidates the weapon chosen by real Q.
	before=notices.size();await key(KEY_Q,true);await key(KEY_Q,false)
	store.equip("player",spear);await frames()
	feedback("主手武器已改变",before)
	check(store.count("player","fire_rag")==stock and store.coating(spear)==null,"Weapon invalidation coated a different UID or spent the rag")
	store.equip("player",blade)
	await settle_feedback()
	# Ordinary manual aim cancellation stays silent and preserves the bottle.
	before=notices.size();var bottles:=store.count("player","venom_bottle")
	await key(KEY_R,true)
	check(context.item_actions.aiming,"Real R failed to start bottle aiming")
	await pointer_button(MOUSE_BUTTON_RIGHT,true);await pointer_button(MOUSE_BUTTON_RIGHT,false);await key(KEY_R,false)
	check(notices.size()==before and not context.item_actions.busy() and store.count("player","venom_bottle")==bottles,"Manual aim cancellation emitted failure or consumed its bottle")
	context.actions.stamina.current=0;context.actions.stamina.delay=.8
	await key(KEY_R,true);await key(KEY_R,false)
	feedback("体力不足",before)
	check(store.count("player","venom_bottle")==bottles and not context.item_actions.busy(),"Rejected throw consumed a bottle")
	context.actions.stamina.current=context.actions.stamina.maximum
	await settle_feedback()
	# Use clear water for resource lifecycle: toxic ground can correctly damage
	# the stationary actor and interrupt before the empty-bottle boundary.
	var spray_uid:=store.ready_uid("player","water_sprayer")
	manager.shortcuts.bind_item("quick_e","water_sprayer",spray_uid)
	var action:=manager.pool.get_skill("disperse")
	var choice: Dictionary={"payload":"water","uid":spray_uid,"modifier":""}
	var cost:=manager.combinations.preview(action,actor,false,choice).cost
	actor.mana_component.mp=cost
	before=notices.size();await key(KEY_E,true)
	var deadline:=Time.get_ticks_msec()+1500
	while context.spray.active and Time.get_ticks_msec()<deadline:await frames(1)
	await key(KEY_E,false)
	feedback("法力不足",before)
	await capture("item-feedback-mana")
	check(store.item(spray_uid)!=null and int(store.item(spray_uid).properties.doses)==2 and actor.mana_component.mp==0,"Failed second pulse refunded the first or spent another dose")
	await settle_feedback()
	actor.mana_component.mp=actor.mana_component.max_mp
	before=notices.size();await key(KEY_E,true);await key(KEY_E,false)
	check(notices.size()==before and not context.spray.active and int(store.item(spray_uid).properties.doses)==2,"Releasing during spray windup emitted failure or consumed a dose")
	# Actual E then external UID movement: no implicit switch to the other bottle.
	await key(KEY_E,true)
	var moved:=store.commit(store.preview("player.pocket","player.pack",spray_uid,1))
	check(moved.accepted,"Could not move the selected bottle for invalidation")
	deadline=Time.get_ticks_msec()+1000
	while context.spray.active and Time.get_ticks_msec()<deadline:await frames(1)
	await key(KEY_E,false)
	feedback("离开口袋",before)
	check(store.locate(spray_uid)=="player.pack" and int(store.item(spray_uid).properties.doses)==2,"Source invalidation lost or consumed the moved bottle")
	await settle_feedback()
	var next_uid:=store.ready_uid("player","water_sprayer")
	manager.shortcuts.bind_item("quick_e","water_sprayer",next_uid)
	before=notices.size();var start_mp:=actor.mana_component.mp
	await key(KEY_E,true)
	deadline=Time.get_ticks_msec()+2500
	while context.spray.active and Time.get_ticks_msec()<deadline:await frames(1)
	await key(KEY_E,false)
	feedback("已用完",before)
	await capture("item-feedback-empty")
	check(store.item(next_uid)==null and store.count("player","water_sprayer",false,true)==1 and actor.mana_component.mp==start_mp-3*cost,"Empty bottle feedback changed pulse costs or silently reloaded")
	# The next, still-full bottle is not used by the stale shortcut.
	await settle_feedback()
	before=notices.size();start_mp=actor.mana_component.mp
	await key(KEY_E,true);await key(KEY_E,false)
	feedback("绑定的实物已失去",before)
	check(not context.spray.active and actor.mana_component.mp==start_mp,"Lost explicit UID silently substituted another bottle")
	# The same spray through a skill slot must report executor-level rejection,
	# before SkillManager runs, without spending the remaining physical bottle.
	await settle_feedback()
	var final_uid:=store.ready_uid("player","water_sprayer")
	check(manager.shortcuts.equip_skill("slot_0",action,{"payload":"water","uid":final_uid,"modifier":""}),"Cannot bind the same spray as a skill")
	var buffs:=actor.get_node("BuffManager") as BuffManager
	var paralysis:=load("res://content/spell_operations/statuses/paralysis.tres") as Buff
	check(buffs.apply_buff(paralysis,game.active_enemies[0]),"Paralysis fixture was rejected")
	before=notices.size();start_mp=actor.mana_component.mp
	await key(KEY_1,true);await key(KEY_1,false)
	feedback("控制状态中",before)
	await capture("item-feedback-controlled-skill")
	check(not context.spray.active and int(store.item(final_uid).properties.doses)==3 and actor.mana_component.mp==start_mp,"Controlled skill-slot spray charged a dose or MP")
	buffs.remove_status("paralysis")
	await settle_feedback()
	context.actions.interrupt(.45)
	before=notices.size();start_mp=actor.mana_component.mp
	await key(KEY_1,true);await key(KEY_1,false)
	feedback("失衡中",before)
	await capture("item-feedback-staggered-skill")
	check(not context.spray.active and int(store.item(final_uid).properties.doses)==3 and actor.mana_component.mp==start_mp,"Staggered skill-slot spray charged a dose or MP")
	await settle_feedback()
	actor.mana_component.mp=0;before=notices.size()
	await key(KEY_1,true);await key(KEY_1,false)
	feedback("法力",before)
	check(not context.spray.active and int(store.item(final_uid).properties.doses)==3 and actor.mana_component.mp==0,"Skill-manager refusal charged a dose or duplicated the item-slot path")
	context.actions.action_refused.disconnect(notice)
	await fixture.close()
	if failures.is_empty():print("PASS item feedback input: real Q/E/R/1 and movement/RMB, success and manual-stop silence, single HUD damage/weapon/stamina/mana/source/empty/control/stagger outcomes, exact committed costs; normal distant AI, controlled supply/position/invalidation fixture")
	quit(0 if failures.is_empty() else 1)
