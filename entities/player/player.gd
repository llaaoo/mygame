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

## ── 持有 TriggeredEffect 引用以防 Resource GC ──
var _on_kill_effect: OnKillBonusExp = null
var _on_hit_effect: TriggeredEffect = null
var _on_ice_expire: OnIceArmorExpire = null

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

## ── 待释放的技能来源（"slot_N"，仅快捷键用） ──
var pending_skill_source: String = ""
## ── 瞄准状态（跨状态保持） ──
var aiming_sources: Dictionary = {}
var cancel_aim: bool = false
## ── UI 面板打开时阻止游戏输入 ──
var ui_blocked: bool = false
## ── 瞄准指示器 ──
var _aim_line: Line2D = null
var _aim_dot: Sprite2D = null
var _aim_distance: float = 60.0

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

	# 战斗事件总线（如果有则复用，没有则创建）
	_setup_event_bus()

	# 转发组件信号 → Player 信号
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	skill_manager.cooldown_changed.connect(_on_skill_cooldown)

	# 瞄准指示器
	_setup_aim_indicator()

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
	# 1. 加载技能池（注册表）
	_skill_pool = load("res://runtime/combat/skills/registry/player_skill_pool.tres") as SkillPool
	if not _skill_pool:
		_skill_pool = SkillPool.new()

	# 2. 确保所有技能在池中（纯数据，不计算伤害）
	if not _skill_pool.has_skill("fireball"):
		var fireball := load("res://runtime/combat/skills/data/fireball_data.tres") as SkillData
		if fireball:
			fireball.projectile_scene = load("res://runtime/combat/skills/scenes/fireball.tscn")
			fireball.damage = 25
			fireball.damage_scaling = 1.0          # 100% 魔法伤害加成
			fireball.mp_cost = 15
			fireball.skill_type = SkillData.SkillType.PROJECTILE
			fireball.tags = ["fire"]
			_skill_pool.add_skill(fireball)

	for sid in ["ice_armor", "flame_storm", "shadow_step", "ice_explosion"]:
		if not _skill_pool.has_skill(sid):
			var skill := load("res://runtime/combat/skills/data/%s_data.tres" % sid) as SkillData
			if skill:
				match sid:
					"ice_armor":
						skill.buff_resource = load("res://runtime/combat/skills/data/ice_armor_buff.tres") as Buff
						skill.tags = ["ice"]
					"flame_storm":
						skill.aoe_scene = load("res://runtime/combat/skills/scenes/flame_storm.tscn") as PackedScene
						skill.cast_distance = 150.0
						skill.damage_scaling = 1.2
						skill.tags = ["fire"]
					"shadow_step":
						skill.buff_resource = load("res://runtime/combat/skills/data/shadow_step_buff.tres") as Buff
						skill.tags = ["shadow"]
					"ice_explosion":
						skill.aoe_scene = load("res://runtime/combat/skills/scenes/ice_explosion.tscn") as PackedScene
						skill.tags = ["ice", "aoe"]
				_skill_pool.add_skill(skill)

	# 3. 构建索引
	_skill_pool.build()

	# 4. 注入 pool 到 skill_manager（供 loadout 使用）
	skill_manager.pool = _skill_pool

	# 5. 应用装备映射表
	var loadout := SkillLoadout.create(
		"ice_armor",    # 左手
		"fireball",     # 右手
		["flame_storm", "shadow_step", "ice_explosion"]  # 快捷键 1/2/3
	)
	skill_manager.apply_loadout(loadout)

	# 6. 注入 Modifier Pipeline（伤害不是算出来的，是一层层改出来的）
	_setup_damage_modifiers()


