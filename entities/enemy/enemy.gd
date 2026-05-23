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
	{"strength": 5,  "intelligence": 5,  "agility": 15, "endurance": 5},   # 哨兵：高敏捷
	{"strength": 10, "intelligence": 8,  "agility": 10, "endurance": 10},  # 士兵：均衡
	{"strength": 15, "intelligence": 5,  "agility": 5,  "endurance": 15},  # 坦克：高力耐
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
@onready var stats_component: StatsComponent = $StatsComponent


func _ready() -> void:
	add_to_group("enemy")
	# 碰撞形状
	$CollisionShape2D.shape = load("res://entities/enemy/enemy_body_shape.tres")

	# BuffManager（状态/减益接收）
	_create_buff_manager()

	# 应用预设属性
	_apply_preset_stats(enemy_type)

	# 生命值组件
	health_component.setup($CollisionShape2D)
	health_component.regen_rate = 0.0
	health_component.died.connect(_on_died)
	_apply_stats_to_health()

	# 技能（archetype 驱动场景，SkillData 纯配置）
	var bolt_data := load("res://runtime/combat/skills/data/shadow_bolt_data.tres") as SkillData
	if bolt_data:
		bolt_data.skill_type = SkillData.SkillType.PROJECTILE
		bolt_data.archetype = "linear_projectile"
		bolt_data.visual = load("res://skills/visuals/shadow_visual.tres")
		bolt_data.projectile_speed = 250.0
		bolt_data.damage = 10
		bolt_data.damage_scaling = 0.6
		skill_manager.pool = SkillPool.new()
		skill_manager.pool.add_skill(bolt_data)
		skill_manager.pool.build()
		skill_manager.equip_hand("right", bolt_data)

	# 视觉
	_apply_preset(enemy_type)
	_apply_visuals()

	# 状态机
	_setup_state_machine()

	call_deferred("_find_player")


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
	# HP 直接使用 @export max_hp，不叠加耐力加成（耐力加成仅对 Player 生效）
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
	# 击杀奖励经验（副作用收敛到 CombatExecutor）
	if player:
		CombatExecutor.report_exp_bonus(player, 30 + stats_component.level * 10)
	_spawn_drop()
	died.emit()
	queue_free()


func _spawn_drop() -> void:
	if not drop_scene:
		if randf() < 0.5:
			drop_scene = load("res://pickups/health_pickup.tscn")
		else:
			drop_scene = load("res://pickups/mana_pickup.tscn")

	if not drop_scene:
		return
	var drop = drop_scene.instantiate()
	get_tree().current_scene.add_child.call_deferred(drop)
	drop.global_position = global_position


## ── 攻击 ──

func perform_attack() -> void:
	if not attack_ready or not player:
		return
	attack_ready = false

	# 敌人近战 trace
	var trace := CombatDebugger.begin("melee_enemy", "敌人近战")

	# 近战命中走 CombatExecutor 事件序列
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_hit_sequence()

	CombatExecutor.report_hit(self, player, attack_damage, player.global_position, null, ["melee", "enemy"])
	player.take_damage(attack_damage)

	# 写入 trace 最终伤害
	if trace:
		trace.final_damage = attack_damage

	if exec_inst:
		exec_inst.end_hit_sequence()

	# 关闭敌人近战 trace
	if trace:
		CombatDebugger.store(trace)

	await get_tree().create_timer(attack_cooldown).timeout
	attack_ready = true
