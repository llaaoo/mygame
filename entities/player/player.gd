extends CharacterBody2D
class_name Player

## ── 移动基础值（最终速度 = 基础 + 敏捷加成） ──
@export var base_move_speed: float = 300.0

## ── 背包 ──
@export var inventory: Inventory
var inventory_panel: InventoryPanel
var skill_pool_ui: SkillPoolUI = null
var _skill_pool: SkillPool = null

## ── 调试 ──
@export var debug_items: bool = false

## ── 信号（HUD 订阅） ──
signal health_changed(current_hp: int, max_hp: int)
signal mp_changed(current_mp: int, max_mp: int)
signal died
signal skill_cooldown_changed(remaining: float, total: float)

## ── 朝向 ──
var facing_direction: Vector2 = Vector2.DOWN

## ── 节点引用 ──
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var skill_manager: SkillManager = $SkillManager
@onready var stats_component: StatsComponent = $StatsComponent
var mana_component: ManaComponent = null

## ── 瞄准状态 ──
var _aiming_left: bool = false
var _aiming_right: bool = false
## ── 待释放的技能来源（"left"/"right"/"slot_N"） ──
var pending_skill_source: String = ""

## ── 运行时移动速度（基础 + 敏捷加成） ──
var move_speed: float = 300.0

## ── 状态机 ──
var state_machine: Node


func _ready() -> void:
	add_to_group("player")

	# 身体碰撞形状
	collision_shape.shape = load("res://entities/player/player_body_shape.tres")

	# MP 组件（先创建，_apply_stats 依赖它）
	if not mana_component:
		_create_mana_component()
	mana_component.mp_changed.connect(_on_mp_changed)

	# 属性系统
	_apply_stats()
	stats_component.stat_changed.connect(_on_stat_changed)

	# 初始化组件
	health_component.setup(collision_shape)
	combat_component.setup(self, attack_hitbox, attack_hitbox_shape, animation_player)

	# 技能初始化
	_setup_skills()

	# 转发组件信号 → Player 信号
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	skill_manager.cooldown_changed.connect(_on_skill_cooldown)

	# 状态机
	_setup_state_machine()

	# 视觉
	if sprite and sprite.texture:
		sprite.scale = Vector2(0.5, 0.5)
	sprite.z_as_relative = false
	sprite.z_index = 10

	# 背包面板
	call_deferred("_setup_inventory_panel")

	# 技能池面板
	call_deferred("_setup_skill_pool_ui")


## ── 属性系统 ──

## 追踪上一次属性推导值，用于增量应用（保留装备加成不被覆盖）
var _last_stat_hp: int = 0
var _last_stat_mp: int = 0
var _last_stat_dmg: int = 0
var _last_stat_speed: float = 0.0


func _apply_stats() -> void:
	stats_component._recalculate_all()

	var new_hp := 50 + stats_component.max_hp_bonus
	var new_mp := stats_component.max_mana
	var new_dmg := 10 + stats_component.physical_damage
	var new_speed := base_move_speed + stats_component.move_speed_bonus

	if _last_stat_hp == 0:
		# 首次调用：绝对赋值
		health_component.max_hp = new_hp
		mana_component.max_mp = new_mp
		combat_component.attack_damage = new_dmg
		move_speed = new_speed
	else:
		# 后续调用：只应用差值，保留装备等外部加成
		health_component.max_hp += new_hp - _last_stat_hp
		mana_component.max_mp += new_mp - _last_stat_mp
		combat_component.attack_damage += new_dmg - _last_stat_dmg
		move_speed += new_speed - _last_stat_speed

	health_component.hp = clampi(health_component.hp, 1, health_component.max_hp)
	mana_component.mp = clampi(mana_component.mp, 0, mana_component.max_mp)

	_last_stat_hp = new_hp
	_last_stat_mp = new_mp
	_last_stat_dmg = new_dmg
	_last_stat_speed = new_speed


func _on_stat_changed(_stat_name: String, _new_value: int) -> void:
	_apply_stats()
	health_changed.emit(health_component.hp, health_component.max_hp)
	mp_changed.emit(mana_component.mp, mana_component.max_mp)


## ── 魔能 ──

