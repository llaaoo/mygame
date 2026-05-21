extends CharacterBody2D
class_name Player

## 移动参数
@export var move_speed: float = 300.0

## 攻击参数
@export var attack_range: float = 40.0
@export var attack_damage: int = 10

## 技能参数
@export var skill_scene: PackedScene

## 背包
@export var inventory: Inventory

## 面板引用（Tab 切换）
var inventory_panel: InventoryPanel

## 生命值
@export var max_hp: int = 100
var hp: int = 100

## 受伤无敌
@export var invincible_duration: float = 0.5
var invincible: bool = false
var is_dead: bool = false

## 脱战自回（不受伤害 regen_delay 秒后，每秒回复 regen_rate HP）
@export var regen_delay: float = 5.0
@export var regen_rate: float = 3.0
var _time_since_damage: float = 0.0
var _regen_accumulator: float = 0.0

## 技能冷却
@export var skill_cooldown: float = 2.0
var skill_cooldown_remaining: float = 0.0

## 信号
signal health_changed(current_hp: int, max_hp: int)
signal died
signal skill_cooldown_changed(remaining: float, total: float)

## 当前朝向
var facing_direction: Vector2 = Vector2.DOWN

## 引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

## 状态机引用
var state_machine: Node
var _states: Dictionary = {}
var _current_state: Node = null

func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	_setup_collisions()
	_setup_state_machine()

	if sprite and sprite.texture:
		sprite.scale = Vector2(0.5, 0.5)
	sprite.z_as_relative = false
	sprite.z_index = 10

	# 设置背包面板
	call_deferred("_setup_inventory_panel")

func _process(delta: float) -> void:
	# 技能冷却递减
	if skill_cooldown_remaining > 0:
		skill_cooldown_remaining = max(0.0, skill_cooldown_remaining - delta)
		skill_cooldown_changed.emit(skill_cooldown_remaining, skill_cooldown)

	# 脱战自回
	if not is_dead and hp < max_hp:
		_time_since_damage += delta
		if _time_since_damage >= regen_delay:
			_regen_accumulator += regen_rate * delta
			var heal_amt = int(_regen_accumulator)
			if heal_amt > 0:
				_regen_accumulator -= heal_amt
				hp = min(max_hp, hp + heal_amt)
				health_changed.emit(hp, max_hp)

	if _current_state and _current_state.has_method("update"):
		_current_state.update(delta)

func _physics_process(delta: float) -> void:
	if _current_state and _current_state.has_method("physics_update"):
		_current_state.physics_update(delta)

## 如果 StateMachine 节点有脚本就用它，否则自行管理状态
func _setup_state_machine() -> void:
	state_machine = $StateMachine

	if state_machine.get_script():
		print("🔍 Player: StateMachine 脚本已挂载，由它管理状态")
		for child in state_machine.get_children():
			if child.has_method("enter") and child.get("entity") != self:
				child.set("entity", self)
		return

	print("🔍 Player: StateMachine 无脚本，使用备用状态管理")
	for child in state_machine.get_children():
		if child is State or child.has_method("enter"):
			_states[child.name.to_lower()] = child
			if child.has_signal("transitioned") and not child.transitioned.is_connected(_on_state_transition):
				child.transitioned.connect(_on_state_transition)
			child.set("entity", self)

	_current_state = _states.get("idle")
	if _current_state:
		print("🔍 Player: 进入初始状态: ", _current_state.name)
		_current_state.enter()
	else:
		print("❌ Player: 找不到 idle 状态！可用状态: ", _states.keys())

## 连接背包面板
func _setup_inventory_panel() -> void:
	var panel = get_tree().current_scene.get_node_or_null("InventoryPanel")
	if panel and panel is InventoryPanel:
		inventory_panel = panel
		inventory_panel.setup(inventory, $EquipmentManager)
		# 添加测试物品
		_add_test_items()


func _add_test_items() -> void:
	if not inventory:
		return
	# 加载示例装备并放入背包
	var helmet = load("res://items/examples/iron_helmet.tres")
	var armor = load("res://items/examples/leather_armor.tres")
	var boots = load("res://items/examples/iron_boots.tres")
	inventory.add_item(helmet, 1)
	inventory.add_item(armor, 1)
	inventory.add_item(boots, 1)
	print("🎒 测试装备已添加到背包")


func _on_state_transition(state: Node, new_state_name: String) -> void:
	if state != _current_state:
		return
	var new_state = _states.get(new_state_name.to_lower())
	if not new_state:
		return
	if _current_state:
		_current_state.exit()
	new_state.enter()
	_current_state = new_state

func _setup_collisions() -> void:
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	collision_shape.shape = circle

	var rect = RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	attack_hitbox_shape.shape = rect
	attack_hitbox_shape.disabled = false
	attack_hitbox.monitoring = false

	if not attack_hitbox.body_entered.is_connected(_on_attack_hit):
		attack_hitbox.body_entered.connect(_on_attack_hit)
	if not attack_hitbox.area_entered.is_connected(_on_attack_hit_area):
		attack_hitbox.area_entered.connect(_on_attack_hit_area)

## 获取鼠标相对于玩家的方向
func get_mouse_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()

## 被状态机调用 - 执行近战攻击
func perform_melee_attack() -> void:
	var attack_dir = get_mouse_direction()
	facing_direction = attack_dir
	attack_hitbox.position = attack_dir * attack_range
	attack_hitbox.rotation = attack_dir.angle()
	attack_hitbox.monitoring = true

	if animation_player.has_animation("attack"):
		animation_player.play("attack")

	await get_tree().create_timer(0.15).timeout
	attack_hitbox.monitoring = false
	attack_hitbox.position = Vector2.ZERO

## 攻击命中敌人
func _on_attack_hit(body: Node2D) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

func _on_attack_hit_area(area: Area2D) -> void:
	if area.owner == self:
		return
	if area.has_method("take_damage"):
		area.take_damage(attack_damage)

## 被敌人攻击时调用（供敌人和技能调用）
func take_damage(amount: int) -> void:
	if invincible:
		return

	hp = max(0, hp - amount)
	health_changed.emit(hp, max_hp)
	print("🩸 玩家受到伤害: ", amount, " 剩余HP: ", hp, "/", max_hp)

	# 受伤重置自回计时
	_time_since_damage = 0.0

	if hp <= 0:
		is_dead = true
		died.emit()
		set_process(false)
		set_physics_process(false)
		collision_shape.set_deferred("disabled", true)
		print("💀 玩家死亡！")
		return

	invincible = true
	await get_tree().create_timer(invincible_duration).timeout
	invincible = false

## 恢复生命值（供拾取物、Buff、技能等调用）
func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	print("💚 玩家恢复: ", amount, " HP: ", hp, "/", max_hp)

## 被状态机调用 - 释放技能
func cast_skill() -> void:
	if skill_scene == null:
		return
	if skill_cooldown_remaining > 0:
		return

	var skill_dir = get_mouse_direction()
	facing_direction = skill_dir

	var skill_instance = skill_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(skill_instance)

	skill_instance.global_position = global_position + skill_dir * 30.0
	if skill_instance.has_method("set_direction"):
		skill_instance.set_direction(skill_dir)
	if skill_instance.has_method("set_caster"):
		skill_instance.set_caster(self)

	skill_cooldown_remaining = skill_cooldown
	skill_cooldown_changed.emit(skill_cooldown_remaining, skill_cooldown)

	if animation_player.has_animation("skill"):
		animation_player.play("skill")
