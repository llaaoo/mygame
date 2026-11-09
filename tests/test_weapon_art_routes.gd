extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var game: GrayriverGame
var actor: Player
var target: Enemy
var actions: ActorActionController
var weapons: Dictionary={}
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames() -> void:
	for i in range(3): await physics_frame
func prime(weapon: String,sequence: Array[String],hit_last := false,finish_last := true) -> void:
	actions.cancel(); actor.position=Vector2(-4000,800)
	game.session.inventory.equip("player",weapons[weapon]); actor.actor_context.martial.ready_at.clear()
	target.position=actor.position+Vector2(1000,0)
	target.health_component.hp=target.health_component.max_hp; target.health_component.invincible=false
	target.actor_context.actions.cancel("scope_left"); target.actor_context.actions.stability.current=100
	for index in range(sequence.size()):
		actions.stamina.current=100
		var request:=Action.melee(actor); request.direction=Vector2.RIGHT
		if sequence[index]=="heavy": request.action_type=Action.ActionType.HEAVY_ATTACK
		check(actions.try_action(request).accepted,"Could not accept a real sequence stroke")
		if index<sequence.size()-1:
			actions.advance(actions.remaining)
			continue
		actions.advance(actions.profile.windup+.01)
		if index==sequence.size()-1 and hit_last:
			target.position=actor.position+Vector2(45,0); await frames()
			target.health_component.tick(1) # Isolate contact trials from earlier projectile immunity.
			var contact:=actions.contact(target)
			check(contact.damage_dealt>0,"Actual contact did not confirm the terminal stroke: "+contact.rejection)
			target.position=actor.position+Vector2(1000,0)
		if finish_last: actions.advance(actions.remaining)
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	actor=game.player; actions=actor.actor_context.actions; target=game.active_enemies[0]
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_process(false); target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var store:=game.session.inventory
	for id in ["river_sabre","river_spear","river_staff","river_bow"]:
		store.receive("player",id,1); weapons[id]=store.find_owned("player",id)
	store.receive_into("player.pocket","arrow",16)
	for id in MartialArts.IDS: actor.actor_context.martial.learn(id)
	for source in QuickslotLoadout.SOURCES: actor.skill_manager.shortcuts.clear(source)
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"],["river_bow","bow_aim"]]:
		await prime(pair[0],["light","heavy"])
		var view:=actions.weapon_art_view()
		check(not view.is_empty() and view.technique==pair[1] and view.route=="power" and is_equal_approx(view.remaining,1.1),"Completed light-heavy did not open its full authored window")
		var request:=actions.capture_weapon_art(Vector2.RIGHT); var before:=actions.stamina.current
		check(actions.try_action(request).accepted and actions.profile==MartialArts.definition(pair[1]).profile and is_equal_approx(before-actions.stamina.current,actions.profile.stamina_cost),"Shared art required a shortcut or used wrong form/cost")
		check(actions.weapon_art_view().is_empty(),"An accepted art left a reusable opportunity")
	await prime("river_sabre",["light","heavy"],true)
	var choice:=actions.weapon_art_view()
	check(choice.alternatives.size()==2 and choice.route=="power","Same combo did not offer exactly two arts with the base default")
	var deadline: float=choice.remaining
	actions.advance(.18)
	var selection_stamina:=actions.stamina.current
	check(actions.cycle_weapon_art().accepted and actions.weapon_art_view().route=="power_followup" and actions.weapon_art_view().remaining<deadline-.17 and actions.stamina.current==selection_stamina,"Ctrl selection changed costs, failed to switch or refreshed the deadline")
	var locked:=actions.capture_weapon_art(Vector2.RIGHT)
	check(actions.cycle_weapon_art().accepted and actions.weapon_art_view().route=="power","Second switch failed to return to the first art")
	check(actions.try_action(locked).accepted and actions.profile==MartialArts.definition("blade_breaker").followup_profile,"Switching after capture changed the locked art")
	var martial:=actor.actor_context.martial
	var group:="blade:light/heavy"
	var saved_routes:=martial.snapshot()
	check(not martial.equip_route("blade_breaker/power",2),"A combo accepted a third equipped art")
	var too_many:=saved_routes.duplicate(true); too_many.routes[group].append("blade_breaker/flow")
	check(not MartialArts.valid(too_many),"Save accepted more than two arts for one sequence")
	check(martial.remove_route(group,1),"Could not remove an equipped choice")
	var one_route:=martial.snapshot(); martial.restore(one_route)
	check(martial.route_slots(group).size()==1,"Save/restore silently refilled an intentionally removed art")
	martial.restore(saved_routes)
	await prime("river_sabre",["heavy","light"])
	check(actions.weapon_art_view().is_empty(),"Wrong input order opened a route")
	await prime("river_sabre",["light","light"])
	check(actions.weapon_art_view().is_empty(),"Whiffed lights opened a hit-required route")
	await prime("river_sabre",["light","light"],true)
	var all_hits:=MartialArts.definition("blade_breaker").art_route("flow").duplicate() as MartialRoute
	all_hits.hit_rule=MartialRoute.HitRule.ALL
	check(actions.weapon_art.match_route(all_hits).is_empty(),"Final hit fabricated earlier hit facts for an all-hit route")
	actions.advance(.7)
	check(actions.combo_snapshot().is_empty() and not actions.weapon_art_view().is_empty() and actions.weapon_art_view().route=="flow","Art window incorrectly reused the shorter normal-combo deadline")
	var captured:=actions.capture_weapon_art(Vector2.RIGHT)
	actions.advance(.21); var stamina:=actions.stamina.current
	check(actions.try_action(captured).reason=="武技窗口已失效" and actions.stamina.current==stamina,"Expired shared input fell back or charged")
	await prime("river_sabre",["light","heavy"])
	captured=actions.capture_weapon_art(Vector2.RIGHT); actions.stamina.current=0
	check(actions.try_action(captured).reason=="stamina" and not actions.weapon_art_view().is_empty(),"Resource refusal consumed the pattern")
	actions.stamina.current=100
	check(actions.try_action(captured).accepted,"Still-valid affordable retry changed its selection")
	await prime("river_sabre",["light","heavy"]); captured=actions.capture_weapon_art(Vector2.RIGHT)
	store.equip("player",weapons.river_staff); store.equip("player",weapons.river_sabre)
	check(actions.try_action(captured).reason=="武技窗口已失效","Same-frame UID return restored a route")
	await prime("river_sabre",["light","heavy"]); captured=actions.capture_weapon_art(Vector2.RIGHT)
	var next:=Action.melee(actor); next.direction=Vector2.RIGHT; actions.stamina.current=100
	actions.try_action(next); actions.advance(actions.remaining)
	check(actions.try_action(captured).reason=="武技窗口已失效","A new stroke reused an older token")
	# Accepting/canceling windup does not count as a released heavy.
	await prime("river_sabre",["light"])
	var heavy:=Action.melee(actor); heavy.action_type=Action.ActionType.HEAVY_ATTACK; heavy.direction=Vector2.RIGHT
	actions.stamina.current=100; actions.try_action(heavy)
	check(actions.weapon_art_view().is_empty(),"Heavy acceptance alone opened a window")
	actions.interrupt(.2); check(actions.weapon_art_view().is_empty(),"Interrupted sequence retained progress")
	await prime("river_sabre",["light","heavy"],false,false)
	actions.advance(actions.profile.active)
	check(actions.remaining>.35 and actions.weapon_art_view().is_empty(),"Early recovery advertised a shared input that would expire before completion")
	actions.advance(maxf(0,actions.remaining-.2)); captured=actions.capture_weapon_art(Vector2.RIGHT)
	check(actions.try_action(captured).reason=="buffered","Shared key bypassed commitment instead of buffering")
	actions.advance(actions.remaining)
	check(actions.mode=="attack" and actions.profile==MartialArts.definition("blade_breaker").profile,"Buffered shared key lost the exact route")
	# Big steps cannot stretch a completed window.
	await prime("river_sabre",["light","heavy"],false,false)
	actions.advance(actions.remaining+1.11)
	check(actions.weapon_art_view().is_empty(),"Long frame extended the art window")
	await prime("river_sabre",["light","heavy"])
	check(not actions.weapon_art_view(true).reason.is_empty(),"Shift preview promised a missing coating")
	actions.cancel(); store.receive_into("player.pocket","fire_rag",1)
	check(actor.actor_context.item_actions.begin("fire_rag"),"Could not use an actual rag for shared art")
	actor.actor_context.item_actions.advance(1.3)
	await prime("river_sabre",["light","heavy"])
	captured=actions.capture_weapon_art(Vector2.RIGHT,true)
	check(not captured.params.enchantment_state.is_empty() and actions.try_action(captured).accepted and store.coating(weapons.river_sabre)!=null,"Shared art did not lock/retain actual coating until release")
	actions.advance(actions.profile.windup+.01)
	check(store.coating(weapons.river_sabre)==null and game.region_root.get_children().any(func(node): return node is EnchantmentWave),"Shift shared art failed to consume its real coating and emit the normal wave")
	game._save_progress(); game.reload_progress(); await frames()
	check(actions.weapon_art_view().is_empty(),"Restore retained physical sequence history")
	var invalid:=MartialRoute.new(); invalid.id="bad"; invalid.sequence=["light","cast"]
	check(not invalid.valid(),"Nonphysical route step accepted")
	invalid.sequence=["light"]; invalid.window=INF
	check(not invalid.valid(),"Nonfinite route window accepted")
	var catalog:=MartialCatalog.default_catalog().duplicate(true) as MartialCatalog
	var duplicate:=catalog.techniques[0].duplicate(true) as MartialTechnique; duplicate.id="duplicate.route"; catalog.techniques.append(duplicate)
	check(catalog.validate().is_empty(),"Different techniques sharing a sequence must be authorable")
	duplicate.art_routes.append(duplicate.art_routes[0])
	check(not catalog.validate().is_empty(),"Duplicate route in one technique was accepted")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon art routes: four real light-heavy windows without slots, hit-required flow, independent deadline, strict token/UID/order/interrupt/expiry, real cost, buffered commitment, modifier preview, restore and authoring validation")
	quit(0 if failures.is_empty() else 1)
