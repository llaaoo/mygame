extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true,true)
	var session:=game.session;var store:=session.inventory;var context:=game.player.actor_context;var query:=context.learning_query
	check(not query.knows("skinning",WorldCondition.Knowledge.FIELDCRAFT),"Unlearned professional knowledge passed")
	session.fieldcraft.learn("player","skinning");context.martial.learn("blade_breaker")
	check(query.knows("skinning") and query.knows("blade_breaker",WorldCondition.Knowledge.MARTIAL),"Unified knowledge missed fieldcraft/martial")
	check(not query.knows("skinning",WorldCondition.Knowledge.MARTIAL),"Knowledge category accepted another discipline")
	game.progress.actions["fire_sigil"]=true;game._apply_knowledge()
	check(query.knows("inscribe",WorldCondition.Knowledge.ACTION) and query.knows("fire_sigil",WorldCondition.Knowledge.ACTION),"Legacy knowledge did not qualify its actual canonical operation")
	var intrinsic:=SpellOperationCatalog.default_catalog().rules[0]
	check(query.knows(intrinsic.id,WorldCondition.Knowledge.COMBINATION),"Default learned operation reaction was absent from unified knowledge")
	var untrained:=session.actor_for_id("river.enemy.camp.fieldcraft.hound.v1") as Enemy
	check(not untrained.actor_context.learning_query.knows("inscribe",WorldCondition.Knowledge.ACTION),"Player operation knowledge leaked into an untrained actor")
	var gate:=WorldCondition.new();gate.kind=WorldCondition.Kind.KNOWLEDGE;gate.knowledge_kind=WorldCondition.Knowledge.ACTION;gate.key="inscribe";gate.hint="先掌握刻阵基础操作"
	var reaction_gate:=gate.duplicate() as WorldCondition;reaction_gate.knowledge_kind=WorldCondition.Knowledge.COMBINATION;reaction_gate.key=intrinsic.id
	var chapter:=game.catalog.chapter.duplicate() as ExplorationChapterData;chapter.quests=game.catalog.chapter.quests.duplicate()
	var authored:=chapter.quests[0].duplicate() as ExplorationQuestData;authored.conditions=[gate,reaction_gate];chapter.quests[0]=authored
	check(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter)).is_empty(),"Authored canonical knowledge gates rejected registered operations/default reactions")
	gate.key="unknown_operation"
	check(not ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter)).is_empty(),"Unknown authored operation gate accepted")
	var quest: ExplorationQuestData
	for entry in game.quests:
		if entry.id=="river.hunting_evidence":quest=entry
	check(quest!=null,"Evidence quest absent")
	game.progress.claims["river.hunting.route"]=true
	check(not quest.is_complete(game.progress) and not game.guidance.next_step(quest).title.contains("报告"),"Guidance promised a report before actual practice or alternate evidence")
	for id in ["river.enemy.camp.depth.ridge_archer.v1","river.enemy.camp.depth.ridge_mauler.v1"]:
		var body:=session.actor_for_id(id) as Enemy;body.take_damage(10000);await process_frame
	check(not quest.default_complete(game.progress) and quest.is_complete(game.progress) and game.guidance.next_step(quest).title.contains("报告"),"Real alternate encounter evidence still directed player through unmet default practice")
	store.receive("player","field_knife",1)
	var before: float=session.proficiency.get("survival",0);var xp:=game.player.stats_component.experience;var level:=game.player.stats_component.level
	var receipts: Array[String]=[]
	for id in ["river.enemy.camp.fieldcraft.hound.v1","river.enemy.camp.depth.ridge_hound.1.v1"]:
		var body:=session.actor_for_id(id) as Enemy
		check(body!=null,"Missing real authored hunting source "+id)
		if not body:continue
		game.player.position=body.position+Vector2(25,0);body.take_damage(10000);await process_frame
		var rows:=store.entries(id+".anatomy").filter(func(row):return row.definition=="raw_hide")
		var raw: Dictionary=rows[0];receipts.append(raw.uid)
		check(game.loot.harvesting.complete(id,raw.uid,raw.properties.harvest,store.find_owned("player","field_knife")),"Actual professional extraction failed")
	check(session.fieldcraft.harvest_count("player","skinning")==2 and float(session.proficiency.get("survival",0))>before and (game.player.stats_component.level>level or game.player.stats_component.experience>xp),"Harvest practice did not feed shared growth/proof")
	before=float(session.proficiency.get("survival",0));xp=game.player.stats_component.experience
	session.facts.publish("corpse_harvested","player",{"raw_uid":receipts[0],"skill":"skinning","family":receipts[0]})
	check(float(session.proficiency.get("survival",0))==before and game.player.stats_component.experience==xp,"Duplicate harvested UID farmed growth")
	check(quest.default_complete(game.progress),"Two independent processed bodies did not qualify the default evidence route")
	game.player.position=Vector2(-3500,2100)
	var points:=game.player.stats_component.attribute_points
	var reputation:=session.relations.disposition(TownServices.MERCHANT,"player")
	var route:=quest.approaches.filter(func(entry):return entry.relation_changes.has(TownServices.MERCHANT))[0] as ExplorationQuestApproachData
	check(game.progress_service.claim_quest(quest,route.id) and not game.progress_service.claim_quest(quest) and not game.progress_service.claim_quest(quest,route.id) and game.player.stats_component.attribute_points==points+1 and session.relations.disposition(TownServices.MERCHANT,"player")==reputation+10,"Alternative report did not award actual relationship/points exactly once")
	var charter:=CharterCatalog.default_catalog().definition("hunters")
	var team: String=session.relations.memberships.player
	check(charter.enroll(context) and context.martial.learned.has("hunter_pin") and not charter.enroll(context) and not CharterCatalog.default_catalog().definition("wardens").enroll(context),"Affiliation prerequisites/exclusive knowledge failed")
	check(session.relations.memberships.player==team and session.relations.affiliation("player")=="hunters","Social identity changed combat faction or failed condition")
	game.player.position=Vector2(-3500,2100);game._save_progress();await fixture.close()
	fixture=Fixture.new(self);game=await fixture.boot(true,true);session=game.session
	check(session.relations.affiliation("player")=="hunters" and session.fieldcraft.harvest_count("player","skinning")==2 and game.player.actor_context.martial.learned.has("hunter_pin"),"Cold save lost identity, practice or unlocked art")
	before=float(session.proficiency.get("survival",0));session.facts.publish("corpse_harvested","player",{"raw_uid":receipts[0],"skill":"skinning","family":receipts[0]})
	check(float(session.proficiency.get("survival",0))==before,"Cold reload renewed a completed practice receipt")
	await fixture.travel("river_workshop");var spec: WorldStorageData
	for box in game.current_data.storage:
		if box.id=="storage.town.hunters":spec=box
	check(spec!=null,"Affiliation supply not actually mounted")
	game.player.position=spec.pos+Vector2(0,-25)
	check(game.world_storage.reason(spec).is_empty(),"Earned identity did not open real member box")
	var row: Dictionary=game.session.inventory.entries(spec.id)[0]
	check(game.world_storage.transfer(spec,row.uid,row.quantity,"player.pack").accepted,"Member could not transfer actual finite stock")
	var remaining:=game.session.inventory.entries(spec.id)
	game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true);await fixture.travel("river_workshop")
	check(game.session.inventory.entries(spec.id)==remaining,"Member supply refilled on reentry")
	await fixture.close()
	if failures.is_empty():print("PASS world depth knowledge: shared categories, real anatomy -> permanent practice/XP -> alternate conditions/report -> exclusive identity/art/access, cold UID receipts and finite stock")
	quit(0 if failures.is_empty() else 1)
