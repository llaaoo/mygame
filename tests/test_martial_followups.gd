extends SceneTree
## Controlled contacts and clocks, separate from the live-input test.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var game: GrayriverGame
var actor: Player
var target: Enemy
var actions: ActorActionController
var weapons: Dictionary={}
var arrow: WeaponArrow
var starts: Array[Dictionary]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames() -> void:
	for i in range(3): await physics_frame
func request(id: String,base := false) -> Action:
	var input:=Action.new(); input.action_type=Action.ActionType.TECHNIQUE; input.skill_id=id; input.direction=Vector2.RIGHT
	return actions.capture_technique_intent(input,base)
func prime(weapon: String,id: String,hit := true,blocked := false) -> void:
	actions.cancel(); actor.position=Vector2(-4000,800)
	game.session.inventory.equip("player",weapons[weapon])
	actor.actor_context.martial.ready_at.clear()
	target.position=actor.position+Vector2(800,0)
	target.health_component.hp=target.health_component.max_hp; target.health_component.invincible=false
	target.actor_context.actions.cancel(); target.actor_context.actions.stability.current=100
	var data:=MartialArts.definition(id)
	for index in range(data.followup_after[0]+1):
		actions.stamina.current=100
		var swing:=Action.melee(actor); swing.direction=Vector2.RIGHT
		check(actions.try_action(swing).accepted,"Could not prime actual normal stage")
		if index<data.followup_after[0]: actions.advance(actions.remaining)
	actions.advance(actions.profile.windup+.01)
	arrow=null
	if weapon=="river_bow":
		var arrows:=game.region_root.get_children().filter(func(node): return node is WeaponArrow and not node.is_queued_for_deletion())
		if not arrows.is_empty(): arrow=arrows.back(); arrow.set_physics_process(false)
	if hit:
		target.position=actor.position+Vector2(45 if weapon!="river_bow" else 100,0); await frames()
		if blocked:
			target.actor_context.actions.guarding=true; target.actor_context.actions.facing=Vector2.LEFT; target.actor_context.actions.stamina.current=100
		if arrow: arrow._physics_process(.3)
		else: actions.contact(target)
		target.position=actor.position+Vector2(800,0)
	# Enter the actual last 200ms of recovery; do not skip commitment.
	actions.advance(maxf(0,actions.remaining-.2))
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	actor=game.player; actions=actor.actor_context.actions; target=game.active_enemies[0]
	check(preload("res://tests/support/awakened_actor_fixture.gd").awaken(actor),"Controlled physical-action MP budget could not initialize")
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_process(false); target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var store:=game.session.inventory
	for id in ["river_sabre","river_spear","river_staff","river_bow"]:
		store.receive("player",id,1); weapons[id]=store.find_owned("player",id)
	store.receive_into("player.pocket","arrow",20)
	for id in MartialArts.IDS: actor.actor_context.martial.learn(id)
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": starts.append(fact.data))
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"],["river_bow","bow_aim"]]:
		await prime(pair[0],pair[1])
		var data:=MartialArts.definition(pair[1]); var view:=actions.technique_view(pair[1])
		check(view.linked and view.profile==data.followup_profile,"Qualified contact did not offer the authored route: "+pair[1])
		var input:=request(pair[1]); var before:=actions.stamina.current
		check(actions.try_action(input).reason=="buffered" and actions.stamina.current==before,"Followup bypassed recovery or charged while queued")
		actions.advance(actions.remaining)
		check(actions.profile==data.followup_profile and starts.back().followup and starts.back().stamina==data.followup_profile.stamina_cost and actions.combo_snapshot().is_empty(),"Buffered link used wrong form/cost or retained ordinary progression")
		check(actor.actor_context.martial.ready_at.has(pair[1]) and actor.mana_component.mp==60,"Linked form bypassed cooldown or spent MP")
		if pair[0]=="river_bow":
			var ammo:=store.count("player","arrow")
			actions.advance(actions.profile.windup+.01)
			var arrows:=game.region_root.get_children().filter(func(node): return node is WeaponArrow and not node.is_queued_for_deletion())
			check(store.count("player","arrow")==ammo-1 and not arrows.is_empty(),"Linked bow failed to commit a second real arrow")
			if not arrows.is_empty():
				var shot:=arrows.back() as WeaponArrow
				check(shot.profile==data.followup_profile and shot.damage==roundi(actor.combat_component.attack_damage*data.followup_profile.damage_multiplier),"Linked arrow ignored the authored damage/range tradeoff")
				shot.set_physics_process(false); shot.queue_free()
		actions.cancel(); var retry:=request(pair[1]); before=actions.stamina.current
		check(not actions.try_action(retry).accepted and actions.stamina.current==before,"Shared cooldown failed or charged on refusal")
	# Whiffs/blocks cannot manufacture opportunities; Ctrl can keep the base form.
	await prime("river_sabre","blade_breaker",false)
	check(not actions.technique_view("blade_breaker").linked,"Whiff created a link")
	await prime("river_sabre","blade_breaker",true,true)
	check(not actions.technique_view("blade_breaker").linked,"Blocked/chip contact created a link")
	await prime("river_sabre","blade_breaker")
	var base_input:=request("blade_breaker",true); actions.advance(actions.remaining)
	check(actions.try_action(base_input).accepted and actions.profile==MartialArts.definition("blade_breaker").profile and not starts.back().followup,"Explicit base choice silently changed")
	await prime("river_sabre","blade_breaker"); actions.advance(actions.remaining)
	var captured:=request("blade_breaker"); actions.advance(actions.combo.remaining+.01)
	var before:=actions.stamina.current
	check(actions.try_action(captured).reason=="接势窗口已失效" and actions.stamina.current==before,"Expired route fell back or charged")
	await prime("river_sabre","blade_breaker"); actions.advance(actions.remaining); captured=request("blade_breaker")
	store.equip("player",weapons.river_staff); store.equip("player",weapons.river_sabre)
	check(actions.try_action(captured).reason=="接势窗口已失效","Same-frame switch restored a stale opportunity")
	await prime("river_sabre","blade_breaker"); actions.advance(actions.remaining)
	actor.skill_manager.shortcuts.bind_technique("quick_e","blade_breaker")
	captured=request("blade_breaker"); captured.skill_source="quick_e"; captured.params["binding_revision"]=actor.skill_manager.shortcuts.revision("quick_e")
	actor.skill_manager.shortcuts.clear("quick_e")
	check(actions.try_action(captured).reason=="stale_binding","Linked input bypassed the shortcut revision")
	captured=request("blade_breaker"); actions.stamina.current=0
	check(actions.try_action(captured).reason=="stamina" and actions.technique_view("blade_breaker").linked,"Failed resource check consumed the opportunity")
	actions.stamina.current=100
	check(actions.try_action(captured).accepted,"Affordable retry lost its exact still-valid form")
	await prime("river_staff","staff_sweep"); actions.advance(actions.remaining)
	check(actions.try_action(request("staff_sweep")).accepted,"Could not accept real wide followup")
	actions.advance(actions.profile.windup+.01)
	target.position=actor.position+Vector2.from_angle(deg_to_rad(100))*70; await frames()
	# Only the action clock is manually advanced in this geometry fixture.
	target.health_component.invincible=false
	var wide_hit:=actions.contact(target); var target_origin:=target.position
	target.actor_context.actions.advance(.18)
	check(wide_hit.damage_dealt>0 and wide_hit.pushed and target.position.distance_to(target_origin)>35 and target.position.distance_to(target_origin)<=48.01,"Wide followup did not exchange normal reach/push for its real 210-degree contact")
	# An arrow may confirm after recovery, but cannot upgrade an older base input.
	await prime("river_bow","bow_aim",false); actions.advance(actions.remaining)
	base_input=request("bow_aim")
	target.position=actor.position+Vector2(100,0); await frames()
	check(arrow!=null,"No real arrow for late-contact boundary")
	if arrow: arrow._physics_process(.3)
	check(actions.technique_view("bow_aim").linked,"Late first-arrow contact could not confirm the still-live window")
	check(actions.try_action(base_input).accepted and actions.profile==MartialArts.definition("bow_aim").profile,"Late contact changed a previously captured base request")
	# A still-flying old arrow cannot restore cleared state.
	await prime("river_bow","bow_aim",false); actions.advance(actions.remaining); actions.clear_input()
	target.position=actor.position+Vector2(100,0); await frames()
	if arrow: arrow._physics_process(.3)
	check(actions.combo_snapshot().is_empty() and not actions.technique_view("bow_aim").linked,"Old projectile restored cleared progress")
	# Explicit element release remains a real transaction in the faster route.
	actions.cancel(); store.equip("player",weapons.river_sabre); store.receive_into("player.pocket","fire_rag",1)
	check(actor.actor_context.item_actions.begin("fire_rag"),"Could not apply actual fire rag")
	actor.actor_context.item_actions.advance(1.3)
	await prime("river_sabre","blade_breaker"); actions.advance(actions.remaining)
	captured=request("blade_breaker"); captured.params["release_enchantment"]=true
	captured.params["enchantment_weapon_uid"]=weapons.river_sabre; captured.params["enchantment_state"]=store.coating_state(weapons.river_sabre)
	check(actions.try_action(captured).accepted and store.coating(weapons.river_sabre)!=null,"Linked element release consumed coating before the actual swing")
	actions.advance(actions.profile.windup+.01)
	check(store.coating(weapons.river_sabre)==null and game.region_root.get_children().any(func(node): return node is EnchantmentWave),"Linked release failed to commit the real coating/wave")
	# AI can only use learned techniques and goes through the same capture/executor.
	actions.cancel(); target.actor_context.actions.cancel(); target.position=actor.position+Vector2(45,0); await frames()
	var enemy:=target.actor_context; var chosen:=EnemyCharacterBrain.new(target)._martial_action(actor,45,actor.actor_context)
	check(chosen==null,"AI used an unlearned technique")
	store.receive(enemy.id,"river_sabre",1); store.equip(enemy.id,store.find_owned(enemy.id,"river_sabre")); enemy.martial.learn("blade_breaker")
	actions.guarding=true; enemy.actions.stamina.current=100
	chosen=EnemyCharacterBrain.new(target)._martial_action(actor,45,actor.actor_context)
	check(chosen!=null and enemy.actions.try_action(chosen).accepted and enemy.actions.stamina.current==74,"Learned AI guard-break ignored actual knowledge, cost or execution")
	enemy.actions.cancel(); enemy.martial.ready_at.clear(); actions.cancel()
	actor.health_component.hp=actor.health_component.max_hp; actor.health_component.invincible=false
	var attack:=Action.melee(target); attack.direction=Vector2.LEFT
	actor.position=target.position-Vector2(800,0); enemy.actions.stamina.current=100
	enemy.actions.try_action(attack); enemy.actions.advance(enemy.actions.remaining)
	actor.position=target.position-Vector2(45,0); await frames()
	enemy.actions.stamina.current=100; enemy.actions.try_action(attack); enemy.actions.advance(enemy.actions.profile.windup+.01)
	enemy.actions.contact(actor); enemy.actions.advance(enemy.actions.remaining)
	var brain:=EnemyCharacterBrain.new(target); brain._offense_cooldown=1
	var choices:=brain.choose(actor)
	check(choices.size()==1 and choices[0].action_type==Action.ActionType.TECHNIQUE and (not str(choices[0].params.get("followup_family","")).is_empty() or not str(choices[0].params.get("art_token","")).is_empty()),"Normal AI decision ignored a confirmed learned followup")
	if choices.size()==1 and choices[0].action_type==Action.ActionType.TECHNIQUE:
		check(enemy.actions.try_action(choices[0]).accepted and enemy.actions.profile==MartialArts.definition("blade_breaker").followup_profile,"AI followup bypassed shared execution")
	var invalid:=MartialArts.definition("blade_breaker").duplicate(true) as MartialTechnique
	invalid.followup_after=[1,1]; check(not invalid.valid(),"Duplicate followup stages accepted")
	invalid.followup_after=[]; check(not invalid.valid(),"Profile without eligible stages accepted")
	await fixture.travel("river_watch_vault")
	var captains:=game.active_enemies.filter(func(foe): return foe.character_definition.id=="river_watch_captain")
	check(captains.size()==1 and captains[0].actor_context.martial.learned.has("blade_breaker"),"Authored existing captain did not receive initial martial knowledge")
	if not captains.is_empty():
		var captain_id: String=captains[0].actor_context.id
		# Simulate a previously recorded empty knowledge set through its restore API.
		captains[0].actor_context.martial.restore({})
		game._save_progress(); game.reload_progress(); await frames()
		var restored:=game.session.actor_for_id(captain_id)
		check(restored!=null and restored.actor_context.martial.learned.is_empty(),"Restore overwrote recorded knowledge from the new template")
	game._save_progress(); check(SaveManager.instance.read_slot(3).usable(),"Followup runtime state broke persistence")
	await fixture.close()
	if failures.is_empty(): print("PASS martial followups: four confirmed contact routes, real buffered commitment/cost/cooldown, whiff/block rejection, explicit base/late-input snapshot, expiry/UID cleanup, actual arrows/late hits, real element release, learned AI execution and save")
	quit(0 if failures.is_empty() else 1)
