@tool
class_name AuthoredMapCell
extends Node2D
## A Godot scene is the spatial authority. Existing typed Resources own rules.
@export var region_definition: ExplorationRegionData
@export_enum("wood", "stone", "ground", "overlay") var floor_style := "wood":
	set(value): floor_style=value; queue_redraw()
@export var floor_tint := Color("706555"):
	set(value): floor_tint=value; queue_redraw()
var _preview_extent := Vector2.ZERO

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(validation_errors())

static func compile(scene: PackedScene, overlay: ExplorationRegionData=null) -> ExplorationRegionData:
	if not scene or not scene.can_instantiate(): return null
	var instance:=scene.instantiate()
	var map:=instance as AuthoredMapCell
	if not map or not map.region_definition:
		instance.free()
		return null
	var result:=map.compile_definition(overlay)
	result.map_scene=scene
	map.free()
	return result

func compile_definition(overlay: ExplorationRegionData=null) -> ExplorationRegionData:
	# Repeated builds never append into the source definition or a previous result.
	var result:=overlay.duplicate(true) as ExplorationRegionData if overlay else region_definition.duplicate(true) as ExplorationRegionData
	result.map_errors=PackedStringArray(validation_errors())
	for child in find_children("*","",true,false):
		if child is MapFurniture and child.solid:
			result.authored_obstacles.append({"position":point_for(child),"size":child.footprint,"kind":"map_furniture","map_source":source_for(child)})
		elif child is MapArrival:
			result.arrival_points[child.id]=point_for(child)
			result.map_arrival_rules[child.id]={"minimum_enemy_distance":child.minimum_enemy_distance,"map_source":source_for(child),"default_entry":child.default_entry}
			if child.default_entry: result.authored_entry=point_for(child)
		elif child is MapFeature and child.definition:
			var collection:=MapFeature.collection_for(child.definition)
			if collection.is_empty(): continue
			var copy: Resource=child.definition.duplicate(true)
			copy.pos=point_for(child)
			copy.set_meta("map_source",source_for(child))
			if copy is ExplorationEncounterData:
				copy.set_meta("persistent_id",copy.persistent_id)
				copy.set_meta("group",copy.group if not copy.group.is_empty() else result.id)
			if copy is SurfaceValveData:
				for path in copy.paths:
					if path:
						for i in path.points.size(): path.points[i]+=copy.pos
			var entries: Array=result.get(collection)
			entries.append(copy)
	return result

func source_for(node: Node) -> String:
	return "%s::%s"%[scene_file_path,get_path_to(node)]

func point_for(node: Node2D) -> Vector2:
	var point:=Vector2.ZERO
	var cursor: Node=node
	while cursor and cursor!=self:
		if cursor is Node2D: point+=cursor.position
		cursor=cursor.get_parent()
	return point

func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if not region_definition: errors.append(source_for(self)+": Map cell requires a region definition")
	elif region_definition.id.is_empty() or region_definition.id.begins_with("change_me"): errors.append(source_for(self)+": Replace the template region identity before registration")
	elif not region_definition.authored_size.is_finite() or region_definition.authored_size.x<320 or region_definition.authored_size.y<320 or region_definition.authored_size.x>24000 or region_definition.authored_size.y>24000: errors.append(source_for(self)+": Map cell bounds must be finite, between 320 and 24000")
	elif region_definition.authored_entry!=Vector2.ZERO: errors.append(source_for(self)+": Set default entry on a MapArrival node, not Resource.authored_entry")
	if position!=Vector2.ZERO or rotation!=0 or scale!=Vector2.ONE: errors.append(source_for(self)+": Map root transform must be identity")
	var anchors: Dictionary={};var default_count:=0
	for child in find_children("*","",true,false):
		var at:=source_for(child)+": "
		if child is AuthoredMapCell: errors.append(at+"Use Node2D prefab groups; connect separate map cells with passages")
		if child is Node2D and (not child.position.is_finite() or child.rotation!=0 or child.scale!=Vector2.ONE): errors.append(at+"Map transforms support translation only")
		if child is MapFurniture and (not child.footprint.is_finite() or child.footprint.x<=0 or child.footprint.y<=0): errors.append(at+"Invalid furniture footprint")
		if child is MapArrival:
			if child.id.is_empty() or anchors.has(child.id): errors.append(at+"Missing/duplicate arrival identity: "+child.id)
			anchors[child.id]=true
			if child.default_entry: default_count+=1
			if not is_finite(child.minimum_enemy_distance) or child.minimum_enemy_distance<0 or child.minimum_enemy_distance>2000: errors.append(at+"Invalid enemy clearance")
		if child is MapFeature:
			if MapFeature.collection_for(child.definition).is_empty(): errors.append(at+"Unsupported map feature")
			elif child.definition.pos!=Vector2.ZERO: errors.append(at+"Set feature position on the Node2D, not Resource.pos")
			if child.definition is ExplorationExitData:
				if child.definition.id.is_empty(): errors.append(at+"Authored passage requires a stable id")
				if not child.definition.target_anchor.is_empty() and child.definition.arrival!=Vector2.INF: errors.append(at+"Use target_anchor or arrival coordinates, not both")
			if child.definition is ExplorationEncounterData and child.definition.persistent_id.is_empty(): errors.append(at+"Authored encounter requires a persistent_id")
			if child.definition is SurfacePatchData and (not is_finite(child.definition.radius) or child.definition.radius<=0 or child.definition.radius>1024): errors.append(at+"Authored surface radius must be finite, within 0–1024")
	if default_count!=1: errors.append(source_for(self)+": Map requires exactly one default entry marker")
	return errors

func mount_collision(layout: RunRoomLayout) -> void:
	# The very same rectangles feed pathfinding, collision and the local map.
	for spec in layout.obstacles: _body(spec.position,spec.size)
	var half:=layout.arena_size*.5
	_body(Vector2(0,-half.y-16),Vector2(layout.arena_size.x+64,32))
	_body(Vector2(0,half.y+16),Vector2(layout.arena_size.x+64,32))
	_body(Vector2(-half.x-16,0),Vector2(32,layout.arena_size.y))
	_body(Vector2(half.x+16,0),Vector2(32,layout.arena_size.y))

func _body(point: Vector2,extent: Vector2) -> void:
	var body:=StaticBody2D.new()
	body.position=point; body.collision_layer=1; body.collision_mask=0
	var collision:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=extent; collision.shape=shape
	body.add_child(collision); add_child(body)

func _ready() -> void:
	z_index=-110
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint(): set_process(false); return
	if region_definition and _preview_extent!=region_definition.authored_size:
		_preview_extent=region_definition.authored_size
		queue_redraw()

func _draw() -> void:
	if not region_definition or floor_style=="overlay": return
	var extent:=region_definition.authored_size
	var r:=Rect2(-extent*.5,extent)
	draw_rect(r.grow(28),Color("252d2b"))
	draw_rect(r,floor_tint)
	var step:=Vector2(96,24) if floor_style=="wood" else Vector2(48,48)
	for row in range(ceili(extent.y/step.y)):
		for col in range(ceili(extent.x/step.x)):
			var at:=r.position+Vector2(col,row)*step
			var shade: float=posmod(col*7+row*3,5)*.012
			draw_rect(Rect2(at+Vector2.ONE,step-Vector2.ONE*2),floor_tint.lightened(shade))
	if floor_style=="wood":
		for y in range(int(r.position.y)+12,int(r.end.y),24): draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color(0,0,0,.07),1)
	draw_rect(r.grow(8),Color("a2906d"),false,8)
	draw_rect(r.grow(20),Color("474b40"),false,12)