func _create_mana_component() -> void:
	var mc := ManaComponent.new()
	mc.name = "ManaComponent"
	add_child(mc)
	mana_component = mc


func _on_mp_changed(current_mp: int, max_mp: int) -> void:
	mp_changed.emit(current_mp, max_mp)


func use_mp(amount: int) -> bool:
	return mana_component.use_mp(amount)


func restore_mp(amount: int) -> void:
	mana_component.restore_mp(amount)


## ── 技能初始化 ──

func _setup_skills() -> void:
	_skill_pool = load("res://skills/player_skill_pool.tres") as SkillPool
	if not _skill_pool:
		_skill_pool = SkillPool.new()

	# 确保火球在池中
	if not _skill_pool.has_skill("fireball"):
		var fireball := load("res://skills/fireball_data.tres") as SkillData
		if fireball:
			fireball.projectile_scene = load("res://skills/fireball.tscn")
			fireball.damage = 25 + stats_component.magic_damage
			fireball.mp_cost = 15
			fireball.skill_type = SkillData.SkillType.PROJECTILE
			_skill_pool.add_skill(fireball)

	# 右手默认装备火球
	var fireball := _skill_pool.get_skill("fireball")
	skill_manager.equip_hand("right", fireball)


## ── 信号转发 ──

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_changed.emit(current_hp, max_hp)


func _on_died() -> void:
	set_process(false)
	set_physics_process(false)
	print("💀 玩家死亡！")
	died.emit()


func _on_skill_cooldown(skill_index: int, remaining: float, total: float) -> void:
	skill_cooldown_changed.emit(remaining, total)


## ── 状态机 ──

func _setup_state_machine() -> void:
	state_machine = $StateMachine
	if not state_machine.get_script():
		return

	for child in state_machine.get_children():
		if child.has_method("enter") and child.get("entity") != self:
			child.set("entity", self)


## ── 背包 ──

func _setup_inventory_panel() -> void:
	var panel = get_tree().current_scene.get_node_or_null("InventoryPanel")
	if not panel:
		var panel_scene = load("res://ui/inventory_panel.tscn") as PackedScene
		if panel_scene:
			panel = panel_scene.instantiate()
			panel.name = "InventoryPanel"
			get_tree().current_scene.add_child.call_deferred(panel)

	if panel and panel is InventoryPanel:
		inventory_panel = panel
		if not inventory:
			inventory = load("res://items/player_inventory.tres") as Inventory
		inventory_panel.setup(inventory, $EquipmentManager)
		if debug_items:
			_add_test_items()


func _setup_skill_pool_ui() -> void:
	var ui := SkillPoolUI.new()
	ui.name = "SkillPoolUI"
	get_tree().current_scene.add_child.call_deferred(ui)
	ui.setup(_skill_pool, skill_manager)


func _add_test_items() -> void:
	if not inventory:
		return
	var helmet = load("res://items/examples/iron_helmet.tres")
	var armor = load("res://items/examples/leather_armor.tres")
	var boots = load("res://items/examples/iron_boots.tres")
	inventory.add_item(helmet, 1)
	inventory.add_item(armor, 1)
	inventory.add_item(boots, 1)
	print("🎒 测试装备已添加到背包")


## ── 公开 API ──

func get_mouse_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()


func perform_melee_attack() -> void:
	combat_component.perform_melee_attack()


## 释放左手或右手技能
func cast_hand(hand: String) -> void:
	var ok := skill_manager.use_hand(hand, self, get_mouse_direction())
	if ok and animation_player.has_animation("skill"):
		animation_player.play("skill")


## 释放快捷键槽位技能
func cast_slot(idx: int) -> void:
	var ok := skill_manager.use_slot(idx, self, get_mouse_direction())
	if ok and animation_player.has_animation("skill"):
		animation_player.play("skill")


## 开始瞄准（按下时调用）
func start_aim(hand: String) -> void:
	if hand == "left":
		_aiming_left = true
	else:
		_aiming_right = true


## 结束瞄准并释放（松手时调用）
func end_aim(hand: String) -> void:
	if hand == "left":
		_aiming_left = false
	else:
		_aiming_right = false
	pending_skill_source = hand


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


func heal(amount: int) -> void:
	health_component.heal(amount)
