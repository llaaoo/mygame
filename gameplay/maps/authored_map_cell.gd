@tool
class_name AuthoredMapCell
extends Node2D
## A Godot scene is the spatial authority. Existing typed Resources own rules.
@export var region_definition: ExplorationRegionData
@export_enum("wood", "stone", "overlay") var floor_style := "wood":
	set(value): floor_style=value; queue_redraw()
@export var floor_tint := Color("706555"):
	set(value): floor_tint=value; queue_redraw()
var _preview_extent := Vector2.ZERO

static func compile(scene: PackedScene, overlay: ExplorationRegionData=null) -> ExplorationRegionData:
	var instance:=scene.instantiate()
	var map:=instance as AuthoredMapCell
	if not map or not map.region_definition:
		instance.free()
		return null
	var result:=overlay if overlay else map.region_definition.duplicate(true) as ExplorationRegionData
	result.map_scene=scene
	result.map_errors=PackedStringArray(map.validation_errors())
	for child in map.find_children("*","",true,false):
		if child is MapFurniture and child.solid:
			result.authored_obstacles.append({"position":map.point_for(child),"size":child.footprint,"kind":"map_furniture"})
		elif child is MapFeature and child.definition:
			var copy: Resource=child.definition.duplicate(true)
			copy.pos=map.point_for(child)
			if copy is ExplorationExitData: result.exits.append(copy)
			elif copy is ExplorationDiscoveryData: result.discoveries.append(copy)
			elif copy is SurvivalStationData: result.survival_stations.append(copy)
			elif copy is MapAmenityData: result.amenities.append(copy)
			elif copy is WorldStorageData: result.storage.append(copy)
	map.free()
	return result

func point_for(node: Node2D) -> Vector2:
	var point:=Vector2.ZERO
	var cursor: Node=node
	while cursor and cursor!=self:
		if cursor is Node2D: point+=cursor.position
		cursor=cursor.get_parent()
	return point

func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if not region_definition: errors.append("Map cell requires a region definition")
	elif not region_definition.authored_size.is_finite() or region_definition.authored_size.x<320 or region_definition.authored_size.y<320: errors.append("Map cell requires finite authored bounds")
	if position!=Vector2.ZERO or rotation!=0 or scale!=Vector2.ONE: errors.append("Map root transform must be identity")
	for child in find_children("*","",true,false):
		if child is Node2D and (not child.position.is_finite() or child.rotation!=0 or child.scale!=Vector2.ONE): errors.append("Map transforms support translation only: "+str(child.name))
		if child is MapFurniture and (not child.footprint.is_finite() or child.footprint.x<=0 or child.footprint.y<=0): errors.append("Invalid furniture footprint: "+str(child.name))
		if child is MapFeature and not (child.definition is ExplorationExitData or child.definition is ExplorationDiscoveryData or child.definition is SurvivalStationData or child.definition is MapAmenityData or child.definition is WorldStorageData): errors.append("Unsupported map feature: "+str(child.name))
		if child is MapFeature and child.definition and "pos" in child.definition and child.definition.pos!=Vector2.ZERO: errors.append("Set feature position on the Node2D, not Resource.pos: "+str(child.name))
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
