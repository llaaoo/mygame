class_name MapPreviewGame
extends GrayriverGame
## Editor-only entry point; reuses real rules and starting budget, isolates all saves.
const REQUEST := "res://.godot/map_authoring_preview.cfg"
@export var preview_scene: PackedScene
@export var entry_anchor := ""
var preview_ready := false
var _preview_region := ""
var _preview_position := Vector2.INF
static var _reset_context: Dictionary={}
func _ready() -> void:
	persistence_enabled=false
	SaveManager.instance.repository=MemorySaveRepository.new()
	if not _reset_context.is_empty():
		preview_scene=load(_reset_context.scene) as PackedScene
		entry_anchor=str(_reset_context.arrival)
		_reset_context.clear()
	if not preview_scene:
		var request:=ConfigFile.new()
		request.load(REQUEST)
		var path: String=request.get_value("preview","scene","res://content/maps/grayriver/inn.tscn")
		preview_scene=load(path) as PackedScene
		entry_anchor=str(request.get_value("preview","arrival",""))
	if not preview_scene:
		push_error("Map preview requires a saved map scene");get_tree().quit(1);return
	var cell:=preview_scene.instantiate() as AuthoredMapCell
	if not cell:
		push_error("Map preview root must be AuthoredMapCell");get_tree().quit(1);return
	var report:=MapAuthoringAudit.cell_report(cell)
	cell.free()
	if not report.errors.is_empty():
		for error in report.errors: push_error(error)
		get_tree().quit(1);return
	var region:=report.region as ExplorationRegionData
	_preview_region=region.id
	if not entry_anchor.is_empty() and not region.arrival_points.has(entry_anchor):
		push_error("Missing preview arrival: "+entry_anchor);get_tree().quit(1);return
	_preview_position=region.arrival_points.get(entry_anchor,region.authored_entry)
	catalog=ExplorationContentCatalog.new(report.chapter)
	super._ready()
	call_deferred("_prepare_preview")
func start_location() -> Dictionary:
	if not progress.journey.is_empty(): return super.start_location()
	return {"region":_preview_region,"position":_preview_position}
func _prepare_preview() -> void:
	while not ready_for_play: await get_tree().process_frame
	ui.close_modal()
	var layer:=CanvasLayer.new();layer.layer=130;add_child(layer)
	var panel:=PanelContainer.new();panel.position=Vector2(260,8);panel.size=Vector2(650,80)
	panel.add_theme_stylebox_override("panel",GameUIStyle.panel_style(.95));layer.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	box.add_child(FoundationWidgets.label("地图试玩 · "+current_data.title,17))
	box.add_child(FoundationWidgets.label("独立内存存档 · 默认人物预算与正常AI · F5/F9只影响本次试玩",12,true))
	var row:=HBoxContainer.new();box.add_child(row)
	row.add_child(FoundationWidgets.button("重置地图试玩",func():
		_reset_context={"scene":preview_scene.resource_path,"arrival":entry_anchor}
		get_tree().reload_current_scene()))
	row.add_child(FoundationWidgets.button("退出地图试玩",func():get_tree().quit()))
	preview_ready=true
	print("Map preview ready: %s; in-memory saves; normal AI and default budget"%region_id)
