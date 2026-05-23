class_name FlameStorm
extends Area2D
## 烈焰风暴 — AoE 范围伤害，生成后立即伤害范围内所有敌人，短暂延迟后自毁

@export var damage: int = 30
@export var lifetime: float = 0.6

var caster: Node2D = null


func _ready() -> void:
	# 确保碰撞形状
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 80.0
		shape_node.shape = circle

	# 视觉
	var spr = $Sprite2D
	if spr:
		spr.modulate = Color(1.0, 0.3, 0.1, 0.6)
		spr.scale = Vector2(0.8, 0.8)

	body_entered.connect(_on_body_entered)

	# 短暂延迟后自毁
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

	# 进入异步事件序列
	if CombatExecutor.instance:
		CombatExecutor.instance.begin_hit_sequence()

	CombatExecutor.report_hit(caster, target, damage, global_position, skill, tags)

	# 更新 trace 最终伤害（不关闭！超时处理器统一 store，确保多命中全记录）
	if has_meta("_combat_trace"):
		var trace := get_meta("_combat_trace") as CombatTrace
		if trace:
			trace.final_damage = maxi(trace.final_damage, damage)

	# 结束异步事件序列
	if CombatExecutor.instance:
		CombatExecutor.instance.end_hit_sequence()
