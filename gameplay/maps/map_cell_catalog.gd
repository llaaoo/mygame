class_name MapCellCatalog
extends Resource
## Add a cell/overlay in the Inspector; chapter assembly compiles its typed markers.
@export var maps: Array[PackedScene] = []
func append_to(chapter: ExplorationChapterData) -> void:
	for scene in maps:
		if not scene:
			push_error("Missing authored map scene")
			continue
		var instance:=scene.instantiate()
		var view:=instance as AuthoredMapCell
		if not view or not view.region_definition:
			instance.free()
			push_error("Invalid authored map scene")
			continue
		var id:=view.region_definition.id
		view.free()
		var existing: ExplorationRegionData
		for region in chapter.regions:
			if region.id==id: existing=region; break
		if existing and existing.map_scene:
			existing.map_errors.append("Multiple authored scenes assigned to region: "+id)
			continue
		var compiled:=AuthoredMapCell.compile(scene,existing)
		if not existing: chapter.regions.append(compiled)
