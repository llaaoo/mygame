extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const HOUND="river.enemy.camp.fieldcraft.hound.v1"
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n:=4) -> void:
	for i in n:await process_frame
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true)
	var store:=game.session.inventory;var knowledge:=game.session.fieldcraft
	var hound: Enemy
	for foe in game.active_enemies:
		if foe.actor_context.id==HOUND:hound=foe
	check(hound!=null,"Authored hound absent")
	if not hound:quit(1);return
	var parts:=store.entries(HOUND+".anatomy")
	check(parts.size()==2 and not GrayriverLoot.snapshot(hound).materials.has("raw_hide"),"Body parts leaked into ordinary pockets")
	game.player.position=hound.position+Vector2(25,0);hound.take_damage(1000);await frames()
	var raw: Dictionary=parts.filter(func(row):return row.definition=="raw_hide")[0]
	var fang: Dictionary=parts.filter(func(row):return row.definition=="raw_fang")[0]
	var harvesting:=game.loot.harvesting
	check(harvesting.reason(HOUND,raw.uid,raw.properties.harvest).contains("尚未学会"),"Unlearned extraction accepted")
	check(game.loot.take(HOUND)==0 and store.item(raw.uid)!=null,"Take all bypassed professional knowledge")
	check(game.loot.pending(HOUND) and game.presenter.journal_text().contains("专业部位2处"),"Knowledge-gated remains vanished from return-trip journal/map projection")
	var teacher:=TrainingCatalog.default_catalog().actor_id
	store.receive("player","coin",40)
	var before:=store.count("player","coin")
	check(not FieldcraftLearning.purchase(FieldcraftCatalog.default_catalog().skill("fang_work"),game.player.actor_context,teacher).accepted and store.count("player","coin")==before,"Advanced course bypassed prerequisite or charged on failure")
	# Use the real timed book operation; cancellation and duplicate learning preserve it.
	store.receive("player","book_skinning",2)
	var use:=game.player.actor_context.item_actions;use.set_physics_process(false)
	check(use.begin("book_skinning"),"Fieldcraft book refused")
	use.advance(.7);use.cancel()
	check(not knowledge.knows("player","skinning") and store.count("player","book_skinning")==2,"Interrupted book consumed knowledge or item")
	check(use.begin("book_skinning"),"Book could not restart");use.advance(2.1)
	check(knowledge.knows("player","skinning") and store.count("player","book_skinning")==1 and not use.begin("book_skinning"),"Completed/duplicate knowledge book incorrect")
	check(harvesting.reason(HOUND,raw.uid,raw.properties.harvest).contains("工具"),"Missing knife allowed extraction")
	store.receive("player","field_knife",1);var knife:=store.find_owned("player","field_knife")
	check(harvesting.reason(HOUND,raw.uid,raw.properties.harvest,knife).is_empty(),"Learned equipped fieldcraft refused")
	check(FieldcraftLearning.purchase(FieldcraftCatalog.default_catalog().skill("fang_work"),game.player.actor_context,teacher).accepted and store.count("player","coin")==before-6,"Teacher did not charge once and learn")
	check(not FieldcraftLearning.purchase(FieldcraftCatalog.default_catalog().skill("fang_work"),game.player.actor_context,teacher).accepted and store.count("player","coin")==before-6,"Duplicate course charged")
	# Live work pins the original tool UID; an identical replacement cannot finish it.
	harvesting.inspect(HOUND,raw.uid);check(game.player.field_work.start_selected(),"Could not start professional work")
	game.player.field_work.tick(.5);store.drop_item("player",knife,1,game.region_id,game.player.position)
	store.receive("player","field_knife",1);game.player.field_work.tick(.2)
	check(not game.player.field_work.is_busy() and store.item(raw.uid)!=null and store.count("player","beast_hide")==0,"Work silently switched tool or consumed interrupted part")
	game.player.field_work.close_panel()
	harvesting.inspect(HOUND,raw.uid);check(game.player.field_work.start_selected(),"Work failed to restart after replacement")
	game.player.take_damage(1);game.player.field_work.tick(.1)
	check(not game.player.field_work.is_busy() and store.item(raw.uid)!=null,"Taking damage did not preserve unprocessed source")
	game.player.field_work.close_panel()
	harvesting.inspect(HOUND,raw.uid);game.player.field_work.start_selected();game.player.field_work.tick(10)
	check(store.item(raw.uid)==null and store.count("player","beast_hide")==1 and store.item(fang.uid)!=null,"Extraction did not transform exactly one real part")
	check(not harvesting.complete(HOUND,raw.uid,raw.properties.harvest,knife) and store.count("player","beast_hide")==1,"Repeated stale completion duplicated material")
	# Full destination atomically preserves the raw source, including UID/metadata.
	while store.receive("player","river_maul",1)==1:pass
	while store.receive("player","cloth",99)>0:pass
	var full:=store.snapshot()
	check(not store.process_anatomy("player",HOUND,fang.uid).accepted and store.snapshot()==full,"Full inventory lost a finite part")
	store.pay("player",{"river_maul":2})
	var actual_knife:=store.find_owned("player","field_knife")
	check(harvesting.complete(HOUND,fang.uid,fang.properties.harvest,actual_knife) and store.count("player","beast_fang")==2,"Freed capacity did not allow retained fangs")
	check(not game.loot.pending(HOUND),"Exhausted remains left a false pending-loot marker")
	store.pay("player",{"river_maul":store.count("player","river_maul")})
	store.receive("player","ash",1);store.receive("player","crystal",1)
	var supplies:=game.survival.supplies
	check(supplies.knows_recipe("hide_bindings") and supplies.knows_recipe("fang_ward") and not supplies.knows_recipe("gland_venom"),"Knowledge did not gate manufacturing")
	var cloth:=store.count("player","cloth");var powder:=store.count("player","ward_powder")
	check(supplies.craft("hide_bindings") and supplies.craft("fang_ward") and store.count("player","cloth")==cloth+2 and store.count("player","ward_powder")==powder+1 and store.count("player","beast_hide")==0 and store.count("player","beast_fang")==0,"Body materials not conserved through manufacture")
	check(FieldcraftLearning.purchase(FieldcraftCatalog.default_catalog().skill("gland_work"),game.player.actor_context,teacher).accepted,"Qualified gland lesson refused")
	var crawler: Enemy
	for foe in game.active_enemies:
		if foe.actor_context.id=="river.enemy.camp.fieldcraft.crawler.v1":crawler=foe
	var crawler_id:=crawler.actor_context.id
	game.player.position=crawler.position+Vector2(25,0);crawler.take_damage(1000);await frames()
	var gland: Dictionary=store.entries(crawler_id+".anatomy")[0]
	check(harvesting.complete(crawler_id,gland.uid,gland.properties.harvest,actual_knife) and store.count("player","gland_sample")==1,"Learned gland extraction did not deliver finite alchemy resource")
	store.receive("player","herb",1)
	var venom:=store.count("player","potent_venom")
	check(supplies.craft("gland_venom") and store.count("player","gland_sample")==0 and store.count("player","potent_venom")==venom+1,"Harvested gland did not enter actual poison manufacturing")
	var saved:=game.session.snapshot();check(CampaignSession.valid_snapshot(saved),"Anatomy/session snapshot invalid")
	var malformed: Dictionary=saved.inventory.duplicate(true);malformed.containers[HOUND+".anatomy"].items=[raw.duplicate(true)];malformed.containers[HOUND+".anatomy"].items[0].properties.harvest.outputs.beast_hide=-2
	check(not InventoryService.valid_snapshot(malformed),"Invalid finite output budget accepted")
	var missing_module:=saved.duplicate(true);missing_module.erase("fieldcraft");missing_module[SaveSections.VERSIONS].erase("fieldcraft")
	check(game.session.snapshot_read_status(missing_module)==SaveSections.Status.VALID,"Pre-fieldcraft session cannot load additive default module")
	check(knowledge.validate_save_data({"learned":{}}) and not knowledge.validate_save_data({"learned":{"player":{"fang_work":true}}}),"Knowledge prerequisites/defaults invalid")
	game.player.position=Vector2(-3500,2100);game._save_progress()
	await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true);store=game.session.inventory
	check(game.session.fieldcraft.knows("player","fang_work") and store.entries(HOUND+".anatomy").is_empty() and game.loot.corpses.has(HOUND),"Cold reentry refilled body parts or lost learned knowledge")
	var profile:=load("res://content/harvesting/hound.tres") as HarvestProfile
	profile.initialize(store,HOUND)
	check(store.entries(HOUND+".anatomy").is_empty(),"Reinitialization replenished exhausted anatomy")
	await fixture.travel("river_workshop")
	var chest:="storage.town.workshop.fieldcraft"
	check(store.entries(chest).size()==2,"Authored first-use knife/book source missing")
	await fixture.close()
	if failures.is_empty():print("PASS fieldcraft: real book/training, prerequisites, pinned tool UID, interrupted work, finite anatomy, take-all isolation, atomic capacity, recipes and cold persistence")
	quit(0 if failures.is_empty() else 1)
