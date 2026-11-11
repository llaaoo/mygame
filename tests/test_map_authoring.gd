extends SceneTree
const Budget=preload("res://tests/support/map_content_snapshot.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func run() -> void:
	var report:=MapAuthoringAudit.catalog_report()
	check(report.errors.is_empty() and report.cells==5,"Registered outdoor/interior/dungeon maps did not pass their common pipeline")
	var chapter:=report.chapter as ExplorationChapterData
	var catalog:=ExplorationContentCatalog.new(chapter)
	var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/archive_pre_scene_budget.json"))
	var archive_budget:=Budget.archive(catalog.regions.river_archive)
	# The adventure pass adds exactly two shelves and one conditional return.
	# Keep the pre-scene fixture intact: every old enemy, note/reward, surface,
	# obstacle and unconditional return must still match it exactly, except the
	# shared landing was deliberately moved out of a live enemy's detection range.
	check(archive_budget.obstacles.size()==expected.obstacles.size()+2 and archive_budget.exits.size()==expected.exits.size()+1,"Archive adventure changed its declared spatial additions")
	var retained_budget:=archive_budget.duplicate(true)
	retained_budget.obstacles=retained_budget.obstacles.slice(0,expected.obstacles.size())
	retained_budget.exits=retained_budget.exits.slice(0,expected.exits.size())
	var camp:=catalog.regions.camp as ExplorationRegionData
	var shared_arrival: Vector2=camp.arrival_points.archive_return
	check(shared_arrival==Vector2(-2700,-1800) and float(camp.map_arrival_rules.archive_return.minimum_enemy_distance)==520.0,"Archive shared return landing or declared enemy clearance changed")
	for foe in camp.encounters:
		check(shared_arrival.distance_to(foe.pos)>=foe.detect_range+80,"Archive return lands within enemy detection plus interaction clearance")
	var named_returns:=0
	for passage in catalog.regions.river_archive.exits:
		if passage.target=="camp" and passage.target_anchor=="archive_return":
			named_returns+=1
			check(passage.arrival==shared_arrival,"A return copied coordinates instead of resolving the shared landing")
	check(named_returns==2,"Original exit and new shaft do not share one named safe landing")
	# Normalize only the explicitly asserted safety change before comparing every
	# other old budget field; the checked-in historical fixture remains untouched.
	retained_budget.exits[0].arrival=expected.exits[0].arrival.duplicate()
	check(retained_budget==expected,"Archive adventure changed original enemies, knowledge, rewards, surfaces, collision or return identity")
	# Resource.duplicate copies exported definitions, not the compiler's transient
	# arrival dictionaries. Recompile an independent chapter so this negative case
	# exercises the actual authored arrival rule instead of a stripped clone.
	var unsafe_camp:=ExplorationContentCatalog.new(GrayriverDefinition.build()).regions.camp as ExplorationRegionData
	check(unsafe_camp.map_arrival_rules.has("archive_return"),"Negative arrival fixture lost compiled map rules")
	unsafe_camp.encounters[0].pos=shared_arrival
	check(MapGeometry.errors(unsafe_camp).any(func(error: String):return "Enemy inside arrival clearance: archive_return" in error),"Moving an enemy onto the return landing did not fail authoring validation")
	var missing:=MapCellCatalog.new();missing.maps=[null]
	check(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(GrayriverDefinition.build(missing))).any(func(e):return "Missing authored map scene" in e),"A missing scene printed an error but passed the returned validation report")
	check(AuthoredMapCell.compile(PackedScene.new())==null,"An empty scene was instantiated instead of rejected")
	var overlay:=ExplorationRegionData.new();overlay.id="camp"
	var town_scene:=load("res://content/maps/grayriver/town_sites.tscn") as PackedScene
	var first:=AuthoredMapCell.compile(town_scene,overlay);var again:=AuthoredMapCell.compile(town_scene,overlay)
	check(overlay.exits.is_empty() and overlay.authored_obstacles.is_empty() and overlay.map_scene==null and first.exits.size()==again.exits.size(),"Repeated overlay compilation appended into its source or accumulated doors")
	var source:=load("res://content/maps/grayriver/inn.tscn") as PackedScene
	var cell:=source.instantiate() as AuthoredMapCell
	var entry:=cell.get_node("默认入口落点") as MapArrival;entry.position+=Vector2(80,0)
	report=MapAuthoringAudit.cell_report(cell)
	var edited:=ExplorationContentCatalog.new(report.chapter)
	var incoming: ExplorationExitData=edited.regions.camp.exits.filter(func(p):return p.target=="river_inn")[0]
	check(report.errors.is_empty() and incoming.arrival==Vector2(80,280) and edited.regions.river_inn.authored_entry==Vector2(80,280),"Moving a named entry did not update all incoming doors and default spawn")
	check(AuthoredMapCell.compile(source).authored_entry==Vector2(0,280),"Live compilation mutated the original scene/shared definition")
	var door:=cell.get_node("离开灰苇客栈") as MapFeature
	# Duplicate the definition; editing the test must not mutate the loaded source.
	door.definition=door.definition.duplicate(true);door.definition.target_anchor="missing"
	report=MapAuthoringAudit.cell_report(cell)
	check(report.errors.any(func(e):return "Missing target arrival" in e and "离开灰苇客栈" in e),"Dangling anchor lacks a precise scene/node diagnostic")
	door.definition.target_anchor="inn_return";door.definition.return_exit="archive.enter"
	report=MapAuthoringAudit.cell_report(cell)
	check(report.errors.any(func(e):return "Mismatched return passage" in e),"A door paired with another building's return passed")
	door.definition.return_exit="town.inn.enter";door.definition.requires_clear=true
	report=MapAuthoringAudit.cell_report(cell)
	check(report.errors.any(func(e):return "Primary return route must be unconditional" in e),"An authored escape route could require clearing its own room")
	door.definition.requires_clear=false
	var duplicate:=MapArrival.new();duplicate.id="entry";cell.add_child(duplicate)
	check(cell.validation_errors().any(func(e):return "duplicate arrival" in e),"Duplicate landing identity was accepted")
	cell.free()
	# A real sealed wall, not a misplaced point: both sides are walkable but disconnected.
	cell=AuthoredMapCell.new();cell.region_definition=ExplorationRegionData.new();cell.region_definition.id="geometry";cell.region_definition.authored_size=Vector2(800,640)
	entry=MapArrival.new();entry.default_entry=true;entry.position=Vector2(-250,0);cell.add_child(entry)
	var wall:=MapFurniture.new();wall.name="sealed_wall";wall.footprint=Vector2(40,640);cell.add_child(wall)
	var feature:=MapFeature.new();feature.name="unreachable_note";feature.position=Vector2(250,0);feature.definition=ExplorationDiscoveryData.new();feature.definition.id="test.note";cell.add_child(feature)
	var compiled:=cell.compile_definition();compiled.map_scene=source
	check(MapGeometry.errors(compiled).any(func(e):return "Unreachable" in e and "unreachable_note" in e),"A sealed-off interaction passed navigation validation")
	wall.footprint.y=200;compiled=cell.compile_definition();compiled.map_scene=source
	check(MapGeometry.errors(compiled).is_empty(),"Opening an actual corridor did not restore reachability")
	cell.free()
	# Prefab group translation must move valve channels as well as their controller.
	cell=AuthoredMapCell.new();cell.region_definition=ExplorationRegionData.new();cell.region_definition.id="prefab";cell.region_definition.authored_size=Vector2(800,640)
	entry=MapArrival.new();entry.default_entry=true;cell.add_child(entry)
	var group:=Node2D.new();group.position=Vector2(100,50);cell.add_child(group)
	var valve:=SurfaceValveData.new();var path:=WaterPathData.new();path.points=PackedVector2Array([Vector2(32,0)]);valve.paths=[path]
	feature=MapFeature.new();feature.definition=valve;group.add_child(feature)
	compiled=cell.compile_definition()
	check(compiled.valves[0].pos==Vector2(100,50) and compiled.valves[0].paths[0].points[0]==Vector2(132,50) and path.points[0]==Vector2(32,0),"Moving an authored valve prefab left its channel behind or mutated its shared Resource")
	cell.free()
	if failures.is_empty(): print("PASS map authoring: real outdoor/interior/dungeon catalog, pre-migration archive budget/IDs, live named-entry propagation, immutable sources, exact missing-anchor/return diagnostics, duplicate arrivals, sealed-wall reachability and translated valve prefabs")
	quit(0 if failures.is_empty() else 1)
