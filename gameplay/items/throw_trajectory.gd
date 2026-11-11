class_name ThrowTrajectory
extends RefCounted
## A throw's preview and physical carrier share obstruction layers and impact offset.
## Preview reflects the current scene; actors may move before the bottle arrives.
const COLLISION_MASK := 11
const IMPACT_OFFSET := 2.0

static func first_hit(world: World2D, from: Vector2, to: Vector2, exclude: Array[RID]) -> Dictionary:
	var ray:=PhysicsRayQueryParameters2D.create(from,to,COLLISION_MASK,exclude)
	ray.collide_with_areas=true
	return world.direct_space_state.intersect_ray(ray)

static func impact_point(hit: Dictionary, direction: Vector2) -> Vector2:
	return Vector2(hit.position)-direction*IMPACT_OFFSET
