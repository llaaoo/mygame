extends CharacterBody2D
class_name Enemy

@export var max_hp: int = 30
@export var move_speed: float = 120.0
@export var detect_range: float = 200.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.0
@export var patrol_enabled: bool = false
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var patrol_pause: float = 0.8
@export var suspicion_duration: float = 2.5
@export var return_tolerance: float = 12.0
@export var ranged_preferred_range: float = 180.0
@export var drop_scene: PackedScene

enum AIRole { MELEE, RANGED, HYBRID }
@export var ai_role: AIRole = AIRole.MELEE

@export var enemy_type: int = 1:
	set(value):
		enemy_type = value
		_apply_preset(value)

const PRESETS: Array[Dictionary] = [
	{"name": "哨兵", "color": Color(0.3, 0.9, 0.3, 1.0), "scale": Vector2(0.25, 0.25)},
	{"name": "士兵", "color": Color(0.8, 0.25, 0.25, 1.0), "scale": Vector2(0.4, 0.4)},
	{"name": "重兵", "color": Color(0.6, 0.2, 0.7, 1.0), "scale": Vector2(0.55, 0.55)},
]

const PRESET_STATS: Array[Dictionary] = [
	{"strength": 5, "intelligence": 5, "agility": 15, "endurance": 5},
	{"strength": 10, "intelligence": 8, "agility": 10, "endurance": 10},
	{"strength": 15, "intelligence": 5, "agility": 5, "endurance": 15},
]

const MELEE_SPLASH_RADIUS: float = 40.0
const MELEE_SPLASH_DAMAGE: float = 0.5

var enemy_color: Color = Color.RED
var enemy_scale: Vector2 = Vector2(0.4, 0.4)
var enemy_name: String = "敌人"
var player: Player = null
var attack_ready: bool = true
var _attack_timer: float = 0.0
var _revenge_target: Node2D = null
var _leash_distance: float = 500.0
var _home_position: Vector2 = Vector2.ZERO
var _returning_home: bool = false
var _patrol_index: int = 0
var _patrol_wait_remaining: float = 0.0
var _suspicion_timer: float = 0.0

signal died

@onready var health_component: HealthComponent = $HealthComponent
@onready var skill_manager: SkillManager = $SkillManager
@onready var stats_component: StatsComponent = $StatsComponent
@onready var state_chart: StateChart = $StateChart


func _ready() -> void:
	add_to_group("enemy")
	_home_position = global_position
	$CollisionShape2D.shape = load("res://entities/enemy/enemy_body_shape.tres")
	_create_buff_manager()
	_apply_preset_stats(enemy_type)
	health_component.setup($CollisionShape2D)
	health_component.regen_rate = 0.0
	health_component.died.connect(_on_died)
	_apply_stats_to_health()
	_setup_ranged_skill()
	_apply_preset(enemy_type)
	_apply_visuals()
	_setup_state_chart()
	call_deferred("_subscribe_revenge_events")
	call_deferred("_find_player")


func _setup_ranged_skill() -> void:
	var bolt_data := load("res://gameplay/abilities/data/shadow_bolt_data.tres") as SkillData
	if not bolt_data:
		return
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


func _subscribe_revenge_events() -> void:
	var bus := CombatEventBus.instance
	if not bus:
		await get_tree().process_frame
		_subscribe_revenge_events()
		return
	bus.subscribe(CombatEvent.Type.ON_HIT, _on_got_hit)
	bus.subscribe(CombatEvent.Type.ON_KILL, _on_target_killed)


func _on_got_hit(ev: CombatEvent) -> void:
	if ev.target != self:
		return
	if ev.source == self or not is_instance_valid(ev.source):
		return
	if ev.source is Player:
		_revenge_target = ev.source
		_returning_home = false
		return
	if not _is_valid_revenge_source(ev):
		return
	_revenge_target = ev.source
	_returning_home = false


func _is_valid_revenge_source(ev: CombatEvent) -> bool:
	var tags: Array = ev.data.get("tags", [])
	if tags.has("trap") or tags.has("environment"):
		return false
	var source := ev.source
	if not source or not is_instance_valid(source):
		return false
	return source.is_in_group("enemy") or source.is_in_group("summon")


