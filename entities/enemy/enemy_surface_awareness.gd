class_name EnemySurfaceAwareness
extends Node
## Bounded local steering. The existing action resolver still owns movement.
const INTERVAL := 0.25
const ANGLES := [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2, 3 * PI / 4, -3 * PI / 4, PI]
var actor: CharacterBody2D
var cautious := false
var direction := Vector2.ZERO
var should_evade := false
var last_candidate_queries := 0
var evaluations := 0
var _remaining := 0.0
var _desired := Vector2.ZERO
var _evaluated := false

func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)

func steer(desired: Vector2) -> Vector2:
	_desired = desired.normalized()
	return direction if _evaluated else _desired

func tick(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0 or not is_instance_valid(actor) or not can_process(): return
	if not PhysicsServer2D.body_get_space(actor.get_rid()).is_valid(): return
	_remaining = INTERVAL
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_dead: return
	var runtime := GameRuntime.instance
	var surfaces := runtime.get_simulation_runtime().get_surface_manager() if runtime else null
	if not surfaces: return
	var preferred := _desired
	if preferred.is_zero_approx() and actor.has_method("get_target_direction"):
		preferred = actor.get_target_direction()
	if preferred.is_zero_approx(): preferred = Vector2.RIGHT
	var current := surfaces.danger_at(actor.global_position, actor)
	should_evade = current >= 0.6
	var best := INF
	direction = Vector2.ZERO
	last_candidate_queries = 0
	for angle in ANGLES:
		var candidate := preferred.rotated(angle)
		if actor.test_move(actor.global_transform, candidate * 64): continue
		last_candidate_queries += 1
		var danger := surfaces.danger_at(actor.global_position + candidate * 64, actor)
		var score := danger * (6.0 if cautious else 2.5) + (1.0 - candidate.dot(preferred))
		if score < best:
			best = score
			direction = candidate
	_evaluated = true
	evaluations += 1
