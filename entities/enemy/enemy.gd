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
var _revenge_target: Node2D = null       ## 复仇目标（谁打了我 → 我打谁）
var _leash_distance: float = 500.0       ## 脱战距离

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

	# 订阅伤害事件（复仇机制）
	call_deferred("_subscribe_revenge_events")

	call_deferred("_find_player")


## ── 复仇机制：监听 CombatEventBus ON_HIT / ON_KILL ──

func _subscribe_revenge_events() -> void:
	var bus := CombatEventBus.instance
	if not bus:
		await get_tree().process_frame
		_subscribe_revenge_events()
		return
	bus.subscribe(CombatEvent.Type.ON_HIT, _on_got_hit)
	bus.subscribe(CombatEvent.Type.ON_KILL, _on_target_killed)


## 我被谁打了 → 设为复仇目标
func _on_got_hit(ev: CombatEvent) -> void:
	if ev.target != self:
		return
	if ev.source == self or not is_instance_valid(ev.source):
		return
	if ev.source is Player:
		return
	if not _is_valid_revenge_source(ev):
		return
	_revenge_target = ev.source


func _is_valid_revenge_source(ev: CombatEvent) -> bool:
	var tags: Array = ev.data.get("tags", [])
	if tags.has("trap") or tags.has("environment"):
		return false
	var source := ev.source
	if not source or not is_instance_valid(source):
		return false
	return source.is_in_group("enemy") or source.is_in_group("summon")


## 复仇目标死了 → 清空
func _on_target_killed(ev: CombatEvent) -> void:
	if ev.target == _revenge_target:
		_revenge_target = null


## 获取当前优先级最高的目标：复仇目标 > 玩家
func _get_current_target() -> Node2D:
	if _is_valid_target(_revenge_target):
		return _revenge_target
	if player and not player.health_component.is_dead:
		return player
	return null


## 目标是否有效（非空、有效实例、未死、在脱战距离内）
func _is_valid_target(target: Node2D) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target.has_method("is_dead") and target.is_dead():
		return false
	if target.get("health_component") and target.health_component.is_dead:
		return false
	if global_position.distance_to(target.global_position) > _leash_distance:
		return false
	return true


## 获取当前目标方向
func get_target_direction() -> Vector2:
	var target := _get_current_target()
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()


## 到当前目标的距离
func distance_to_target() -> float:
	var target := _get_current_target()
	if not target:
		return INF
	return global_position.distance_to(target.global_position)


func _setup_state_chart() -> void:
	var brain := state_chart.get_node("Brain") as CompoundState
	if not brain:
		return

	var idle := brain.get_node("Idle") as AtomicState
	var chase := brain.get_node("Chase") as AtomicState
	var attack := brain.get_node("Attack") as AtomicState

	idle.state_physics_processing.connect(_on_idle_physics)
	chase.state_physics_processing.connect(_on_chase_physics)
	attack.state_entered.connect(_on_attack_enter)
	attack.state_physics_processing.connect(_on_attack_physics)


## ── Action Layer ── Enemy 通过通用 Action 表达意图，与 Player/NPC 同构 ──

## 产生当前上下文下的 Action 列表
func poll_actions() -> Array[Action]:
	var actions: Array[Action] = []

	var target := _get_current_target()
	if not target:
		return actions

	match _current_state_name():
		"Chase":
			# 向目标移动
			actions.append(Action.move(get_target_direction(), self))
			# 远程施法（冷却允许时）
			if skill_manager and skill_manager.can_use("right"):
				actions.append(Action.cast("right", get_target_direction(), self))
		"Attack":
			# 近战攻击（冷却允许时）
			if attack_ready and _attack_timer >= attack_cooldown:
				actions.append(Action.melee(self))

	return actions


## 通用 Action 路由（与 Player.resolve_action 同构）
## 执行前统一通过 ActionResolver 验证
func resolve_action(action: Action) -> void:
	# 统一验证（cooldown / mp / alive）
	if not ActionResolver.validate(self, action):
		return

	match action.action_type:
		Action.ActionType.MOVE:
			velocity = action.direction * move_speed
			move_and_slide()

		Action.ActionType.CAST:
			skill_manager.use_hand(action.skill_source, self, action.direction)

		Action.ActionType.MELEE:
			_do_melee_attack()


func _current_state_name() -> String:
	var brain := state_chart.get_node("Brain") as CompoundState
	if not brain:
		return ""
	for child in brain.get_children():
		if child is AtomicState and child.active:
			return child.name
	return ""


## ── StateChart 状态处理器（只负责：1.环境感知 → 2.发送事件 → 3.调用 poll/resolve） ──

func _on_idle_physics(_delta: float) -> void:
	var target := _get_current_target()
	if not target:
		return
	if distance_to_target() <= detect_range:
		state_chart.send_event("player_detected")


func _on_chase_physics(_delta: float) -> void:
	var target := _get_current_target()
	if not target:
		# 无目标 → 回到 Idle（清除复仇，重新搜索玩家）
		_revenge_target = null
		if not player or player.health_component.is_dead:
			state_chart.send_event("player_lost")
		return

	var dist := distance_to_target()

	if dist <= attack_range:
		state_chart.send_event("player_in_range")
		return

	if dist > _leash_distance:
		# 复仇目标太远 → 放弃复仇
		_revenge_target = null
		if not player or player.health_component.is_dead:
			state_chart.send_event("player_lost")
		return

	# 通过通用 Action 表达意图 + 执行
	var actions := poll_actions()
	for action in actions:
		resolve_action(action)


func _on_attack_enter() -> void:
	_attack_timer = 0.0
	velocity = Vector2.ZERO


func _on_attack_physics(delta: float) -> void:
	var target := _get_current_target()
	if not target:
		_revenge_target = null
		state_chart.send_event("player_lost")
		return

	_attack_timer += delta
	var dist := distance_to_target()

	if dist > attack_range * 1.5:
		state_chart.send_event("player_out_of_range")
		return

	# 通过通用 Action 表达意图 + 执行
	var actions := poll_actions()
	for action in actions:
		resolve_action(action)
		_attack_timer = 0.0  # 攻击后重置计时器


const MELEE_SPLASH_RADIUS: float = 40.0   ## 近战溅射半径
const MELEE_SPLASH_DAMAGE: float = 0.5    ## 溅射伤害系数

func _do_melee_attack() -> void:
	var target := _get_current_target()
	if not attack_ready or not target:
		return
	attack_ready = false

	var trace := CombatDebugger.begin("melee_enemy", "敌人近战")
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_hit_sequence()

	# report_hit() 内部已调用 take_damage()
	CombatExecutor.report_hit(self, target, attack_damage, target.global_position, null, ["melee", "enemy"])

	# 溅射伤害：击中附近所有敌人（模拟互殴场景）
	var splash_dmg := int(attack_damage * MELEE_SPLASH_DAMAGE)
	if splash_dmg > 0:
		for body in get_tree().get_nodes_in_group("enemy"):
			if body == self or body == target:
				continue
			if not is_instance_valid(body):
				continue
			var dist := global_position.distance_to(body.global_position)
			if dist <= MELEE_SPLASH_RADIUS:
				CombatExecutor.report_hit(self, body, splash_dmg, body.global_position, null, ["melee", "enemy", "splash"])

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
	get_parent().add_child.call_deferred(drop)
	drop.global_position = global_position
