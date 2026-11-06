extends CharacterBody2D
class_name Enemy
var actor_context: ActorContext

@export var character_definition: ActorCharacterData
var base_move_speed := 120.0
var melee_damage_multiplier := 1.0
var mana_component: ManaComponent
var character_brain: EnemyCharacterBrain
var _character_synergies: SkillSynergyResolver
var _player_search: Timer

@export var max_hp: int = 30
@export var move_speed: float = 120.0
@export var detect_range: float = 200.0
@export var attack_range: float = 55.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.0
@export var melee_windup := 0.4
@export var melee_recovery := 0.25
@export var ranged_windup := 0.45
@export var patrol_enabled: bool = false
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var patrol_pause: float = 0.8
@export var suspicion_duration: float = 2.5
@export var return_tolerance: float = 12.0
@export var ranged_preferred_range: float = 180.0
@export var drop_scene: PackedScene
@export var health_drop_amount := 20
@export var mana_drop_amount := 30
var rewards_enabled := true
var physical_loot := false
var story_truce := false

enum AIRole { MELEE, RANGED, HYBRID }
@export var ai_role: AIRole = AIRole.MELEE

@export var enemy_type: int = 1:
	set(value):
		enemy_type = value
		_apply_preset(value)

const PRESETS: Array[Dictionary] = [
	{"name": "哨兵", "scale": Vector2(0.24, 0.24)},
	{"name": "士兵", "scale": Vector2(0.26, 0.26)},
	{"name": "重兵", "scale": Vector2(0.3, 0.3)},
]

const PRESET_TEXTURE_PATHS: Array[String] = [
	"res://content/art/pixel/actors/enemy_scout.tres",
	"res://content/art/pixel/actors/enemy_soldier.tres",
	"res://content/art/pixel/actors/enemy_brute.tres",
]

const PRESET_STATS: Array[Dictionary] = [
	{"strength": 5, "intelligence": 5, "agility": 15, "endurance": 5},
	{"strength": 10, "intelligence": 8, "agility": 10, "endurance": 10},
	{"strength": 15, "intelligence": 5, "agility": 5, "endurance": 15},
]

const MELEE_SPLASH_RADIUS: float = 40.0
const MELEE_SPLASH_DAMAGE: float = 0.5

var attack_preparation: EnemyAttackPreparation
var surface_awareness: EnemySurfaceAwareness
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
var _attack_ready_remaining := 0.0
var _flash_tween: Tween

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
	attack_preparation = EnemyAttackPreparation.new()
	attack_preparation.actor = self
	add_child(attack_preparation)
	surface_awareness = EnemySurfaceAwareness.new()
	surface_awareness.actor = self
	surface_awareness.cautious = ai_role == AIRole.RANGED
	add_child(surface_awareness)
	_apply_preset_stats(enemy_type)
	health_component.setup($CollisionShape2D)
	health_component.regen_rate = 0.0
	health_component.died.connect(_on_died)
	_apply_stats_to_health()
	if character_definition:
		_setup_character()
	else:
		_setup_ranged_skill()
	_apply_preset(enemy_type)
	_apply_visuals()
	if character_definition: enemy_name=character_definition.title
	_setup_state_chart()
	call_deferred("_subscribe_revenge_events")
	call_deferred("_find_player")


func _setup_character() -> void:
	mana_component=ManaComponent.new()
	mana_component.name="ManaComponent"
	add_child(mana_component)
	var equipment:=EquipmentManager.new()
	equipment.name="EquipmentManager"
	add_child(equipment)
	ActorCombatModel.initialize_body(self,character_definition)
	_apply_stats()
	ActorCombatModel.configure_actions(self,character_definition)
	ActorCombatModel.configure_equipment(self,character_definition)
	ActorEquipmentVisual.install(self)
	if physical_loot:
		add_to_group("interactable")
		var interaction := Interactable.new()
		interaction.name = "Interactable"
		interaction.set_callback(func(_actor: Node2D):
			if actor_context and actor_context.inspect_requested.is_valid(): actor_context.inspect_requested.call(self))
		add_child(interaction)
	health_component.hp=health_component.max_hp
	mana_component.mp=mana_component.max_mp
	stats_component.stat_changed.connect(func(_key,_value):_apply_stats())
	character_brain=EnemyCharacterBrain.new(self)
	var status:=preload("res://entities/enemy/enemy_character_status.gd").new()
	status.actor=self
	add_child(status)

func _apply_stats() -> void:
	if not character_definition or not is_instance_valid(mana_component): return
	ActorCombatModel.rebuild(self)
	max_hp=health_component.max_hp


func _setup_ranged_skill() -> void:
	var bolt_data := load("res://gameplay/abilities/data/shadow_bolt_data.tres") as SkillData
	if not bolt_data:
		return
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
	if character_definition and not _character_synergies:
		_character_synergies=SkillSynergyResolver.new()
		add_child(_character_synergies)
		_character_synergies.setup(self)
	bus.subscribe(CombatEvent.Type.ON_HIT, _on_got_hit)
	bus.subscribe(CombatEvent.Type.ON_KILL, _on_target_killed)


