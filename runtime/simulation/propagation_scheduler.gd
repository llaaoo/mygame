class_name PropagationScheduler
extends Node
## PropagationScheduler — BFS 传播队列处理（每帧 N 个 job）
##
## 防火墙 (CONTRACT 9):
##   MAX_PROPAGATION_DEPTH = 4
##   MAX_JOBS_PER_TICK = 8
##   MAX_QUEUE_SIZE = 64
##   PROPAGATION_DECAY = 0.5

const MAX_PROPAGATION_DEPTH := 4
const MAX_JOBS_PER_TICK := 8
const MAX_QUEUE_SIZE := 64
const PROPAGATION_DECAY := 0.5


class PropagationJob:
	var source_cell: Vector2i
	var target_cell: Vector2i
	var damage: float
	var depth: int
	var tags: Array[String]
	
	func _init(src: Vector2i, tgt: Vector2i, dmg: float, dep: int, t: Array[String]) -> void:
		source_cell = src
		target_cell = tgt
		damage = dmg
		depth = dep
		tags = t


var _jobs: Array[PropagationJob] = []
var _surface_scheduler: SurfaceScheduler = null
var _surface_manager: SurfaceManager = null
var _spatial_index: WorldSpatialIndex = null


func setup(surface_sched: SurfaceScheduler, spatial: WorldSpatialIndex, surf_mgr: SurfaceManager = null) -> void:
	_surface_scheduler = surface_sched
	_spatial_index = spatial
	_surface_manager = surf_mgr


func enqueue(source: Vector2i, target: Vector2i, damage: float, depth: int, tags: Array[String]) -> void:
	if depth > MAX_PROPAGATION_DEPTH:
		return
	if _jobs.size() >= MAX_QUEUE_SIZE:
		return
	
	_jobs.append(PropagationJob.new(source, target, damage, depth, tags))


func tick(delta: float) -> void:
	var processed := 0
	
	while _jobs.size() > 0 and processed < MAX_JOBS_PER_TICK:
		var job: PropagationJob = _jobs.pop_front()
		_execute_job(job)
		processed += 1


func _execute_job(job: PropagationJob) -> void:
	if not _surface_scheduler:
		return
	
	# 优先用 SurfaceManager 的 ReactionRule 表
	if _surface_manager:
		var changed := _surface_manager.apply_tags(job.target_cell, job.tags, "propagation_from_%s" % job.source_cell)
		
		# 标记为 spread_to_neighbors 的反应继续传播
		if changed and job.depth < MAX_PROPAGATION_DEPTH:
			var surf := _surface_scheduler.get_surface(job.target_cell)
			var rules: Array = _surface_manager._reactions.get(surf.get("state", "dry"), [])
			for rule in rules:
				if rule is SurfaceReaction and rule.spread_to_neighbors:
					_spread_neighbors(job, rule)
		return
	
	# fallback: 硬编码规则（无 SurfaceManager 时）
	var surf: Dictionary = _surface_scheduler.get_surface(job.target_cell)
	var current_state: String = surf.get("state", "dry")
	
	if current_state == "oiled" and "fire" in job.tags:
		_surface_scheduler.set_surface(job.target_cell, "burning", 8.0, "propagation_from_%s" % job.source_cell)
		_spread_neighbors(job, null)


func _spread_neighbors(job: PropagationJob, rule: SurfaceReaction = null) -> void:
	var neighbors := _get_neighbors(job.target_cell)
	var tags: Array[String] = rule.spread_tags if rule and not rule.spread_tags.is_empty() else job.tags
	var dmg: float = rule.spread_damage if rule and rule.spread_damage > 0 else job.damage
	
	for neighbor: Vector2i in neighbors:
		var neighbor_surf: Dictionary = _surface_scheduler.get_surface(neighbor)
		if neighbor_surf.get("state", "dry") == "dry":
			continue
		enqueue(job.target_cell, neighbor, dmg * PROPAGATION_DECAY, job.depth + 1, tags)


func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT,
		cell + Vector2i.UP,
		cell + Vector2i.DOWN
	]


func _to_string() -> String:
	return "PropagationScheduler(jobs=%d)" % _jobs.size()
