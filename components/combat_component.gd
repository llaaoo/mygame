class_name CombatComponent
extends Node
## 近战战斗组件 — 攻击盒管理 + 命中检测
## 挂载到 Player 节点，通过 setup() 注入依赖

## 属性
@export var attack_damage: int = 10
@export var attack_range: float = 40.0

## 注入的依赖
var _entity: Player = null
var _attack_hitbox: Area2D = null
var _attack_hitbox_shape: CollisionShape2D = null
var _animation_player: AnimationPlayer = null


func setup(entity: Player, hitbox: Area2D, hitbox_shape: CollisionShape2D, anim: AnimationPlayer) -> void:
	_entity = entity
	_attack_hitbox = hitbox
	_attack_hitbox_shape = hitbox_shape
	_animation_player = anim

	# 配置攻击盒
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	_attack_hitbox_shape.shape = rect
	_attack_hitbox_shape.disabled = false
	_attack_hitbox.monitoring = false

	# 连接攻击命中信号
	if not _attack_hitbox.body_entered.is_connected(_on_attack_hit):
		_attack_hitbox.body_entered.connect(_on_attack_hit)
	if not _attack_hitbox.area_entered.is_connected(_on_attack_hit_area):
		_attack_hitbox.area_entered.connect(_on_attack_hit_area)


func perform_melee_attack() -> void:
	var attack_dir := _entity.get_mouse_direction()
	_entity.facing_direction = attack_dir
	_attack_hitbox.position = attack_dir * attack_range
	_attack_hitbox.rotation = attack_dir.angle()
	_attack_hitbox.monitoring = true

	if _animation_player.has_animation("attack"):
		_animation_player.play("attack")

	await _entity.get_tree().create_timer(0.15).timeout
	_attack_hitbox.monitoring = false
	_attack_hitbox.position = Vector2.ZERO


func _on_attack_hit(body: Node2D) -> void:
	if body == _entity:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)


func _on_attack_hit_area(area: Area2D) -> void:
	if area.owner == _entity:
		return
	if area.has_method("take_damage"):
		area.take_damage(attack_damage)
