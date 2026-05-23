class_name PersistentAOE
extends Area2D
## 持久 AoE 基类 — SkillData 驱动的范围效果
## 所有 AoE 技能（火焰风暴、冰爆、毒云等）共用此 Archetype
## 视觉由 SkillData.{aoe_color, aoe_scale, aoe_lifetime} 注入

@export var damage: int = 30
@export var lifetime: float = 0.6

var caster: Node2D = null
var _needs_setup: bool = true


## 核心入口：SkillData 注入所有参数
func setup(skill: SkillData, caster_node: Node2D) -> void:
	caster = caster_node
	damage = skill.damage  ## 会被 SkillExecutor 覆写为 resolve_damage()
	
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
			var shape = shape_node.shape
			if shape and shape is CircleShape2D:
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
			var shape = shape_node.shape
			if shape and shape is CircleShape2D:
				shape.radius = skill.aoe_radius
	
	_needs_setup = false


func _ready() -> void:
	# 确保碰撞形状
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 80.0
		shape_node.shape = circle

	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(lifetime).timeout
	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			CombatDebugger.store(trace)
	queue_free()


func set_caster(c: Node2D) -> void:
	caster = c


func _on_body_entered(body: Node2D) -> void:
	if body == caster:
		return
	if body.has_method("take_damage"):
		_emit_hit_event(body)
		body.take_damage(damage)


func _emit_hit_event(target: Node2D) -> void:
	var skill := get_meta("skill_data", null) as SkillData
	var tags: Array[String] = skill.tags if skill else []

	if CombatExecutor.instance:
		CombatExecutor.instance.begin_hit_sequence()

	CombatExecutor.report_hit(caster, target, damage, global_position, skill, tags)

	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			trace.final_damage = maxi(trace.final_damage, damage)

	if CombatExecutor.instance:
		CombatExecutor.instance.end_hit_sequence()
