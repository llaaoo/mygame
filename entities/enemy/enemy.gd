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

## 敌人类型预设（0=哨兵, 1=士兵, 2=坦克）
@export var enemy_type: int = 1:
	set(v):
		enemy_type = v
		_apply_preset(v)

var hp: int = 30
var player: Player = null
var attack_ready: bool = true

## 预设数据表：{name, color, scale}
const PRESETS: Array[Dictionary] = [
	{"name": "哨兵", "color": Color(0.3, 0.9, 0.3, 1), "scale": Vector2(0.25, 0.25)},   # 0
	{"name": "士兵", "color": Color(0.8, 0.25, 0.25, 1), "scale": Vector2(0.4, 0.4)},    # 1
	{"name": "坦克", "color": Color(0.6, 0.2, 0.7, 1), "scale": Vector2(0.55, 0.55)},    # 2
]

## 运行时使用的视觉属性
var enemy_color: Color = Color.RED
var enemy_scale: Vector2 = Vector2(0.4, 0.4)
var enemy_name: String = "敌人"

signal died

func _ready() -> void:
	hp = max_hp
	# 从 .tres 资源加载形状
	$CollisionShape2D.shape = load("res://entities/enemy/enemy_body_shape.tres")
	# 应用预设（enemy_type setter 可能在 _ready 前已执行，这里确保生效）
	_apply_preset(enemy_type)
	_apply_visuals()
	_setup_state_machine()
	call_deferred("_find_player")

## 根据 enemy_type 应用完整预设
func _apply_preset(type_idx: int) -> void:
	if type_idx < 0 or type_idx >= PRESETS.size():
		return
	var p = PRESETS[type_idx]
	enemy_name = p["name"]
	enemy_color = p["color"]
	enemy_scale = p["scale"]

## 确保状态机的 entity 指向自己（运行时 owner 可能为 null）
func _setup_state_machine() -> void:
	var sm = $StateMachine
	if not sm.get_script():
		return
	for child in sm.get_children():
		if child.has_method("enter") and child.get("entity") != self:
			child.set("entity", self)

## 应用视觉属性到 Sprite2D
func _apply_visuals() -> void:
	var spr = $Sprite2D
	spr.modulate = enemy_color
	spr.scale = enemy_scale

## 受伤闪烁效果
func _flash_damage() -> void:
	var spr = $Sprite2D
	spr.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	spr.modulate = enemy_color

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		await get_tree().create_timer(0.5).timeout
		_find_player()

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
	_flash_damage()
	print("👹 %s 受到伤害: %d  剩余HP: %d" % [enemy_name, amount, hp])
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