func _on_got_hit(ev: CombatEvent) -> void:
	if ev.target != self or health_component.is_dead:
		return
	if ev.source == self or not is_instance_valid(ev.source):
		return
	if ev.source is Player:
		if story_truce:
			story_truce=false
			if actor_context and actor_context.hostile_requested.is_valid(): actor_context.hostile_requested.call(self)
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
	if story_truce: return null
	if actor_context and actor_context.relations.attitude(actor_context.id,"player")=="friendly" and not _is_valid_target(_revenge_target): return null
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
	if character_brain: return character_brain.choose(target)
	match _current_state_name():
		"Chase":
			if _should_move_during_chase(dist):
				actions.append(Action.move(get_target_direction(), self))
			if _can_use_ranged(dist):
				actions.append(Action.cast("right", get_target_direction(), self))
		"Attack":
			if surface_awareness and surface_awareness.should_evade:
				actions.append(Action.move(surface_awareness.direction, self))
			if ai_role == AIRole.RANGED:
				if _can_use_ranged(dist):
					actions.append(Action.cast("right", get_target_direction(), self))
			else:
				if attack_ready and _attack_timer >= attack_cooldown:
					actions.append(Action.melee(self))
	return actions


func resolve_action(action: Action) -> void:
	if actor_context and actor_context.actions.active() and action.action_type in [Action.ActionType.MOVE,Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK,Action.ActionType.GUARD,Action.ActionType.USE_ITEM]:
		if action.action_type==Action.ActionType.MELEE: action.direction=get_target_direction()
		actor_context.actions.try_action(action)
		return
	if actor_context and actor_context.actions.active() and actor_context.actions.busy(): return
	if attack_preparation and attack_preparation.busy(): return
	if character_definition and skill_manager.combinations.is_busy(): return
	if not ActionResolver.validate(self, action):
		return

	match action.action_type:
		Action.ActionType.MOVE:
			var direction := surface_awareness.steer(action.direction) * action.direction.length() if surface_awareness else action.direction
			velocity = direction * move_speed
			move_and_slide()
		Action.ActionType.CAST:
			var target := _get_current_target()
			var direction := action.direction
			var context := action.cast_context
			attack_preparation.begin(target, direction, ranged_windup, 0, func():
				if not skill_manager.use_source(action.skill_source,self,context) and character_brain: character_brain.refused()
			, "ranged")
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

	if character_brain:
		for action in poll_actions():
			resolve_action(action)
			if action.action_type==Action.ActionType.MELEE: _attack_timer=0
		return

	if ai_role == AIRole.RANGED and dist < attack_range * 0.7:
		resolve_action(Action.move((global_position - target.global_position).normalized() * 0.7, self))
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
	if character_definition:
		skill_manager.combinations.cancel("目标失效：准备取消")
		attack_preparation.cancel()
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
	if actor_context and actor_context.actions.active() and actor_context.actions.busy(): return
	if attack_preparation and attack_preparation.busy(): return
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
	if not attack_preparation.begin(target, (target.global_position - global_position).normalized(), melee_windup, melee_recovery, func():
		if attack_preparation.melee_connects(): _resolve_melee_hit(target)
	, "melee"): return
	attack_ready = false
	_attack_ready_remaining = maxf(attack_cooldown, melee_windup + melee_recovery)

func _resolve_melee_hit(target: Node2D) -> void:
	var trace := CombatDebugger.begin("melee_enemy", "敌人近战")
	var exec_inst := CombatExecutor.instance
	if exec_inst:
		exec_inst.begin_hit_sequence()

	ActorCombatModel.melee_contact(self,target,attack_damage,["melee","enemy"])

	var splash_dmg := 0 if character_definition else int(attack_damage * MELEE_SPLASH_DAMAGE)
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


func _process(delta: float) -> void:
	if character_brain: character_brain.tick(delta)
	if not attack_ready:
		_attack_ready_remaining = maxf(0, _attack_ready_remaining - delta)
		if _attack_ready_remaining == 0:
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
	enemy_color = Color.WHITE
	enemy_scale = preset["scale"]


func _apply_visuals() -> void:
	var spr := $Sprite2D as Sprite2D
	if enemy_type >= 0 and enemy_type < PRESET_TEXTURE_PATHS.size():
		spr.texture = load(PRESET_TEXTURE_PATHS[enemy_type]) as Texture2D
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.modulate = Color.WHITE
	spr.scale = enemy_scale


func _flash_damage() -> void:
	var spr := $Sprite2D
	spr.modulate = Color(1.0, 0.35, 0.35, 1.0)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(spr, "modulate", Color.WHITE, 0.1)


func _find_player() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		if not _player_search:
			_player_search=Timer.new()
			_player_search.one_shot=true
			_player_search.wait_time=.5
			_player_search.timeout.connect(_find_player)
			add_child(_player_search)
		_player_search.start()


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
	health_component.take_damage(ActorCombatModel.incoming_damage(self,amount))


func _on_died() -> void:
	if character_definition:
		skill_manager.combinations.cancel("死亡")
		skill_manager.combinations.clear_field()
	if attack_preparation: attack_preparation.cancel()
	if player and rewards_enabled:
		CombatExecutor.report_exp_bonus(player, 30 + stats_component.level * 10)
	if rewards_enabled and not physical_loot: _spawn_drop()
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
	if drop is HealthPickup: drop.heal_amount = health_drop_amount
	if drop is ManaPickup: drop.mana_amount = mana_drop_amount
	get_parent().add_child.call_deferred(drop)
	drop.global_position = global_position

func _exit_tree() -> void:
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_HIT,_on_got_hit)
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_KILL,_on_target_killed)
	if character_definition and is_instance_valid(skill_manager) and skill_manager.combinations:
		skill_manager.combinations.cancel("离区")
		skill_manager.combinations.clear_field()
