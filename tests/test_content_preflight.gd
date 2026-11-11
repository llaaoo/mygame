extends SceneTree
## Authoring failures remain returned diagnostics, never engine/script errors or
## partial chapters. Fixtures modify copies, not the published JSON/resources.
var failures: Array[String]=[]
const SOURCE := "fixture://grayriver-invalid.json"
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func reject(raw: Variant,field: String,value := "") -> void:
	var errors:=GrayriverValidator.validate(raw,SOURCE)
	check(errors.any(func(message: String): return field in message and (value.is_empty() or value in message)),"Missing precise authoring diagnostic: "+field+" / "+value)
	var chapter:=GrayriverDefinition.build_from_data(raw,null,true,SOURCE)
	check(chapter.regions.is_empty() and chapter.actions.is_empty() and chapter.quests.is_empty(),"Invalid raw content was partially assembled: "+field)
	var report:=MapAuthoringAudit._report(chapter)
	check(report.errors==PackedStringArray(errors) and report.cells==0,"Map authoring failed to retain the same preflight diagnostics: "+field)
func run() -> void:
	var text:=FileAccess.get_file_as_string(GrayriverDefinition.PATH)
	var parsed:=GrayriverDefinition.parse_source(text)
	check(parsed.errors.is_empty(),"Published JSON failed raw preflight")
	var original: Dictionary=parsed.data
	var bad_text:=GrayriverDefinition.parse_source("{\n\"regions\": [",SOURCE)
	check(bad_text.errors.size()==1 and bad_text.errors[0].begins_with(SOURCE+":") and "invalid JSON" in bad_text.errors[0],"Malformed JSON did not retain file/line/parser diagnostics")
	check(GrayriverDefinition.parse_source("[]",SOURCE).errors.any(func(message: String): return SOURCE in message and "object" in message),"Non-object JSON root passed preflight")
	check(GrayriverDefinition.read_source("user://missing-authoring-input.json").errors.size()==1,"Missing source file was silently accepted")
	reject({"regions":[]},SOURCE+".roads")
	var bad:=original.duplicate(true); bad.regions="not an array"
	reject(bad,SOURCE+".regions")
	bad=original.duplicate(true); bad.regions[0]=null
	reject(bad,SOURCE+".regions[0]")
	bad=original.duplicate(true); bad.regions[0].notes[0].template="unknown_area/missing"
	reject(bad,SOURCE+".regions[0].notes[0].template","unknown_area/missing")
	bad=original.duplicate(true); bad.regions[0].notes[0].template="camp/missing_discovery"
	reject(bad,SOURCE+".regions[0].notes[0].template","camp/missing_discovery")
	bad=original.duplicate(true); bad.regions[0].puzzles[0].template="alchemy/missing_puzzle"
	reject(bad,SOURCE+".regions[0].puzzles[0].template","missing_puzzle")
	bad=original.duplicate(true); bad.regions[0].puzzles[0].template="alchemy/facility"
	reject(bad,SOURCE+".regions[0].puzzles[0].template","unexpected resource type")
	bad=original.duplicate(true); bad.regions[0].facilities[0]={"pos":[0,0],"template":"alchemy/missing_facility"}
	reject(bad,SOURCE+".regions[0].facilities[0].template","missing_facility")
	bad=original.duplicate(true); bad.regions[0].notes[0].pos=[0]
	reject(bad,SOURCE+".regions[0].notes[0].pos","two coordinates")
	bad=original.duplicate(true); bad.regions[0].entry=[0,"south"]
	reject(bad,SOURCE+".regions[0].entry[1]")
	bad=original.duplicate(true); bad.regions[0].size=[0,7200]
	reject(bad,SOURCE+".regions[0].size[0]")
	bad=original.duplicate(true); bad.regions[0].encounters[0].character="missing_character"
	reject(bad,SOURCE+".regions[0].encounters[0].character","missing_character")
	bad=original.duplicate(true); bad.regions[0].encounters[0].profile="missing_profile"
	reject(bad,SOURCE+".regions[0].encounters[0].profile","missing_profile")
	bad=original.duplicate(true); bad.regions[0].obstacles=[null,{"position":[0,0],"size":[40,40],"kind":"wall"}]
	reject(bad,SOURCE+".regions[0].obstacles[0]")
	bad=original.duplicate(true); bad.regions[0].notes=[null,original.regions[0].notes[0]]
	reject(bad,SOURCE+".regions[0].notes[0]")
	bad=original.duplicate(true); bad.roads[0][0]=[0]
	reject(bad,SOURCE+".roads[0][0]")
	bad=original.duplicate(true); bad.regions[0].notes[0].materials={"charcoal":"two"}
	reject(bad,SOURCE+".regions[0].notes[0].materials.charcoal")
	bad=original.duplicate(true); bad.regions[0].valves=[{"id":"fixture.valve","title":"valve","pos":[0,0],"paths":[{"title":"path","points":[[0]]}]}]
	reject(bad,SOURCE+".regions[0].valves[0].paths[0].points[0]")
	# Both legal entry points preserve authored input, inherited budgets and full
	# domain validation. Existing map authoring tests retain migration budgets.
	var before:=JSON.stringify(original)
	var chapter:=GrayriverDefinition.build_from_data(original)
	check(not chapter.has_meta("preflight_errors") and chapter.regions.size()>original.regions.size(),"Legal raw content failed to compile with registered map cells")
	check(JSON.stringify(original)==before,"Preflight/build mutated the source dictionary")
	var catalog:=ExplorationContentCatalog.new(chapter)
	check(ExplorationContentValidator.new().validate(catalog).is_empty(),"Legal preflight bypassed or broke full typed content validation")
	var legacy:=ExplorationContentCatalog.new()
	var inherited: ExplorationDiscoveryData
	for note in legacy.regions.camp.discoveries:
		if note.id=="material_handbook": inherited=note
	var handbook:=catalog.fact("river.handbook").definition as ExplorationDiscoveryData
	check(inherited!=null and handbook.materials==inherited.materials and handbook.actions.has("water_call"),"Validated template assembly changed existing inherited materials or knowledge")
	var public_build:=GrayriverDefinition.build()
	check(not public_build.has_meta("preflight_errors") and public_build.regions.size()==chapter.regions.size(),"File-based builder differs from validated in-memory assembly")
	# The editor's current-cell entry must preserve catalog errors before it
	# compiles the live tree; a blank Inspector slot must not dereference null.
	var map_catalog:=load(MapAuthoringAudit.CATALOG).duplicate() as MapCellCatalog
	map_catalog.maps.append(null)
	var cell:=load("res://content/maps/grayriver/inn.tscn").instantiate() as AuthoredMapCell
	var cell_report:=MapAuthoringAudit.cell_report(cell,map_catalog)
	check(cell_report.errors.any(func(message: String):return "Missing authored map scene" in message),"Current-cell editor audit swallowed an empty registered map entry")
	cell.free()
	# Real product startup, using only isolated user:// authoring fixtures. Keep a
	# nondefault SaveManager slot and existing files as sentinels for early abort.
	DirAccess.make_dir_recursive_absolute("user://journey_archive/preflight-existing")
	var protected_paths: Array[String]=["user://save_3.sav","user://save_3.sav.bak","user://journey_archive/preflight-existing/latest.sav"]
	for path in protected_paths:
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(("existing journey: "+path).to_utf8_buffer()); file.close()
	var malformed:=original.duplicate(true); malformed.regions[0].notes[0].pos=[0]
	for sample in ["{invalid",JSON.stringify(malformed)]:
		var fixture_path:="user://invalid-grayriver-startup.json"
		var input:=FileAccess.open(fixture_path,FileAccess.WRITE); input.store_string(sample); input.close()
		var previous: Dictionary={}
		for path in protected_paths: previous[path]=FileAccess.get_file_as_bytes(path)
		var game:=load("res://grayriver.tscn").instantiate() as GrayriverGame
		game.source_path=fixture_path
		var saves:=SaveManager.new(); saves.name="SaveManager"; saves.active_slot=7
		game.get_node("GameRuntime").add_child(saves)
		root.add_child(game); current_scene=game
		for i in 8: await process_frame
		check(game.session==null and game.progress_service==null and not game.ready_for_play and not game.is_processing(),"Bad product startup entered bootstrap/services or kept processing")
		check(game.get_node("Player").process_mode==Node.PROCESS_MODE_DISABLED and not game.persistence_enabled,"Bad product startup left the player/save path active")
		var diagnostics:=game.get_node_or_null("StartupError").find_child("Diagnostics",true,false) as Label if game.has_node("StartupError") else null
		check(diagnostics!=null and diagnostics.is_visible_in_tree() and fixture_path in diagnostics.text,"Product startup did not display readable source diagnostics")
		check(saves.active_slot==7 and saves.last_read==null and saves.repository.sections.owner_for("grayriver_frontier")==null,"Failed startup selected/loaded/registered the campaign save")
		for path in protected_paths: check(FileAccess.get_file_as_bytes(path)==previous[path],"Failed startup changed existing journey/archive bytes: "+path)
		var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
		if not output.is_empty() and DisplayServer.get_name()!="headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("startup-invalid-json.png" if sample=="{invalid" else "startup-invalid-position.png"))
		game.queue_free(); current_scene=null
		for i in 6: await process_frame
	if failures.is_empty(): print("PASS content preflight: malformed JSON and raw shapes, absent/wrong template resources, precise nested fields, no partial assembly, shared map diagnostics, legal source immutability and inherited budgets")
	quit(0 if failures.is_empty() else 1)
