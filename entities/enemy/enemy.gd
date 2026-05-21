extends CharacterBody2D
class_name Enemy

## 属性
@export var max_hp: int = 30
@export var move_speed: float = 120.0
@export var detect_range: float = 200.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.0

## 掉落物（死亡时生成，可扩展为 loot table）
@export var drop_scene: PackedScene

var hp: int = 30
var player: Player = null
var attack_ready: bool = true

signal died

func _ready() -> void:
	hp = max_hp
	_setup_collision()
	_setup_state_machine()
	call_deferred("_find_player")

## 确保状态机的 entity 指向自己（运行时 owner 可能为 null）
func _setup_state_machine() -> void:
	var sm = $StateMachine
	if not sm.get_script():
		return
	for child in sm.get_children():
		if child.has_method("enter") and child.get("entity") != self:
			child.set("entity", self)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		await get_tree().create_timer(0.5).timeout
		_find_player()

func _setup_collision() -> void:
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = 14.0
		shape_node.shape = circle

## 获取到玩家的方向
func get_player_direction() -> Vector2:
	if not player:
		return Vector2.ZERO
	return (player.global_position - global_position).normalized()

## 到玩家的距离
func distance_to_player() -> float:
	if not player:
		return INF
	return global_position.distance_to(player.global_position)

## 被攻击
func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	print("👹 敌人受到伤害: ", amount, " 剩余HP: ", hp)
	if hp <= 0:
		_spawn_drop()
		died.emit()
		queue_free()

## 生成掉落物（可扩展：未来可用 drop_table 替代单一 drop_scene）
func _spawn_drop() -> void:
	if not drop_scene:
		drop_scene = load("res://pickups/health_pickup.tscn")
	if not drop_scene:
		return
	var drop = drop_scene.instantiate()
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position

## 执行攻击
func perform_attack() -> void:
	if not attack_ready or not player:
		return
	attack_ready = false
	player.take_damage(attack_damage)
	print("👹 敌人攻击玩家，伤害: ", attack_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	attack_ready = true
