extends Area2D
class_name Fireball

@export var speed: float = 500.0
@export var damage: int = 25
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.DOWN
var caster: Node2D = null

func _ready() -> void:
	# 确保碰撞形状有效
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 8.0
		shape_node.shape = circle
	
	# 连接信号 - 碰撞到物体时
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	add_to_group("projectile")
	
	# 自动销毁
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func set_caster(c: Node2D) -> void:
	caster = c

func _on_body_entered(body: Node2D) -> void:
	if body == caster:
		return  # 不打施法者
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.owner == caster:
		return
	if area.is_in_group("projectile"):
		return  # 投射物之间不碰撞
	if area.has_method("take_damage"):
		area.take_damage(damage)
	queue_free()