func _on_target_killed(ev: CombatEvent) -> void:
	if ev.target == _revenge_target:
		_revenge_target = null


func _get_current_target() -> Node2D:
	if _is_valid_target(_revenge_target):
		return _revenge_target
	if _is_valid_target(player) and global_position.distance_to(player.global_position) <= detect_range * 1.35:
		return player
	return null


func _is_valid_target(target: Node2D) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target.has_method("is_dead") and target.is_dead():
		return false
	if target.get("health_component") and target.health_component.is_dead:
		return false
	return true


func get_target_direction() -> Vector2:
	var target := _get_current_target()
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()


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


func poll_actions() -> Array[Action]:
	var actions: Array[Action] = []
	var target := _get_current_target()
	if not target:
		return actions

	var dist := global_position.distance_to(target.global_position)
	match _current_state_name():
		"Chase":
			if _should_move_during_chase(dist):
				actions.append(Action.move(get_target_direction(), self))
			if _can_use_ranged(dist):
				actions.append(Action.cast("right", get_target_direction(), self))
		"Attack":
			if ai_role == AIRole.RANGED:
				if _can_use_ranged(dist):
					actions.append(Action.cast("right", get_target_direction(), self))
			else:
				if attack_ready and _attack_timer >= attack_cooldown:
					actions.append(Action.melee(self))
	return actions


func resolve_action(action: Action) -> void:
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


func _on_idle_physics(delta: float) -> void:
	var target := _get_current_target()
	if target and global_position.distance_to(target.global_position) <= detect_range:
		_returning_home = false
		_suspicion_timer = suspicion_duration
		state_chart.send_event("player_detected")
		return
	_tick_idle_navigation(delta)


func _on_chase_physics(delta: float) -> void:
	var target := _get_current_target()
	if not target:
		_begin_return_home()
		state_chart.send_event("player_lost")
		return

	var dist := global_position.distance_to(target.global_position)
	if _is_out_of_leash(target):
		_begin_return_home()
		state_chart.send_event("player_lost")
		return

	if _should_enter_attack(dist):
		state_chart.send_event("player_in_range")
		return

	if target == player and dist > detect_range * 1.8 and _revenge_target == null:
		_begin_return_home()
		state_chart.send_event("player_lost")
		return

	var actions := poll_actions()
	for action in actions:
		resolve_action(action)


func _on_attack_enter() -> void:
	_attack_timer = 0.0
	velocity = Vector2.ZERO


func _on_attack_physics(delta: float) -> void:
	var target := _get_current_target()
	if not target:
		_begin_return_home()
		state_chart.send_event("player_lost")
		return

	_attack_timer += delta
	var dist := global_position.distance_to(target.global_position)
	if _is_out_of_leash(target):
		_begin_return_home()
		state_chart.send_event("player_lost")
		return

	if _should_leave_attack(dist):
		state_chart.send_event("player_out_of_range")
		return

	if ai_role == AIRole.RANGED and dist < attack_range * 0.7:
		velocity = (global_position - target.global_position).normalized() * move_speed * 0.7
		move_and_slide()
		return

	var actions := poll_actions()
	for action in actions:
		resolve_action(action)
		if action.action_type == Action.ActionType.MELEE:
			_attack_timer = 0.0


func _should_move_during_chase(dist: float) -> bool:
	if ai_role == AIRole.RANGED:
		return dist > ranged_preferred_range
	if ai_role == AIRole.HYBRID:
		return dist > attack_range * 0.95
	return true


func _should_enter_attack(dist: float) -> bool:
	if ai_role == AIRole.RANGED:
		return dist <= ranged_preferred_range
	return dist <= attack_range


func _should_leave_attack(dist: float) -> bool:
	if ai_role == AIRole.RANGED:
		return dist > ranged_preferred_range * 1.15
	return dist > attack_range * 1.35


