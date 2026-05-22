extends CharacterBody2D
class_name Enemy

## ── 属性 ──
@export var max_hp: int = 30
@export var move_speed: float = 120.0
@export var detect_range: float = 200.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.0

## ── 掉落 ──
@export var drop_scene: PackedScene

## ── 视觉预设 (0=哨兵🟢, 1=士兵🔴, 2=坦克🟣) ──
@export var enemy_type: int = 1:
	set(v):
		enemy_type = v
		_apply_preset(v)

const PRESETS: Array[Dictionary] = [
	{"name": "哨兵", "color": Color(0.3, 0.9, 0.3, 1), "scale": Vector2(0.25, 0.25)},
	{"name": "士兵", "color": Color(0.8, 0.25, 0.25, 1), "scale": Vector2(0.4, 0.4)},
	{"name": "坦克", "color": Color(0.6, 0.2, 0.7, 1), "scale": Vector2(0.55, 0.55)},
]

var enemy_color: Color = Color.RED
var enemy_scale: Vector2 = Vector2(0.4, 0.4)
var enemy_name: String = "敌人"

## ── 运行时 ──
var player: Player = null
var attack_ready: bool = true

signal died

@onready var health_component: HealthComponent = $HealthComponent
@onready var skill_manager: SkillManager = $SkillManager


func _ready() -> void:
	# 碰撞形状
	$CollisionShape2D.shape = load("res://entities/enemy/enemy_body_shape.tres")

	# 生命值组件
	health_component.setup($CollisionShape2D)
	health_component.max_hp = max_hp
	health_component.hp = max_hp
	health_component.regen_rate = 0.0  # 敌人不自回
	health_component.died.connect(_on_died)

	# 技能
	var bolt_data := load("res://skills/shadow_bolt_data.tres") as SkillData
	if bolt_data:
		bolt_data.scene = load("res://skills/fireball.tscn")
		bolt_data.projectile_speed = 250.0  # 敌人投射物更慢
		skill_manager.skills = [bolt_data]
		skill_manager._ready()

	# 视觉
	_apply_preset(enemy_type)
	_apply_visuals()

	# 状态机
	_setup_state_machine()

	call_deferred("_find_player")


## ── 视觉 ──

func _apply_preset(type_idx: int) -> void:
	if type_idx < 0 or type_idx >= PRESETS.size():
		return
	var p = PRESETS[type_idx]
	enemy_name = p["name"]
	enemy_color = p["color"]
	enemy_scale = p["scale"]


func _apply_visuals() -> void:
	var spr = $Sprite2D
	spr.modulate = enemy_color
	spr.scale = enemy_scale


func _flash_damage() -> void:
	var spr = $Sprite2D
	spr.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	spr.modulate = enemy_color


## ── 状态机 ──

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


## ── AI 辅助 ──

func get_player_direction() -> Vector2:
	if not player:
		return Vector2.ZERO
	return (player.global_position - global_position).normalized()


func distance_to_player() -> float:
	if not player:
		return INF
	return global_position.distance_to(player.global_position)


## ── 受伤/死亡 ──

func take_damage(amount: int) -> void:
	_flash_damage()
	health_component.take_damage(amount)


func _on_died() -> void:
	_spawn_drop()
	died.emit()
	queue_free()


func _spawn_drop() -> void:
	if not drop_scene:
		drop_scene = load("res://pickups/health_pickup.tscn")
	if not drop_scene:
		return
	var drop = drop_scene.instantiate()
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position


## ── 攻击 ──

func perform_attack() -> void:
	if not attack_ready or not player:
		return
	attack_ready = false
	player.take_damage(attack_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	attack_ready = true
