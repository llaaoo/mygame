extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n): await process_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	var session:=game.session
	var store:=session.inventory
	var npc:=session.actor_for_id("river.enemy.service.trainer") as ServiceNPC
	check(npc!=null and npc.actor_context.actions.active(),"Service NPC did not compose the shared actor systems")
	npc.set_physics_process(false)
	npc.actor_context.actions.set_physics_process(false)
	npc.hour_query=func(): return 23.0
	npc._clock=0; npc._physics_process(.3)
	check(not npc.working,"NPC schedule did not close service at night")
	npc.hour_query=func(): return 12.0
	npc._clock=0; npc._physics_process(.3)
	game.player.position=npc.position+Vector2(30,0)
	check(npc.working and npc.can_serve(game.player),"NPC schedule did not reopen service")
	session.relations.set_attitude(npc.actor_context.id,"player","hostile")
	check(not npc.can_serve(game.player),"Hostile NPC offered service")
	session.relations.set_attitude(npc.actor_context.id,"player","neutral")
	var npc_id:=npc.actor_context.id
	store.receive(npc_id,"clean_water",1)
	npc.actor_context.actions.cancel("test")
	npc.actor_context.actions.needs.hydration=10
	var use:=Action.new(); use.action_type=Action.ActionType.USE_ITEM; use.skill_id="clean_water"
	check(npc.actor_context.actions.try_action(use).accepted,"NPC refused real pocket water")
	var task:=npc.get_child(npc.get_child_count()-1) as ActorItemUse
	check(task!=null,"NPC item request created no timed operation")
	if task:
		task.set_physics_process(false)
		task._physics_process(10)
		check(store.count(npc_id,"clean_water")==0 and npc.actor_context.actions.needs.water_remaining>0,"NPC did not consume real stock or receive shared recovery")
	await frames()
	npc.actor_context.actions.cancel("test")
	npc.health_component.hp=maxi(1,npc.health_component.hp-7)
	var saved_hp:=npc.health_component.hp
	store.receive(npc_id,"river_sabre",1)
	var uid:=store.find_owned(npc_id,"river_sabre")
	store.equip(npc_id,uid)
	var query:=ConditionQuery.new(); query.items=store; query.relations=session.relations; query.progress=game.progress
	var condition:=WorldCondition.new(); condition.kind=WorldCondition.Kind.INVENTORY; condition.key="ration"
	check(condition.satisfied(query)==(store.count("player","ration",true)>0),"Typed inventory condition reads another source")
	condition.kind=WorldCondition.Kind.RELATION; condition.key=npc_id; condition.attitude="neutral"
	check(condition.satisfied(query),"Typed relationship condition failed")
	var before:=float(session.proficiency.get("melee",0))
	session.facts.publish("melee_hit","player",{"family":"foundation.test"})
	session.facts.publish("melee_hit","player",{"family":"foundation.test"})
	check(float(session.proficiency.get("melee",0))==before+1,"Duplicate contact awarded duplicate proficiency")
	var bag_rows:=store.entries("player.pack")
	check(session.drop_pack("player"),"Player could not drop real pack")
	var origin:=game.player.position
	var sim:=GameRuntime.instance.get_simulation_runtime()
	var baseline:=sim.entity_ticker_count()
	var guard_id:="river.enemy.camp.bridge_keeper"
	var guard_food:=store.count(guard_id,"ration")
	for cycle in range(10):
		await fixture.travel("river_archive")
		if cycle==0: game.progress.story_actors[guard_id].materials={"ration":90}
		await fixture.travel("camp",origin)
		check(store.entries("player.pack")==bag_rows and not store.is_attached("player.pack"),"Travel copied or silently recovered dropped pack")
		check(session.actors.size()==14,"Travel accumulated actor registrations")
		check(sim.entity_ticker_count()==baseline,"Travel accumulated entity tickers")
	npc=session.actor_for_id(npc_id) as ServiceNPC
	check(store.count(guard_id,"ration")==guard_food,"Legacy story projection refilled canonical NPC inventory")
	check(npc.health_component.hp==saved_hp and store.equipped(npc_id).values().has(uid),"Travel reset NPC injury or equipment identity")
	check(session.recover_pack("player","player.pack"),"Could not recover the same dropped pack")
	check(store.entries("player.pack")==bag_rows,"Recovering pack changed its contents")
	var saved:=session.snapshot()
	check(CampaignSession.valid_snapshot(saved),"Live campaign snapshot invalid")
	var bad:=saved.duplicate(true); bad.inventory.next_uid=1
	check(not session.restore(bad) and session.snapshot().inventory==saved.inventory,"Rejected save mutated canonical inventory")
	# Shared Resource definitions must not own runtime progress.
	var objective:=InteractObjective.new(); objective.required_count=2
	var stage:=QuestStageData.new(); stage.objectives=[objective]
	var definition:=QuestData.new(); definition.stages=[stage]
	var a:=QuestRuntime.new(); a.data=definition; a.start()
	var b:=QuestRuntime.new(); b.data=definition; b.start()
	var event:=CombatEvent.new(); event.type=CombatEvent.Type.ON_INTERACT
	a.on_event(event)
	check(a.get_progress()==[1] and b.get_progress()==[0],"Two quest runtimes mutated their shared Resource")
	var screen:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	root.add_child(screen)
	check(screen.rows!=null and screen.detail!=null,"Expedition screen cannot instantiate independently")
	screen.queue_free()
	# New item content binds to the reusable actor without editing a chapter/factory.
	var custom:=EquipmentData.new(); custom.id="test.authoring.spear"; custom.display_name="Authoring spear"
	custom.slot_type=EquipmentData.SlotType.RIGHT_HAND
	custom.attack_profile=AttackProfile.new(); custom.attack_profile.reach=90
	check(custom.attack_profile.valid(),"Authored attack profile rejected")
	custom.attack_profile.windup=-1
	check(not custom.attack_profile.valid(),"Negative attack timing accepted")
	custom.attack_profile.windup=.25
	var body:=preload("res://gameplay/foundation/shared_actor.tscn").instantiate() as SharedActor
	game.region_root.add_child(body)
	var ctx:=session.bind_actor(body,"test.authoring.actor")
	store.register_definition(custom); store.receive(ctx.id,custom.id,1)
	check(store.equip(ctx.id,store.find_owned(ctx.id,custom.id)).accepted and body.get_node("EquipmentManager").get_equipment(custom.slot_type)==custom,"New actor/weapon required a chapter-specific code path")
	for directory in ["res://gameplay/foundation","res://entities/player/components","res://entities/enemy"]:
		if directory!="res://gameplay/foundation": continue
		for filename in DirAccess.get_files_at(directory):
			if filename.get_extension()!="gd": continue
			var source:=FileAccess.get_file_as_string(directory.path_join(filename))
			for forbidden in ["GrayriverGame","MVPGame","current_scene","GameRuntime.instance"]:
				check(not forbidden in source,"Reusable domain reaches concrete scene/global locator: "+filename)
	# v1-v3 compatibility input: ownership counts already include worn copies.
	var legacy:=CampaignSession.new()
	root.add_child(legacy); legacy.configure(game.catalog,game.rules)
	var old_actor:=preload("res://gameplay/foundation/shared_actor.tscn").instantiate() as SharedActor
	var old_definition:=ActorCharacterData.new(); old_definition.id="legacy"; old_definition.title="Legacy"
	old_definition.materials={"ration":2}
	old_definition.equipment=[game.catalog.equipment["river_sabre"]]
	old_actor.character_definition=old_definition
	root.add_child(old_actor)
	legacy.bind_actor(old_actor,"legacy",{"river_sabre":2},{str(EquipmentData.SlotType.RIGHT_HAND):"river_sabre"})
	check(legacy.inventory.count("legacy","river_sabre",true)==2 and legacy.inventory.count_in("legacy.pack","river_sabre")==1,"Legacy migration duplicated the worn copy")
	var migrated:=legacy.snapshot()
	check(legacy.restore(migrated),"Migrated inventory cannot restore")
	old_actor.queue_free(); await frames()
	old_actor=preload("res://gameplay/foundation/shared_actor.tscn").instantiate() as SharedActor
	old_actor.character_definition=old_definition; root.add_child(old_actor)
	legacy.bind_actor(old_actor,"legacy",{"river_sabre":2},{str(EquipmentData.SlotType.RIGHT_HAND):"river_sabre"})
	check(legacy.inventory.count("legacy","river_sabre",true)==2 and legacy.inventory.count("legacy","ration")==2,"Canonical restore refilled legacy template stock")
	old_actor.queue_free(); legacy.queue_free(); await frames()
	await fixture.close()
	if failures.is_empty(): print("PASS foundation systems: schedules, common needs, physical packs, 20 region changes, persistent NPC equipment, typed conditions, proficiency and shared definitions")
	quit(0 if failures.is_empty() else 1)
