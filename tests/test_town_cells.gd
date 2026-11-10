extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var scene:=load("res://content/maps/grayriver/inn.tscn") as PackedScene
	var editor:=scene.instantiate() as AuthoredMapCell
	var marker:=editor.get_node("旅人寄存箱") as MapFeature
	var original:=marker.definition as WorldStorageData
	marker.position+=Vector2(48,0)
	var packed:=PackedScene.new()
	check(packed.pack(editor)==OK,"Edited cell did not pack")
	var moved:=AuthoredMapCell.compile(packed)
	check(moved.storage[0].pos==Vector2(-472,200) and original.pos==Vector2.ZERO and AuthoredMapCell.compile(scene).storage[0].pos==Vector2(-520,200),"Scene editing failed to move content or mutated the shared Resource")
	marker.rotation=.1
	check(not editor.validation_errors().is_empty(),"Unsupported rotated marker was silently compiled")
	editor.free()
	var chapter:=GrayriverDefinition.build()
	for region in chapter.regions:
		if region.id=="river_inn":
			region.authored_obstacles.append({"position":region.storage[0].pos,"size":Vector2(80,80),"kind":"map_furniture"})
	var rejected:=ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter))
	check(rejected.any(func(message: String): return message.contains("Interaction blocked by geometry")),"Bad authored geometry was silently repaired or accepted")
	var fixture:=Fixture.new(self); var game:=await fixture.boot(true)
	var store:=game.session.inventory
	for id in ["river_inn","river_workshop","river_records"]:
		var data:=game.catalog.regions[id] as ExplorationRegionData
		var layout:=data.make_layout(); var count:=layout.obstacles.size()
		data.reserve_interaction_space(layout)
		check(data.map_scene!=null and count==layout.obstacles.size() and not data.exits.is_empty(),"Authored cell erased furniture or has no exit: "+id)
		var passage:=game.catalog.passage_toward("camp",id,game.progress,game.player.position)
		check(passage!=null and game.guidance.overworld_point(id).distance_to(passage.pos)<81,"Cell return topology or overworld anchor wrong: "+id)
	# Cell travel retains vitals, and the new indoor resident has her own finite stock.
	game.player.health_component.hp=57; game.player.mana_component.mp=23
	await fixture.travel("river_inn")
	check(game.is_at_base() and game.player.health_component.hp==57 and game.player.mana_component.mp==23,"Entering a house healed/refilled the player or lost base needs policy")
	var keeper:=game.session.actor_for_id("river.innkeeper") as ServiceNPC
	check(keeper!=null and keeper.get_parent()==game.region_root and store.count("river.innkeeper","coin")==16,"Indoor host is not a real independently owned actor")
	var adapter:=game.residents.adapter_for("river.innkeeper")
	check(not adapter.market.equipment_services and not adapter.market.production_services and not adapter.salvage("missing",true).accepted,"Inn falsely offers blacksmith/production services")
	var spec:=game.current_data.storage[0] as WorldStorageData
	game.player.position=spec.pos+Vector2(0,25)
	store.receive("player","resin_sprayer",1)
	var uid:=store.find_owned("player","resin_sprayer")
	check(store.spend_instance("player",uid,"doses",1),"Could not create a genuinely used spray fixture")
	var gen:=game.session.region.generation
	check(game.world_storage.transfer(spec,uid,1,spec.id,gen).accepted and store.locate(uid)==spec.id and store.item(uid).properties.doses==2,"Deposit lost actual spray identity or remainder")
	check(game.world_storage.transfer(spec,uid,1,"player.pack",gen).accepted and store.item(uid).properties.doses==2,"Withdrawal refilled spray or failed to use actual pack")
	check(game.world_storage.transfer(spec,uid,1,spec.id,gen).accepted,"Second deposit refused")
	var common:=game.current_data.storage[1] as WorldStorageData
	game.player.position=common.pos+Vector2(0,20)
	var grain: Dictionary=store.entries(common.id).filter(func(row: Dictionary): return row.definition=="grain")[0]
	check(game.world_storage.transfer(common,grain.uid,grain.quantity,"player.pack",gen).accepted,"Public stock could not be taken")
	var cloth: Dictionary=store.entries(common.id)[0]
	check(game.world_storage.transfer(common,cloth.uid,cloth.quantity,"player.pack",gen).accepted and store.entries(common.id).is_empty(),"Public stock was not depleted")
	# Stale callbacks and full containers must fail without half-transfers.
	var before:=store.snapshot()
	await fixture.travel("camp")
	check(not game.world_storage.transfer(spec,uid,1,"player.pack",gen).accepted and store.snapshot()==before,"Stale room callback moved items across cells")
	await fixture.travel("river_inn")
	check(store.entries(common.id).is_empty() and store.item(uid).properties.doses==2,"Re-entry reseeded an empty fixed container or refilled an instance")
	game.player.position=spec.pos+Vector2(0,25)
	while store.entries(spec.id).size()<spec.capacity: store.receive_into(spec.id,"river_sabre",1)
	var incoming:=str(grain.uid)
	before=store.snapshot()
	check(not game.world_storage.transfer(spec,incoming,1,spec.id).accepted and store.snapshot()==before,"Full storage partially removed a real carried stack")
	# A real wall blocks F targeting and the transfer boundary, not merely a tooltip.
	var wall:=StaticBody2D.new();wall.collision_layer=1;wall.collision_mask=0;wall.position=spec.pos+Vector2(0,12)
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(100,4);shape.shape=rectangle;wall.add_child(shape);game.region_root.add_child(wall)
	await physics_frame;await physics_frame
	check(not game.world_storage.reason(spec).is_empty() and game.player.input_controller.interaction_target(true)==null,"A wall did not block storage/F focus")
	wall.queue_free();await physics_frame;await physics_frame
	game.guidance.set_waypoint(Vector2(-450,-100),"river_inn")
	game.player.position=Vector2(0,350)
	game._save_progress()
	var expected:=store.entries(spec.id);var waypoint:=game.progress.waypoint.duplicate(true)
	await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true)
	check(game.region_id=="river_inn" and game.session.inventory.entries(spec.id)==expected and game.session.inventory.entries(common.id).is_empty() and game.progress.waypoint==waypoint,"Saved interior location, persistent empty container, UID/doses or local waypoint was lost")
	check(game.session.actor_for_id("river.innkeeper")!=null,"Saved indoor NPC did not remount")
	check(game.player.position.distance_to(Vector2(0,350))<1,"Door-side save was incorrectly treated as an enemy spawn reservation")
	await fixture.close()
	if failures.is_empty(): print("PASS town cells: editable scene compilation, immutable definitions, closed collision/routes, actual indoor host/market, no arrival healing, fixed stock depletion, persistent UID/doses, capacity rollback, wall and stale callback rejection, real save/re-entry and local waypoint")
	quit(0 if failures.is_empty() else 1)
