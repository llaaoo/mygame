extends CharacterBody2D
class_name Player

## ── 移动 ──
@export var move_speed: float = 300.0

## ── 技能（导出在 Player，运行时转发给 SkillManager） ──
@export var skill_scene: PackedScene

## ── 背包 ──
@export var inventory: Inventory
var inventory_panel: InventoryPanel

## ── 调试 ──
@export var debug_items: bool = false

## ── 信号（HUD 订阅） ──
signal health_changed(current_hp: int, max_hp: int)
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

## ── 状态机 ──
var state_machine: Node


func _ready() -> void:
	add_to_group("player")

	# 身体碰撞形状
	collision_shape.shape = load("res://entities/player/player_body_shape.tres")

	# 初始化组件
	health_component.setup(collision_shape)
	combat_component.setup(self, attack_hitbox, attack_hitbox_shape, animation_player)

	# 技能：编辑器设置优先，否则加载默认
	if skill_scene:
		_setup_skill_from_legacy()
	else:
		_setup_default_skills()

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


## ── 技能初始化 ──

func _setup_skill_from_legacy() -> void:
	# 兼容旧版：将单个 skill_scene 包装为 SkillData
	var data := SkillData.new()
	data.skill_id = "fireball"
	data.display_name = "火球术"
	data.cooldown = 2.0
	data.damage = 25
	data.scene = skill_scene
	data.cast_distance = 30.0
	skill_manager.skills = [data]
	skill_manager._ready()  # 重新初始化冷却数组


func _setup_default_skills() -> void:
	# 加载预设技能数据
	var fireball := load("res://skills/fireball_data.tres") as SkillData
	if fireball:
		fireball.scene = load("res://skills/fireball.tscn")  # Resource 引用在代码中设置
		skill_manager.skills = [fireball]
		skill_manager._ready()


## ── 信号转发 ──

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_changed.emit(current_hp, max_hp)


func _on_died() -> void:
	set_process(false)
	set_physics_process(false)
	print("💀 玩家死亡！")
	died.emit()


func _on_skill_cooldown(skill_index: int, remaining: float, total: float) -> void:
	if skill_index == 0:
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


func cast_skill() -> void:
	skill_manager.use_skill(0, self, get_mouse_direction())
	if animation_player.has_animation("skill"):
		animation_player.play("skill")


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


func heal(amount: int) -> void:
	health_component.heal(amount)
