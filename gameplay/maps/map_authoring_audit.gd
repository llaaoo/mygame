class_name MapAuthoringAudit
extends RefCounted
const CATALOG := "res://content/maps/grayriver/catalog.tres"
static func catalog_report() -> Dictionary:
	return _report(GrayriverDefinition.build())
static func cell_report(cell: AuthoredMapCell,registered: MapCellCatalog=null) -> Dictionary:
	if not is_instance_valid(cell): return {"errors":["Missing authored map cell"]}
	var local:=cell.validation_errors()
	if not local.is_empty(): return {"errors":local}
	if not registered and ResourceLoader.exists(CATALOG): registered=load(CATALOG) as MapCellCatalog
	if not registered: return {"errors":["Missing authored map catalog: "+CATALOG]}
	var others:=MapCellCatalog.new();var found:=false
	for scene in registered.maps:
		# Preserve empty catalog entries for append_to's returned diagnostics.
		if scene and scene.resource_path==cell.scene_file_path: found=true
		else: others.maps.append(scene)
	if not found: return {"errors":["请先保存场景并登记到 "+CATALOG+"，再检查完整连接。"]}
	# Compile the unsaved edited tree over the legacy base, never over its old compiled copy.
	var chapter:=GrayriverDefinition.build(others,false)
	if chapter.has_meta("preflight_errors"): return _report(chapter)
	var index:=-1
	for i in chapter.regions.size():
		if chapter.regions[i].id==cell.region_definition.id: index=i;break
	if index>=0 and chapter.regions[index].map_scene:
		return {"errors":[cell.source_for(cell)+": Region identity already belongs to another scene"]}
	var compiled:=cell.compile_definition(chapter.regions[index] if index>=0 else null)
	compiled.map_scene=load(cell.scene_file_path) as PackedScene
	if index>=0: chapter.regions[index]=compiled
	else: chapter.regions.append(compiled)
	MapConnections.resolve(chapter)
	var report:=_report(chapter);report["region"]=compiled
	return report
static func _report(chapter: ExplorationChapterData) -> Dictionary:
	var raw_errors: PackedStringArray=chapter.get_meta("preflight_errors",PackedStringArray())
	if not raw_errors.is_empty(): return {"errors":raw_errors,"chapter":chapter,"cells":0,"passages":0,"arrivals":0}
	var catalog:=ExplorationContentCatalog.new(chapter)
	var errors:=ExplorationContentValidator.new().validate(catalog)
	var cells:=0;var passages:=0;var arrivals:=0
	for region in chapter.regions:
		if region.map_scene: cells+=1
		passages+=region.exits.size();arrivals+=region.arrival_points.size()
	return {"errors":errors,"chapter":chapter,"cells":cells,"passages":passages,"arrivals":arrivals}
