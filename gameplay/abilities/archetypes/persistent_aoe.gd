class_name PersistentAOE
extends Area2D
## 持久 AoE 基类 — SkillData 驱动的范围效果
## 所有 AoE 技能（火焰风暴、冰爆、毒云等）共用此 Archetype
## 视觉由 SkillData.{aoe_color, aoe_scale, aoe_lifetime} 注入

@export var damage: int = 30
@export var lifetime: float = 0.6

var caster: Node2D = null
var _needs_setup: bool = true
var _tick_interval: float = 0.0
var _tick_elapsed: float = 0.0
var _max_hits_per_target: int = 1
var _hit_counts: Dictionary = {}
var _hit_windows: Dictionary = {}
var _hit_window := 0
var _skill: SkillData
var _remaining_life := 0.0


## 核心入口：SkillData 注入所有参数
func setup(skill: SkillData, caster_node: Node2D) -> void:
	_skill = skill
	caster = caster_node
	damage = skill.damage  ## 会被 SkillExecutor 覆写为 resolve_damage()
	_tick_interval = skill.aoe_tick_interval
	_max_hits_per_target = skill.aoe_max_hits_per_target

	# skill.aoe_visual 优先，fallback 到旧字段
	if skill.aoe_visual:
		var vis := skill.aoe_visual
		lifetime = vis.lifetime
		var spr = $Sprite2D
		if spr:
			spr.modulate = vis.color
			spr.scale = Vector2(vis.scale, vis.scale)
		var shape_node = $CollisionShape2D
		if shape_node:
			var shape := shape_node.shape.duplicate() as CircleShape2D if shape_node.shape else null
			shape_node.shape = shape
			if not shape:
				shape = CircleShape2D.new()
				shape_node.shape = shape
			shape.radius = vis.radius
	else:
		# @deprecated fallback
		lifetime = skill.aoe_lifetime
		var spr = $Sprite2D
		if spr:
			spr.modulate = skill.aoe_color
			spr.scale = Vector2(skill.aoe_scale, skill.aoe_scale)
		var shape_node = $CollisionShape2D
		if shape_node:
			var shape := shape_node.shape.duplicate() as CircleShape2D if shape_node.shape else null
			shape_node.shape = shape
			if not shape:
				shape = CircleShape2D.new()
				shape_node.shape = shape
			shape.radius = skill.aoe_radius


	# 表面交互：AoE 生成 → 设置所在格表面状态
	# Surface reactions run in _ready at the final world position.

	var marker := get_node_or_null("Sprite2D") as Sprite2D
	if marker and marker.texture and "placeholders/" in marker.texture.resource_path:
		marker.hide()
		SpellVisual.attach(self, skill, "burst", skill.aoe_visual.radius if skill.aoe_visual else skill.aoe_radius, lifetime)
	_needs_setup = false


## 根据技能标签在 AoE 所在格设置表面状态
func _apply_surface(skill: SkillData) -> void:
	if not skill:
		return
	# 通过 GameRuntime → SimulationRuntime → SurfaceManager 访问（不再用全局单例）
	var gr := GameRuntime.instance
	if not gr:
		return
	var sim := gr.get_simulation_runtime()
	if not sim:
		return
	var sm := sim.get_surface_manager()
	if not sm:
		return
	var radius := skill.aoe_visual.radius if skill.aoe_visual else skill.aoe_radius
	sm.apply_area(global_position, radius, skill.tags, skill.display_name, skill.creates_surface, skill.surface_duration, skill.ignites_dry_surface, skill.surface_payload_tags)


func _ready() -> void:
	_apply_surface(_skill)
	# 碰撞层：AoE 是 HITBOX，检测 ACTOR + HURTBOX
	collision_layer = 4   # HITBOX
	collision_mask = 10   # ACTOR(2) | HURTBOX(8)

	# 确保碰撞形状
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 80.0
		shape_node.shape = circle

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_remaining_life = lifetime

func _expire() -> void:
	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			CombatDebugger.store(trace)
	queue_free()


func set_caster(c: Node2D) -> void:
	caster = c


func _physics_process(delta: float) -> void:
	var alive_time := minf(delta, maxf(0.0, _remaining_life))
	if _tick_interval > 0.0:
		_tick_elapsed += alive_time
		while _tick_elapsed + 0.000001 >= _tick_interval:
			_tick_elapsed = maxf(0, _tick_elapsed - _tick_interval)
			_hit_window += 1
			for body in get_overlapping_bodies():
				_try_hit(body, true)
			for area in get_overlapping_areas():
				var target := area if area.has_method("take_damage") else area.owner
				_try_hit(target, true)
	_remaining_life = maxf(0, _remaining_life - delta)
	if _remaining_life <= 0.000001:
		_expire()


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	# 检测 Area2D 子节点（如 MapObject 的 HitArea）
	var owner := area.owner
	_try_hit(area if area.has_method("take_damage") else owner)


func _try_hit(target: Node, from_tick: bool = false) -> void:
	if not target or target == caster or not target.has_method("take_damage") or CombatExecutor.same_combat_owner(caster,target as Node2D):
		return
	if _skill and "spray" in _skill.tags and is_instance_valid(caster):
		var origin: Vector2=get_meta("delivery_origin",caster.global_position)
		if target is Node2D:
			var ray:=PhysicsRayQueryParameters2D.create(origin,target.global_position,1,[caster.get_rid()] if caster is CollisionObject2D else [])
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return
	var target_id := target.get_instance_id()
	var hits := int(_hit_counts.get(target_id, 0))
	if hits >= _max_hits_per_target:
		return
	# Body and Hurtbox callbacks share one hit window; later hits come from ticks.
	if (hits > 0 and not from_tick) or int(_hit_windows.get(target_id, -1)) == _hit_window:
		return
	_hit_counts[target_id] = hits + 1
	_hit_windows[target_id] = _hit_window
	_emit_hit_event(target as Node2D)


func _emit_hit_event(target: Node2D) -> void:
	var skill := get_meta("skill_data", null) as SkillData
	var tags: Array[String] = skill.tags if skill else []

	if CombatExecutor.instance:
		CombatExecutor.instance.begin_hit_sequence()

	CombatExecutor.report_hit(caster, target, damage, global_position, skill, tags, str(get_meta("execution_family", "")))

	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			trace.final_damage = maxi(trace.final_damage, damage)

	if CombatExecutor.instance:
		CombatExecutor.instance.end_hit_sequence()
