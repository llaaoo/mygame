class_name ConeCoverage
extends RefCounted
## One spatial predicate for actor contacts and ground cells.
static func contains(world: Node2D,origin: Vector2,direction: Vector2,point: Vector2,reach: float,angle: float,exclude: Array[RID]=[]) -> bool:
	var offset:=point-origin
	if offset.length()>reach or offset.length_squared()>.01 and direction.normalized().dot(offset.normalized())<cos(deg_to_rad(angle*.5)): return false
	var ray:=PhysicsRayQueryParameters2D.create(origin,point,1,exclude)
	return world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
static func apply(actor: Node2D,skill: SkillData,direction: Vector2,family: String,reach := 120.0,angle := 60.0,residual_seconds := 2.0) -> void:
	if not is_instance_valid(actor): return
	var origin:=actor.global_position
	var excluded: Array[RID]=[]
	if actor is CollisionObject2D: excluded.append(actor.get_rid())
	var circle:=CircleShape2D.new(); circle.radius=reach
	var query:=PhysicsShapeQueryParameters2D.new(); query.shape=circle; query.transform=Transform2D(0,origin); query.collision_mask=10; query.collide_with_areas=true; query.exclude=excluded
	var seen: Dictionary={}
	for hit in actor.get_world_2d().direct_space_state.intersect_shape(query,128):
		var target:=hit.collider as Node2D
		if target and not target.has_method("take_damage"): target=target.owner as Node2D
		if not target or target==actor or not target.has_method("take_damage") or seen.has(target.get_instance_id()): continue
		if not contains(actor,origin,direction,target.global_position,reach,angle,excluded): continue
		seen[target.get_instance_id()]=true
		CombatExecutor.report_hit(actor,target,skill.damage,target.global_position,skill,skill.tags,family)
	var surfaces:=SurfaceManager.instance
	if not surfaces: return
	var center:=SurfaceManager.cell_at(origin)
	for x in range(center.x-3,center.x+4):
		for y in range(center.y-3,center.y+4):
			var point:=Vector2(x,y)*64+Vector2(32,32)
			if contains(actor,origin,direction,point,reach,angle,excluded): surfaces.apply_area(point,0,skill.tags,skill.display_name,skill.creates_surface,residual_seconds,false,skill.surface_payload_tags)