## 配置伤害管线（分阶段：FLAT → MULTIPLY → OVERRIDE → FINAL）
func _setup_damage_modifiers() -> void:
	var executor := skill_manager.executor
	if not executor:
		return

	# Stage FLAT: 属性缩放 — 智力 → 魔法伤害
	var stat_mod := StatScalingModifier.new()
	stat_mod.stat_name = "magic_damage"
	stat_mod.ratio = 1.0  # fallback，技能自身的 damage_scaling 优先
	executor.add_modifier(stat_mod)

	# Stage MULTIPLY: 火焰增伤 +20%（示例：火系天赋/装备）
	# var fire_mod := TagMultiplierModifier.new()
	# fire_mod.required_tags = ["fire"]
	# fire_mod.multiplier = 1.2
	# executor.add_modifier(fire_mod)

	# Stage OVERRIDE: 火焰免疫（示例：Boss 词缀）
	# var fire_immune := TagMultiplierModifier.new()
	# fire_immune.required_tags = ["fire"]
	# fire_immune.multiplier = 0.0
	# fire_immune.stage = DamageModifier.Stage.OVERRIDE
	# executor.add_modifier(fire_immune)


## 确保全局 CombatEventBus + CombatExecutor 存在
func _setup_event_bus() -> void:
	# CombatExecutor（唯一控制流入口，手动设 instance 绕过 add_child 时序限制）
	if not CombatExecutor.instance:
		var exec := CombatExecutor.new()
		exec.name = "CombatExecutor"
		CombatExecutor.instance = exec  # 立即可用，无需等待 _ready()
		get_tree().current_scene.add_child.call_deferred(exec)

	# CombatEventBus（事件广播，手动设 instance）
	if CombatEventBus.instance:
		return
	var bus := CombatEventBus.new()
	bus.name = "CombatEventBus"
	CombatEventBus.instance = bus  # 立即可用，订阅/发射无需等待场景树
	get_tree().current_scene.add_child.call_deferred(bus)
	print("📡 CombatEventBus + CombatExecutor 已创建")

	# ON_KILL 对敌人 → 额外经验（持有引用防止 Resource GC）
	_on_kill_effect = OnKillBonusExp.create_for_player(15)
	_register_triggered_effects(_on_kill_effect)

	# ON_STATUS_REMOVED 冰甲 → 冰爆
	_on_ice_expire = OnIceArmorExpire.create_default()
	_register_triggered_effects(_on_ice_expire)

	# EffectGraph：ON_HIT 火焰技能
	_register_graph_demo()

	# 战斗调试器
	_setup_combat_debugger()


func _register_triggered_effects(effect: TriggeredEffect) -> void:
	effect.register()
	print("⚡ 已注册触发效果: ", effect.get_script().get_global_name())


## 演示 EffectGraph：ON_HIT → 火焰技能分支
func _register_graph_demo() -> void:
	# 条件1: 技能必须是火焰标签
	var fire_cond := SkillTagCondition.new()
	fire_cond.required_skill_tag = "fire"

	# 条件2: 目标必须是 Boss
	var boss_cond := TargetTypeCondition.new()
	boss_cond.target_is_boss = true
	boss_cond.target_is_player = false
	boss_cond.target_is_enemy = true

	# 效果节点
	var boss_log := LogNode.new()
	boss_log.message = "🔥 Boss 被火焰命中！触发二段伤害！"
	boss_log.node_name = "BossFireHit"

	var normal_log := LogNode.new()
	normal_log.message = "🔥 火焰命中"
	normal_log.node_name = "NormalFireHit"

	# 分支: if FireSkill AND Boss → BossLog, else → NormalLog
	var fire_gate := ConditionGateNode.new()
	fire_gate.condition = fire_cond
	fire_gate.node_name = "Gate:IsFire"

	var boss_branch := BranchNode.new()
	boss_branch.condition = boss_cond
	boss_branch.true_branch = boss_log
	boss_branch.false_branch = normal_log
	boss_branch.node_name = "Branch:IsBoss"

	fire_gate.child = boss_branch

	# 构建图
	var graph := EffectGraph.new()
	graph.root = fire_gate

	# 创建 TriggeredEffect 包装（持有引用防止 Resource GC）
	_on_hit_effect = TriggeredEffect.new()
	_on_hit_effect.trigger_type = CombatEvent.Type.ON_HIT
	_on_hit_effect.graph = graph
	_on_hit_effect.scope_source = "skill"
	_on_hit_effect.max_recursion = 0

	call_deferred("_register_triggered_effects_deferred", _on_hit_effect)


