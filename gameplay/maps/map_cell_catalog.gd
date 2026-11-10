class_name MapCellCatalog
extends Resource
## Add a cell/overlay in the Inspector; chapter assembly compiles its typed markers.
@export var maps: Array[PackedScene] = []
func append_to(chapter: ExplorationChapterData,resolve_connections := true) -> void:
	var errors: PackedStringArray=chapter.get_meta("map_catalog_errors",PackedStringArray())
	for scene in maps:
		if not scene or not scene.can_instantiate():
			errors.append("Missing authored map scene in catalog")
			continue
		var instance:=scene.instantiate()
		var view:=instance as AuthoredMapCell
		if not view or not view.region_definition:
			instance.free()
			errors.append("Invalid authored map scene: "+scene.resource_path)
			continue
		var id:=view.region_definition.id
		view.free()
		var existing: ExplorationRegionData;var index:=-1
		for i in chapter.regions.size():
			if chapter.regions[i].id==id: existing=chapter.regions[i];index=i;break
		if existing and existing.map_scene:
			existing.map_errors.append("Multiple authored scenes assigned to region: "+id)
			continue
		var compiled:=AuthoredMapCell.compile(scene,existing)
		if not existing: chapter.regions.append(compiled)
		else: chapter.regions[index]=compiled
	chapter.set_meta("map_catalog_errors",errors)
	if resolve_connections: MapConnections.resolve(chapter)