func _can_use_ranged(dist: float) -> bool:
	if ai_role == AIRole.MELEE:
		return false
	if not skill_manager or not skill_manager.can_use("right"):
		return false
	return dist <= ranged_preferred_range


func _is_out_of_leash(target: Node2D) -> bool:
	if not target:
		return true
	return _home_position.distance_to(target.global_position) > _leash_distance


func _begin_return_home() -> void:
	_revenge_target = null
	_returning_home = true
	_suspicion_timer = suspicion_duration
	velocity = Vector2.ZERO


func _tick_idle_navigation(delta: float) -> void:
	if _suspicion_timer > 0.0:
		_suspicion_timer = maxf(0.0, _suspicion_timer - delta)

	if _returning_home:
		_move_towards_point(_home_position)
		if global_position.distance_to(_home_position) <= return_tolerance:
			_returning_home = false
			velocity = Vector2.ZERO
		return

	if not patrol_enabled or patrol_points.is_empty():
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 0.25)
		move_and_slide()
		return

	if _patrol_wait_remaining > 0.0:
		_patrol_wait_remaining = maxf(0.0, _patrol_wait_remaining - delta)
		velocity = Vector2.ZERO
		return

	var target_point := _get_patrol_world_point(_patrol_index)
	_move_towards_point(target_point)
	if global_position.distance_to(target_point) <= return_tolerance:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_patrol_wait_remaining = patrol_pause
		velocity = Vector2.ZERO


func _get_patrol_world_point(index: int) -> Vector2:
	if patrol_points.is_empty():
		return _home_position
	return _home_position + patrol_points[index]


func _move_towards_point(target_point: Vector2) -> void:
	var dir := target_point - global_position
	if dir.length_squared() <= 1.0:
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * move_speed
	move_and_slide()


func _do_melee_attack() -> void:
	var target := _get_current_target()
	if not attack_ready or not target:
		return
	attack_ready = false

	var trace := CombatDebugger.begin("melee_enemy", "敌人近战")
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_hit_sequence()

	CombatExecutor.report_hit(self, target, attack_damage, target.global_position, null, ["melee", "enemy"])

	var splash_dmg := int(attack_damage * MELEE_SPLASH_DAMAGE)
	if splash_dmg > 0:
		for body in get_tree().get_nodes_in_group("enemy"):
			if body == self or body == target:
				continue
			if not is_instance_valid(body):
				continue
			if global_position.distance_to(body.global_position) <= MELEE_SPLASH_RADIUS:
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


func _apply_preset_stats(type_idx: int) -> void:
	if type_idx < 0 or type_idx >= PRESET_STATS.size():
		return
	var s := PRESET_STATS[type_idx]
	stats_component.strength = s["strength"]
	stats_component.intelligence = s["intelligence"]
	stats_component.agility = s["agility"]
	stats_component.endurance = s["endurance"]
	stats_component._recalculate_all()


func _apply_stats_to_health() -> void:
	health_component.max_hp = max_hp
	health_component.hp = health_component.max_hp
	move_speed += stats_component.move_speed_bonus
	attack_damage += stats_component.physical_damage


func _apply_preset(type_idx: int) -> void:
	if type_idx < 0 or type_idx >= PRESETS.size():
		return
	var preset := PRESETS[type_idx]
	enemy_name = preset["name"]
	enemy_color = preset["color"]
	enemy_scale = preset["scale"]


func _apply_visuals() -> void:
	var spr := $Sprite2D
	spr.modulate = enemy_color
	spr.scale = enemy_scale


func _flash_damage() -> void:
	var spr := $Sprite2D
	spr.modulate = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	spr.modulate = enemy_color


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		await get_tree().create_timer(0.5).timeout
		_find_player()


func get_player_direction() -> Vector2:
	if not player:
		return Vector2.ZERO
	return (player.global_position - global_position).normalized()


func distance_to_player() -> float:
	if not player:
		return INF
	return global_position.distance_to(player.global_position)


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
	var drop := drop_scene.instantiate()
	get_parent().add_child.call_deferred(drop)
	drop.global_position = global_position
