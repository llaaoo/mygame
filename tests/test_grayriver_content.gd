extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var errors:Array[String]=[]
var game:GrayriverGame
func _init() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:errors.append(message);push_error(message)
func read(id:String) -> void:
	for note in game.current_data.discoveries:
		if note.id==id:check(game.progress_service.discover(note),"Could not learn "+id);return
	check(false,"Missing note "+id)
func site(id:String) -> SpellWorldObject:
	for node in game.region_root.get_children():
		if node is SpellWorldObject and node.spec.id==id:return node
	return null
func station(id:String) -> ExplorationInteractable:
	for node in game.region_root.get_children():
		if node.has_meta("survival_station") and node.get_meta("survival_station").id==id:return node
	return null
func cast(id:String,target:Vector2) -> void:
	var sm:=game.player.skill_manager
	sm.combinations.tick(2)
	var skill:=sm.pool.get_skill(id)
	sm.equip_slot(5,skill)
	game.player.position=target-Vector2(24,0)
	var context:=CastContext.at_position(game.player,target,skill)
	context.direction=Vector2.RIGHT
	check(sm.use_source("slot_5",game.player,context),"Actual cast refused "+id)
	sm.combinations.tick(2)
	for i in range(3):await physics_frame
func run() -> void:
	check(GrayriverValidator.validate(GrayriverDefinition.data()).is_empty(),"Authored data invalid")
	var bad:=GrayriverDefinition.data()
	bad.regions[0].notes[0]["crafts"]=["unknown_formula"]
	check(GrayriverValidator.validate(bad).any(func(e):return "notes[0].crafts" in e and "unknown_formula" in e),"Bad recipe lacks source field/value diagnostic")
	var bad_chapter:=GrayriverDefinition.build()
	bad_chapter.regions[0].delivery_sites[0].methods[0].material_costs={"unknown_food":1}
	check(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(bad_chapter)).any(func(e):return "unknown_food" in e),"Unknown delivery inventory reference accepted")
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	var p:=game.player
	var supplies:=p.skill_manager.combinations.supplies
	check(p.health_component.max_hp==100 and p.mana_component.max_mp==60,"Functional test changed normal caps")
	read("river.handbook");read("river.pack")
	var before:=supplies.serialize()
	check(supplies.knows_recipe("resin") and not supplies.knows_recipe("storm_dust") and not supplies.craft("storm_dust") and supplies.serialize()==before,"Recipe discovery gate leaked inventory")
	check(station("river.relief_garden")==null,"Garden opened without delivery")
	var delivery:DeliverySiteData=game.current_data.delivery_sites[0]
	var node:ExplorationInteractable
	for child in game.region_root.get_children():
		if child is ExplorationInteractable and child.title==delivery.title:node=child
	p.position=node.position
	game.deliveries.inspect(node,delivery)
	check(not p.field_work.start_selected(),"Delivery accepted unavailable soup")
	p.field_work.selected=1
	before=supplies.serialize()
	check(p.field_work.start_selected(),"Valid dry meal refused")
	p.take_damage(1)
	check(not p.field_work.is_busy() and supplies.serialize()==before,"Interrupted handover charged")
	check(p.field_work.start_selected(),"Handover retry refused")
	p.field_work.tick(1.5)
	check(game.progress.claims.has("river.relief") and supplies.count("ration")==int(before.amounts.ration)-1 and supplies.count("clean_water")==int(before.amounts.clean_water)-1 and station("river.relief_garden")!=null,"Handover payment/world service wrong")
	before=supplies.serialize()
	check(not game.deliveries._complete(delivery.methods[1],node,delivery) and before==supplies.serialize(),"Repeat handover rewarded or charged")
	# Defeat only the local road patrol; distant enemies remain alive.
	for enemy in game.active_enemies.duplicate():
		if enemy.get_meta("frontier_group","")=="road":enemy.rewards_enabled=false;enemy.take_damage(1000)
	check(game.is_area_cleared(Vector2(-1500,350)) and game.active_enemies.size()==9,"Local completion depends on whole world clear")
	var outpost:=game.current_data.facilities[0]
	p.position=outpost.pos
	var facility:ExplorationInteractable
	for child in game.region_root.get_children():
		if child.has_meta("repair_facility") and child.get_meta("repair_facility")==outpost:facility=child
	game.alchemy.inspect(facility,outpost)
	check(p.field_work.start_selected(),"Distant enemies blocked outpost")
	p.field_work.tick(3)
	check(game.progress.claims.has("river.outpost") and station("river.outpost_pot")!=null,"Outpost did not open field cooking")
	read("river.focus");read("river.venom");read("valley.bridge_beams")
	# A real live-work completion removes physical bridge collision on the next frame.
	var bridge:=site("river.bridge_fixed")
	p.position=bridge.position
	supplies.grant({"sap":2,"charcoal":1})
	game.field_sites.inspect(bridge)
	check(p.field_work.start_selected(),"Bridge work failed")
	p.field_work.tick(4)
	for i in range(3):await process_frame
	check(game.progress.claims.has("river.bridge_fixed") and not is_instance_valid(game.terrain.bridge_body),"Bridge claim did not change geography")
	await fixture.travel("river_archive")
	read("river.pulse");read("river.echo");read("alchemy.schematic");read("survival.archive_recipe")
	await fixture.travel("river_mine")
	read("river.storm")
	check(supplies.known_recipes.size()==supplies.crafting_recipes.size(),"All authored material formulas cannot be learned")
	var regulator:=site("alchemy.regulator_open")
	p.position=regulator.position+Vector2(10,0)
	await cast("water_call",regulator.position)
	await cast("ignite",regulator.position)
	regulator.tick(.5)
	check(regulator.completed,"Real steam did not open mine regulator")
	await fixture.travel("camp",Vector2(2752,640))
	var pump:=site("alchemy.pump_open")
	p.position=pump.position+Vector2(12,0)
	for id in ["ignite","water_call","pulse"]:await cast(id,pump.position)
	check(pump.completed,"Real hit sequence did not repair pump")
	check(game.survival.water_quality(station("river.marsh_water"),station("river.marsh_water").get_meta("survival_station"))=="clean_water","Pump failed actual drinking water outcome")
	var event:ExplorationWorldEventData=game.current_data.events[0]
	check(not game.progress_service.choose_world_event(event,event.choices[0]),"Cooling bypassed actual conduction")
	var valve:SurfaceValve
	for child in game.region_root.get_children():
		if child is SurfaceValve:valve=child
	valve.cycle()
	p.position=Vector2(2500,480)
	supplies.grant({"storm_dust":1})
	supplies.configure("water_call","storm_dust")
	await cast("water_call",Vector2(2560,640))
	var conductor:=site("river.conductor")
	conductor.tick(.5)
	check(conductor.completed and supplies.selected.is_empty(),"Actual connected water/one-use material failed")
	# Nearby mill guards, rather than unrelated forest enemies, protect the wheel.
	for enemy in game.active_enemies.duplicate():
		if enemy.get_meta("frontier_group","")=="mill":enemy.rewards_enabled=false;enemy.take_damage(1000)
	check(game.progress_service.choose_world_event(event,event.choices[0]),"Powered wheel cannot select cooling")
	await fixture.travel("river_prison")
	check(game.active_enemies.back().health_component.max_hp==210,"World cooling did not affect later Boss")
	check(p.health_component.max_hp==100 and p.mana_component.max_mp==60,"Content tests inflated caps")
	await fixture.close()
	if errors.is_empty():print("Grayriver content passed: learned crafting, actual food handover/rollback, local clearing, outpost, physical bridge, real steam/pump/conduction and Boss consequence")
	quit(0 if errors.is_empty() else 1)
