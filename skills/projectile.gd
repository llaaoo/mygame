class_name Projectile
extends Area2D
## 投射物基类 — 所有飞行技能（火球、暗影弹、冰箭等）继承此类
## 子类覆写 _apply_visual() 设置外观，或覆写 @export 默认值

@export var speed: float = 300.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var collision_radius: float = 8.0

var direction: Vector2 = Vector2.DOWN
var caster: Node2D = null
var _has_hit: bool = false


func _ready() -> void:
	# 子类视觉定制（必须在形状创建之前，允许覆写 collision_radius）
	_apply_visual()

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
	queue_free()


## 子类覆写：设置 modulate / 粒子 / 缩放等视觉属性
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
	CombatExecutor.report_hit(caster, target, damage, global_position, skill, tags)
