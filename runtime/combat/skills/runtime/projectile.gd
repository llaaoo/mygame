class_name Projectile
extends Area2D
## 投射物基类 — SkillData 驱动的通用线性投射物
## 所有直线飞行技能（火球、暗影弹、冰箭等）共用此 Archetype
## 视觉由 SkillData.{texture, color, scale} 注入

@export var speed: float = 300.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var collision_radius: float = 8.0

var direction: Vector2 = Vector2.DOWN
var caster: Node2D = null
var _has_hit: bool = false
var _needs_setup: bool = true  ## setup() 调用前不进入 _ready 逻辑


## 核心入口：SkillData 注入所有参数（替代子类覆写）
func setup(skill: SkillData, caster_node: Node2D, dir: Vector2) -> void:
	caster = caster_node
	direction = dir.normalized()
	rotation = direction.angle()
	
	# SkillData 驱动数值
	speed = skill.projectile_speed
	damage = skill.projectile_speed  ## 会被 SkillExecutor 覆写为 resolve_damage()
	lifetime = 3.0
	
	# SkillData.visual 优先，fallback 到旧字段
	var spr = $Sprite2D
	if spr and skill:
		if skill.visual:
			if skill.visual.texture:
				spr.texture = skill.visual.texture
			spr.modulate = skill.visual.color
			spr.scale = Vector2(skill.visual.scale, skill.visual.scale)
		else:
			# @deprecated fallback
			if skill.projectile_texture:
				spr.texture = skill.projectile_texture
			spr.modulate = skill.projectile_color
			spr.scale = Vector2(skill.projectile_scale, skill.projectile_scale)
	
	_needs_setup = false


func _ready() -> void:
	if _needs_setup:
		_apply_visual()  ## @deprecated: 旧子类覆写路径，保留兼容
	
	# 确保碰撞形状
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = collision_radius
		shape_node.shape = circle

	# 连接信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	add_to_group("projectile")

	# 自动销毁
	await get_tree().create_timer(lifetime).timeout
	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			trace.record(
				CombatTraceEvent.Category.EVENT_EMIT,
				CombatPhase.Phase.POST,
				"MISS (timeout)", name, "",
				{"lifetime": lifetime},
				{}
			)
			CombatDebugger.store(trace)
	queue_free()


## @deprecated 子类覆写：设置 modulate / 粒子 / 缩放等视觉属性
func _apply_visual() -> void:
	pass


func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func set_caster(c: Node2D) -> void:
	caster = c


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	if body == caster:
		return
	# 同组免伤：敌人投射物不伤敌人，玩家投射物不伤玩家
	if caster and body.is_in_group("enemy") and caster.is_in_group("enemy"):
		return
	if caster and body.is_in_group("player") and caster.is_in_group("player"):
		return
	if not is_instance_valid(caster) or not is_instance_valid(body):
		return
	if body.has_method("take_damage"):
		_has_hit = true
		_emit_hit_event(body)
		body.take_damage(damage)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return
	if area.owner == caster:
		return
	if area.is_in_group("projectile"):
		return
	if not is_instance_valid(caster) or not is_instance_valid(area):
		return
	if area.has_method("take_damage"):
		_has_hit = true
		_emit_hit_event(area)
		area.take_damage(damage)
	queue_free()


## 发射 ON_HIT → CombatExecutor（唯一权威入口）
func _emit_hit_event(target: Node2D) -> void:
	var skill := get_meta("skill_data", null) as SkillData
	var tags: Array[String] = skill.tags if skill else []

	# 进入异步事件序列
	if CombatExecutor.instance:
		CombatExecutor.instance.begin_hit_sequence()

	CombatExecutor.report_hit(caster, target, damage, global_position, skill, tags)

	# 关闭技能 trace（ON_HIT 事件已由 _enforce_emit → _record_trace_event 记录）
	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			trace.final_damage = damage
			CombatDebugger.store(trace)
			remove_meta("_combat_trace")

	# 结束异步事件序列
	if CombatExecutor.instance:
		CombatExecutor.instance.end_hit_sequence()
