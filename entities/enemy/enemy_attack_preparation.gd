class_name EnemyAttackPreparation
extends Node2D
## One live, region-owned warning. Never tracks facing after preparation starts.
var actor: Enemy
var target: Node2D
var world: Node
var direction := Vector2.RIGHT
var point := Vector2.ZERO
var radius := 0.0
var kind := ""
var remaining := 0.0
var duration := 0.0
var recovery := 0.0
var _impact: Callable
var _starting_health := 0

func is_preparing() -> bool: return remaining>0

func busy() -> bool: return remaining > 0 or recovery > 0

func begin(victim: Node2D, facing: Vector2, seconds: float, after: float, callback: Callable, style: String, center := Vector2.ZERO, size := 0.0) -> bool:
	if busy() or not actor._is_valid_target(victim): return false
	_starting_health=actor.health_component.hp
	target = victim
	world = CastContext.default_world(actor)
	direction = facing.normalized()
	point = center
	radius = size
	duration = seconds
	remaining = seconds
	recovery = after
	_impact = callback
	kind = style
	actor.velocity = Vector2.ZERO
	queue_redraw()
	return true

func cancel() -> void:
	remaining = 0
	recovery = 0
	_impact = Callable()
	kind = ""
	queue_redraw()

func _physics_process(delta: float) -> void: tick(delta)

func tick(delta: float) -> void:
	if not busy(): return
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.health_component.is_dead or not actor._is_valid_target(target) or not is_instance_valid(world) or CastContext.default_world(actor) != world:
		cancel()
		return
	if actor.character_definition and actor.health_component.hp<_starting_health:
		cancel()
		return
	if remaining > 0:
		remaining = maxf(0, remaining - delta)
		if remaining == 0:
			var impact := _impact
			_impact = Callable()
			kind = ""
			if impact.is_valid(): impact.call()
	else:
		recovery = maxf(0, recovery - delta)
	queue_redraw()

func melee_connects() -> bool:
	if not actor._is_valid_target(target): return false
	var offset := target.global_position - actor.global_position
	return offset.length() <= actor.attack_range and (offset.is_zero_approx() or direction.dot(offset.normalized()) >= cos(deg_to_rad(50)))

func _draw() -> void:
	if remaining <= 0: return
	var color := Color(1, .48, .22, .4 + .5 * (1 - remaining / duration))
	if kind == "melee":
		var angle := direction.angle()
		draw_arc(Vector2.ZERO, actor.attack_range, angle - deg_to_rad(50), angle + deg_to_rad(50), 20, color, 3)
		draw_line(Vector2.ZERO, direction.rotated(deg_to_rad(-50)) * actor.attack_range, color, 1)
		draw_line(Vector2.ZERO, direction.rotated(deg_to_rad(50)) * actor.attack_range, color, 1)
	elif kind == "ranged":
		draw_line(Vector2.ZERO, direction * 100, color, 3)
		draw_circle(direction * 100, 5, color, false, 2)
	else:
		draw_circle(to_local(point), radius, Color(color, .12))
		draw_arc(to_local(point), radius, 0, TAU, 48, color, 3)
