class_name IceExplosion
extends Area2D
## 冰爆 — 冰霜护盾破碎时释放的范围伤害
## 复用 FlameStorm 的命中逻辑 + 冰系视觉

@export var damage: int = 25
@export var lifetime: float = 0.5
@export var radius: float = 120.0

var caster: Node2D = null


func _ready() -> void:
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = radius
		shape_node.shape = circle

	var spr = $Sprite2D
	if spr:
		spr.modulate = Color(0.3, 0.6, 1.0, 0.5)
		spr.scale = Vector2(radius / 80.0, radius / 80.0)

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

	# 更新 trace 最终伤害（不关闭！超时处理器统一 store）
	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			trace.final_damage = maxi(trace.final_damage, damage)

	if CombatExecutor.instance:
		CombatExecutor.instance.end_hit_sequence()
