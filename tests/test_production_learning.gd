extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self); var game:=await fixture.boot(true)
	game.session.set_process(false)
	var store:=game.session.inventory; var production:=game.session.production
	var merchant:=TownServices.MERCHANT
	var coins:=store.count(merchant,"coin"); var xp:=game.player.stats_component.experience
	var charcoal:=store.count(merchant,"charcoal"); var crystal:=store.count(merchant,"crystal")
	check(production.start("town.fire_stone",2).accepted and not production.start("town.fire_stone").accepted,"Duplicate production orders accepted")
	check(store.count(merchant,"charcoal")==charcoal,"Scheduling prepaid material")
	store.clock_seconds+=120; production.advance()
	check(store.count(merchant,"fire_stone")==2 and store.count(merchant,"charcoal")==charcoal-4 and store.count(merchant,"crystal")==crystal-2,"Production did not transform exact real stock")
	check(store.count(merchant,"coin")==coins and game.player.stats_component.experience==xp,"NPC production minted money or player XP")
	var completed:=store.snapshot(); production.advance()
	check(store.snapshot()==completed and not production.status("town.fire_stone").scheduled,"Completed work replayed")
	check(production.start("town.arrows").accepted,"Arrow order failed")
	store.clock_seconds+=20; game._save_progress(); var deadline:=float(production.snapshot().jobs["town.arrows"].due)
	await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true); game.session.set_process(false)
	store=game.session.inventory; production=game.session.production
	check(production.snapshot().jobs["town.arrows"].due==deadline,"Reload renewed work deadline")
	var arrows:=store.count(merchant,"arrow"); store.clock_seconds=deadline; production.advance()
	check(store.count(merchant,"arrow")==arrows+6,"Persisted work failed to finish")
	# Inputs can be traded away before completion; blocked work banks no past time.
	store.pay(merchant,{"crystal":store.count(merchant,"crystal")})
	store.receive(merchant,"charcoal",1)
	check(production.start("town.fire_stone").accepted,"Blocked order fixture failed")
	store.clock_seconds+=60; var inputs:=store.count(merchant,"charcoal"); production.advance()
	check(production.status("town.fire_stone").blocked and store.count(merchant,"charcoal")==inputs,"Missing material partially charged work")
	store.receive(merchant,"crystal",1); production.advance()
	check(not production.status("town.fire_stone").blocked and production.status("town.fire_stone").remaining>=59,"Unblocking granted instant stored production time")
	check(production.cancel("town.fire_stone") and not production.cancel("town.fire_stone") and store.count(merchant,"crystal")==1,"Cancel spent or refunded nonexistent resources")
	# Atomic output-capacity failure using an authored-shape recipe with two weapons.
	store.receive(merchant,"charcoal",8)
	while store.receive(merchant,"river_staff",1)==1: pass
	var snapshot:=store.snapshot()
	check(not store.craft_batch(merchant,{"charcoal":1},{"river_staff":2}).accepted and store.snapshot()==snapshot,"Full output inventory destroyed materials")
	var custom:=ProductionCatalog.new(); var entry:=ProductionDefinition.new(); entry.id="town.fire_stone"; entry.actor_id=merchant; entry.recipe=CraftingRecipe.new(); entry.recipe.id="capacity_fixture"; entry.recipe.inputs={"charcoal":1}; entry.recipe.output_id="river_staff"; entry.recipe.output_count=2; custom.entries=[entry]
	var work:=ProductionService.new(); work.configure(store,custom,60)
	work.start(entry.id); store.clock_seconds+=60; work.advance()
	check(work.status(entry.id).blocked and work.snapshot().jobs[entry.id].batches==1 and store.snapshot()==snapshot,"Capacity failure lost work or altered stock")
	store.pay(merchant,{"river_staff":2}); work.advance(); store.clock_seconds+=60; work.advance()
	check(not work.status(entry.id).scheduled,"Freed capacity did not resume work")
	# Courses use current world/item requirements and shared knowledge acquisition.
	var context:=game.player.actor_context
	store.receive("player","coin",40)
	var offer:=TrainingCatalog.default_catalog().offer("staff_sweep")
	var money:=store.count("player","coin")
	check(not TechniqueLearning.purchase(offer,context,"river.enemy.service.trainer").accepted and store.count("player","coin")==money,"Missing course requirement charged money")
	store.receive("player","river_staff",1)
	check(TechniqueLearning.purchase(offer,context,"river.enemy.service.trainer").accepted and context.martial.learned.has("staff_sweep") and store.count("player","coin")==money-8,"Valid course failed real payment/knowledge")
	check(not TechniqueLearning.purchase(offer,context,"river.enemy.service.trainer").accepted and store.count("player","coin")==money-8,"Duplicate training charged twice")
	var course:=TrainingCatalog.default_catalog().offer("bow_aim").duplicate() as LearningOffer
	var milestone:=WorldCondition.new(); milestone.kind=WorldCondition.Kind.CLAIM; milestone.key="river.handbook"; milestone.hint="先读施法手册"
	course.requirements=[milestone]
	var course_money:=store.count("player","coin")
	check(not TechniqueLearning.purchase(course,context,"river.enemy.service.trainer").accepted and store.count("player","coin")==course_money,"World-gated course charged before discovery")
	game.progress.claims["river.handbook"]=true
	check(TechniqueLearning.reason(course,context).is_empty(),"World discovery did not unlock configured course")
	check(not TechniqueLearning.purchase(course,context,"missing.teacher").accepted and not context.martial.learned.has("bow_aim"),"Absent teacher granted knowledge")
	var teacher: String="river.enemy.service.trainer"
	store.pay(teacher,{"coin":store.count(teacher,"coin")})
	while store.receive(teacher,"river_staff",1)==1: pass
	while store.receive(teacher,"cloth",99)>0: pass
	var before_knowledge:=context.martial.snapshot(); money=store.count("player","coin")
	check(not TechniqueLearning.purchase(TrainingCatalog.default_catalog().offer("blade_breaker"),context,teacher).accepted and context.martial.snapshot()==before_knowledge and store.count("player","coin")==money,"Full teacher inventory left knowledge or payment half committed")
	var catalog:=MartialCatalog.default_catalog().duplicate() as MartialCatalog
	var definitions: Array[MartialTechnique]=[]
	for definition in catalog.techniques: definitions.append(definition.duplicate() as MartialTechnique)
	catalog.techniques=definitions; context.martial.catalog=catalog
	catalog.definition("blade_breaker").prerequisites=["staff_sweep"]
	catalog.definition("bow_aim").prerequisites=["blade_breaker"]
	catalog.definition("bow_aim").exclusive_group="test.path"; catalog.definition("spear_thrust").exclusive_group="test.path"
	check(catalog.validate().is_empty() and not context.martial.learn("bow_aim") and context.martial.learn("blade_breaker") and context.martial.learn("bow_aim") and not context.martial.learn("spear_thrust"),"Prerequisite or exclusive specialization failed")
	store.receive("player","book_spear_thrust",1)
	check(not context.item_actions.begin("book_spear_thrust") and store.count("player","book_spear_thrust")==1,"Book bypassed specialization or consumed a rejected book")
	catalog.definition("staff_sweep").prerequisites=["blade_breaker"]
	check(not catalog.validate().is_empty(),"Cyclic knowledge prerequisites accepted")
	catalog.definition("staff_sweep").prerequisites=[]
	catalog.definition("bow_aim").exclusive_group="test.impossible"; catalog.definition("blade_breaker").exclusive_group="test.impossible"
	check(not catalog.validate().is_empty(),"Mutually exclusive prerequisite chain accepted")
	check(MartialArts.definition("blade_breaker").prerequisites.is_empty(),"Runtime specialization changed shared authored definitions")
	var invalid_recipe:=ProductionCatalog.default_catalog().definition("town.arrows").duplicate() as ProductionDefinition
	invalid_recipe.work_hours=NAN
	check(not invalid_recipe.valid(),"Nonfinite production duration accepted")
	var invalid_offer:=TrainingCatalog.default_catalog().offer("blade_breaker").duplicate() as LearningOffer
	var condition:=WorldCondition.new(); condition.kind=WorldCondition.Kind.INVENTORY; condition.key="missing_item"; condition.hint="invalid fixture"
	invalid_offer.requirements=[condition]
	check(not invalid_offer.valid(),"Unknown course material accepted")
	var provisions:=ProvisionCatalog.new()
	var meal:=ProvisionCatalog.default_catalog().definition("ration").duplicate() as ProvisionDefinition
	meal.effect=meal.effect.duplicate() as Buff; meal.effect.exclusive_group="wrong.meal.slot"
	provisions.provisions=[meal,ProvisionCatalog.default_catalog().definition("broth")]
	check(not provisions.validate().is_empty(),"Two simultaneous meal replacement groups accepted")
	var invalid:=game.session.snapshot(); invalid.production={"schema":1,"jobs":{"unknown":{"due":0.0,"batches":1,"blocked":false}}}
	check(not CampaignSession.valid_snapshot(invalid),"Unknown production record accepted")
	context.martial.catalog=null
	game._save_progress(); await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true)
	check(game.player.actor_context.martial.learned.has("bow_aim") and game.player.actor_context.martial.learned.has("blade_breaker"),"Saved knowledge was re-gated or erased")
	await fixture.close()
	if failures.is_empty(): print("PASS production/learning: finite stock, deadlines/reentry, missing materials/capacity, no banked time, cancel/idempotence, real courses, rollback, prerequisites/exclusivity/books and validation")
	quit(0 if failures.is_empty() else 1)