func _register_triggered_effects_deferred(effect: TriggeredEffect) -> void:
	effect.register()
	print("🧠 已注册 EffectGraph: ", effect.graph.root.node_name if effect.graph else "(flat)")


## 战斗调试器：开启追踪 + 挂载Debug UI
func _setup_combat_debugger() -> void:
	# 开发模式下默认开启追踪
	if OS.is_debug_build():
		CombatDebugger.enabled = true
		print("📊 CombatDebugger: trace enabled")

	# 挂载 Debug UI（按 ~ 切换）
	var debug_ui := CombatDebugUI.new()
	debug_ui.name = "CombatDebugUI"
	get_tree().current_scene.add_child.call_deferred(debug_ui)


## ── 信号转发 ──

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_changed.emit(current_hp, max_hp)


func _on_died() -> void:
	set_process(false)
	set_physics_process(false)
	print("💀 玩家死亡！")
	died.emit()


func _on_skill_cooldown(_source: String, remaining: float, total: float) -> void:
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


## ── 瞄准指示器 ──

func _setup_aim_indicator() -> void:
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1, 1, 1, 0.5)
	_aim_line.z_index = 20
	_aim_line.visible = false
	add_child(_aim_line)

	_aim_dot = Sprite2D.new()
	_aim_dot.name = "AimDot"
	_aim_dot.texture = load("res://icon.svg")
	_aim_dot.scale = Vector2(0.08, 0.08)
	_aim_dot.modulate = Color(1, 1, 1, 0.6)
	_aim_dot.z_index = 20
	_aim_dot.visible = false
	add_child(_aim_dot)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and event.pressed:
			if aiming_sources.size() > 0:
				cancel_aim = true


func _process(_delta: float) -> void:
	if not _aim_dot or not _aim_dot.visible:
		return
	if _aim_line.visible:
		var dir := get_mouse_direction()
		_aim_line.points = PackedVector2Array([Vector2.ZERO, dir * _aim_distance])
		_aim_dot.global_position = global_position + dir * _aim_distance
	else:
		_aim_dot.global_position = global_position


func show_aim(_source: String, skill: SkillData) -> void:
	if not skill or not _aim_line or not _aim_dot:
		return

	var color := _aim_color(skill.skill_type)

	match skill.skill_type:
		SkillData.SkillType.BUFF:
			_aim_line.visible = false
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.5, 0.5)
			_aim_dot.visible = true

		SkillData.SkillType.AOE:
			_aim_distance = skill.cast_distance
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(skill.aoe_radius / 80.0, skill.aoe_radius / 80.0)
			_aim_dot.visible = true

		SkillData.SkillType.DASH:
			_aim_distance = skill.dash_distance
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.08, 0.08)
			_aim_dot.visible = true

		_:
			_aim_distance = 60.0
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.08, 0.08)
			_aim_dot.visible = true


func _aim_color(skill_type: int) -> Color:
	match skill_type:
		SkillData.SkillType.BUFF:       return Color(0.3, 0.7, 1.0, 0.5)
		SkillData.SkillType.AOE:        return Color(1.0, 0.3, 0.1, 0.6)
		SkillData.SkillType.DASH:       return Color(0.3, 1.0, 0.5, 0.6)
		SkillData.SkillType.PROJECTILE: return Color(1.0, 0.5, 0.2, 0.7)
	return Color.WHITE


func hide_aim() -> void:
	if _aim_line: _aim_line.visible = false
	if _aim_dot: _aim_dot.visible = false


## ── 公开 API ──

func get_mouse_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()


func perform_melee_attack() -> void:
	combat_component.perform_melee_attack()


## 释放左手或右手技能
func cast_hand(hand: String) -> bool:
	var ok := skill_manager.use_hand(hand, self, get_mouse_direction())
	if ok and animation_player.has_animation("skill"):
		animation_player.play("skill")
	return ok


## 释放快捷键槽位技能
func cast_slot(idx: int) -> bool:
	var ok := skill_manager.use_slot(idx, self, get_mouse_direction())
	if ok and animation_player.has_animation("skill"):
		animation_player.play("skill")
	return ok


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


func heal(amount: int) -> void:
	health_component.heal(amount)
