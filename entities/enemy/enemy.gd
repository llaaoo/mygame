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

## ── 预设属性表（哨兵/士兵/坦克） ──
const PRESET_STATS: Array[Dictionary] = [
	{"strength": 5,  "intelligence": 5,  "agility": 15, "endurance": 5},
	{"strength": 10, "intelligence": 8,  "agility": 10, "endurance": 10},
	{"strength": 15, "intelligence": 5,  "agility": 5,  "endurance": 15},
]

var enemy_color: Color = Color.RED
var enemy_scale: Vector2 = Vector2(0.4, 0.4)
var enemy_name: String = "敌人"

## ── 运行时 ──
var player: Player = null
var attack_ready: bool = true
var _attack_timer: float = 0.0

signal died

@onready var health_component: HealthComponent = $HealthComponent
@onready var skill_manager: SkillManager = $SkillManager
@onready var stats_component: StatsComponent = $StatsComponent
@onready var state_chart: StateChart = $StateChart


func _ready() -> void:
	add_to_group("enemy")
	$CollisionShape2D.shape = load("res://entities/enemy/enemy_body_shape.tres")
	_create_buff_manager()
	_apply_preset_stats(enemy_type)
	health_component.setup($CollisionShape2D)
	health_component.regen_rate = 0.0
	health_component.died.connect(_on_died)
	_apply_stats_to_health()

	# 技能
	var bolt_data := load("res://gameplay/abilities/data/shadow_bolt_data.tres") as SkillData
	if bolt_data:
		bolt_data.skill_type = SkillData.SkillType.PROJECTILE
		bolt_data.archetype = "linear_projectile"
		bolt_data.visual = load("res://content/visuals/shadow_visual.tres")
		bolt_data.projectile_speed = 250.0
		bolt_data.damage = 10
		bolt_data.damage_scaling = 0.6
		skill_manager.pool = SkillPool.new()
		skill_manager.pool.add_skill(bolt_data)
		skill_manager.pool.build()
		skill_manager.equip_hand("right", bolt_data)

	_apply_preset(enemy_type)
	_apply_visuals()

	# StateChart 在 _ready 中已由场景实例化，这里连接状态逻辑
	_setup_state_chart()

	call_deferred("_find_player")


func _setup_state_chart() -> void:
	var brain := state_chart.get_node("Brain") as CompoundState
	if not brain:
		return

	var idle := brain.get_node("Idle") as AtomicState
	var chase := brain.get_node("Chase") as AtomicState
	var attack := brain.get_node("Attack") as AtomicState

	# Idle 状态
	idle.state_physics_processing.connect(_on_idle_physics)

	# Chase 状态
	chase.state_physics_processing.connect(_on_chase_physics)

	# Attack 状态
	attack.state_entered.connect(_on_attack_enter)
	attack.state_physics_processing.connect(_on_attack_physics)


func _on_idle_physics(_delta: float) -> void:
	if not player or player.health_component.is_dead:
		return
	if distance_to_player() <= detect_range:
		state_chart.send_event("player_detected")


func _on_chase_physics(_delta: float) -> void:
	if not player or player.health_component.is_dead:
		state_chart.send_event("player_lost")
		return

	var dist := distance_to_player()

	if dist <= attack_range:
		state_chart.send_event("player_in_range")
		return

	if dist > detect_range * 1.5:
		state_chart.send_event("player_lost")
		return

	if skill_manager and skill_manager.can_use("right"):
		var dir := get_player_direction()
		skill_manager.use_hand("right", self, dir)

	var dir := get_player_direction()
	velocity = dir * move_speed
	move_and_slide()


func _on_attack_enter() -> void:
	_attack_timer = 0.0
	velocity = Vector2.ZERO
	_do_melee_attack()


func _on_attack_physics(delta: float) -> void:
	if not player or player.health_component.is_dead:
		state_chart.send_event("player_lost")
		return

	_attack_timer += delta
	var dist := distance_to_player()

	if dist > attack_range * 1.5:
		state_chart.send_event("player_out_of_range")
		return

	if _attack_timer >= attack_cooldown:
		_attack_timer = 0.0
		_do_melee_attack()


func _do_melee_attack() -> void:
	if not attack_ready or not player:
		return
	attack_ready = false

	var trace := CombatDebugger.begin("melee_enemy", "敌人近战")
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_hit_sequence()

	CombatExecutor.report_hit(self, player, attack_damage, player.global_position, null, ["melee", "enemy"])
	player.take_damage(attack_damage)

	if trace:
		trace.final_damage = attack_damage
	if exec_inst:
		exec_inst.end_hit_sequence()
	if trace:
		CombatDebugger.store(trace)

	await get_tree().create_timer(attack_cooldown).timeout
	attack_ready = true


func _create_buff_manager() -> void:
	if has_node("BuffManager"):
		return
	var bm := BuffManager.new()
	bm.name = "BuffManager"
	add_child(bm)


## ── 属性 ──

func _apply_preset_stats(type_idx: int) -> void:
	if type_idx < 0 or type_idx >= PRESET_STATS.size():
		return
	var s = PRESET_STATS[type_idx]
	stats_component.strength = s["strength"]
	stats_component.intelligence = s["intelligence"]
	stats_component.agility = s["agility"]
	stats_component.endurance = s["endurance"]
	stats_component._recalculate_all()


func _apply_stats_to_health() -> void:
	health_component.max_hp = max_hp
	health_component.hp = health_component.max_hp
	move_speed = move_speed + stats_component.move_speed_bonus
	attack_damage = attack_damage + stats_component.physical_damage


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
	if player:
		CombatExecutor.report_exp_bonus(player, 30 + stats_component.level * 10)
	_spawn_drop()
	died.emit()
	queue_free()


func _spawn_drop() -> void:
	if not drop_scene:
		if randf() < 0.5:
			drop_scene = load("res://entities/pickups/health_pickup.tscn")
		else:
			drop_scene = load("res://entities/pickups/mana_pickup.tscn")

	if not drop_scene:
		return
	var drop = drop_scene.instantiate()
	get_tree().current_scene.add_child.call_deferred(drop)
	drop.global_position = global_position
