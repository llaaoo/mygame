extends CharacterBody2D
class_name Player

const PLAYER_SKILL_IDS: Array[String] = [
	"fireball",
	"ice_armor",
	"flame_storm",
	"shadow_step",
	"ice_explosion",
	"poison_cloud",
	"lightning_bolt",
	"summon_skeleton",
	"charged_fireball",
	"ice_storm",
	"shadow_bolt",
	"frost_lance",
	"ember_orb",
	"storm_field",
	"venom_burst",
	"arcane_dash",
	"cinder_volley",
	"solar_spear",
	"magma_pool",
	"glacial_orb",
	"blizzard",
	"thunder_orb",
	"static_nova",
	"plague_bolt",
	"miasma_ring",
	"tidal_orb",
	"phase_blink",
	"summon_wisp",
	"summon_golem",
	"radiant_aegis",
]

## ── 移动基础值（最终速度 = 基础 + 敏捷加成） ──
@export var base_move_speed: float = 300.0

## ── 背包 ──
@export var inventory: Inventory
var inventory_panel: InventoryPanel
var skill_pool_ui: SkillPoolUI = null
var _skill_pool: SkillPool = null

## ── 调试 ──
@export var debug_items: bool = false
@export var exploration_mode: bool = false
@export_range(0.1, 2.0, 0.05) var melee_damage_multiplier := 1.0


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

## ── UI 面板打开时阻止游戏输入 ──
var ui_blocked: bool = false

## ── 运行时移动速度（基础 + 敏捷加成） ──
var move_speed: float = 300.0

## ── 状态机 ──
var casting: PlayerCastingController
var input_controller: PlayerInputController
var bindings: PlayerCombatBindings
var aiming_sources: Dictionary:
	get: return casting.aiming_sources if casting else {}
var cancel_aim: bool:
	get: return casting.cancel_aim if casting else false
	set(value):
		if casting:
			casting.cancel_aim = value
var state_machine: Node

func _enter_tree() -> void:
	# 必须在 _ready 之前注册，否则第一帧 _input 可能触发 Missing action 错误
	_register_interact_key()
	for i in range(4, SkillManager.MAX_SLOTS):
		var action_name := "skill_%d" % (i + 1)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var event := InputEventKey.new()
			event.physical_keycode = KEY_5 + i - 4
			InputMap.action_add_event(action_name, event)

func _ready() -> void:
	casting = PlayerCastingController.new(self)
	add_child(casting)
	input_controller = PlayerInputController.new(self)
	add_child(input_controller)
	bindings = PlayerCombatBindings.new(self)
	add_child(bindings)
	add_to_group("player")

	# 身体碰撞形状
	collision_shape.shape = load("res://entities/player/player_shape.tres")

	# MP 组件（先创建，_apply_stats 依赖它）
	if not mana_component:
		_create_mana_component()
	mana_component.mp_changed.connect(_on_mp_changed)

	# 属性系统
	_apply_stats()
	stats_component.stat_changed.connect(_on_stat_changed)

	# 攻击盒碰撞层（设为 HITBOX 以便 MapObject 的 HitArea 可检测）
	attack_hitbox.collision_layer = 4  # HITBOX

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
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(0.24, 0.24)
	sprite.z_as_relative = false
	sprite.z_index = 10

	# 召唤物管理器
	_setup_summon_manager()

	# 背包面板
	call_deferred("_setup_inventory_panel")

	# 技能池面板
	call_deferred("_setup_skill_pool_ui")

	# Boss 血条
	call_deferred("_setup_boss_bar")

## ── 属性系统 ──

func _apply_stats() -> void:
	stats_component._recalculate_all()
	var buffs := get_node("BuffManager") as BuffManager
	buffs.set_base_attributes({"max_hp": 50 + stats_component.max_hp_bonus, "max_mana": stats_component.max_mana, "attack_damage": roundi((10 + stats_component.physical_damage) * melee_damage_multiplier), "move_speed": base_move_speed + stats_component.move_speed_bonus})
	health_component.hp = clampi(health_component.hp, 0 if health_component.is_dead else 1, health_component.max_hp)
	mana_component.mp = clampi(mana_component.mp, 0, mana_component.max_mp)

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
	var pool_template := load("res://gameplay/abilities/registry/player_skill_pool.tres") as SkillPool
	_skill_pool = pool_template.duplicate(true) as SkillPool if pool_template else SkillPool.new()
	_skill_pool.build()
	for skill_id in PLAYER_SKILL_IDS:
		if _skill_pool.has_skill(skill_id):
			continue
		var skill := load("res://gameplay/abilities/data/%s_data.tres" % skill_id) as SkillData
		if skill:
			_skill_pool.add_skill(skill)

	# 3. 构建索引
	_skill_pool.build()

	# 4. 注入 pool 到 skill_manager（供 loadout 使用）
	for action_id in ["fire_sigil", "ignite"]:
		_skill_pool.add_skill(load("res://gameplay/abilities/data/%s_data.tres" % action_id) as SkillData)
	skill_manager.pool = _skill_pool

	# 5. 应用装备映射表
	var loadout := SkillLoadout.create(
		"ice_armor",    # 左手
		"ignite",       # 右手基础火花；火球由火阵组合产生
		["lightning_bolt", "poison_cloud", "frost_lance", "shadow_bolt", "fire_sigil", "ignite"]
	)
	skill_manager.apply_loadout(loadout)
	if exploration_mode:
		skill_manager.restrict_actions = true
		skill_manager.known_actions = {"ignite": true}
		skill_manager.unequip_hand("left")
		for i in range(SkillManager.MAX_SLOTS):
			skill_manager.unequip_slot(i)
		skill_manager.equip_slot(5, _skill_pool.get_skill("ignite"))
		skill_manager.combinations.learned_rules.clear()

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

## 场景级服务由Player装配，事件与熟练度绑定由PlayerCombatBindings管理。
var quest_manager: QuestManager = null
var summon_manager: SummonManager = null
var mastery_manager: SkillMasteryManager = null

## 输入意图与施法过程委托给PlayerInputController和PlayerCastingController。

## ── 交互键 ──

func _register_interact_key() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event := InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("interact", event)

## ── 信号转发 ──

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_changed.emit(current_hp, max_hp)

func _on_died() -> void:
	set_process(false)
	set_physics_process(false)
	# 清理所有召唤物
	if summon_manager:
		summon_manager.clear_all()
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

## ── 召唤物管理器 ──

## ── 技能熟练度系统 ──

func _setup_summon_manager() -> void:
	if has_node("SummonManager"):
		summon_manager = $SummonManager as SummonManager
		return
	var sm := SummonManager.new()
	sm.name = "SummonManager"
	add_child(sm)
	summon_manager = sm

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
			inventory = load("res://content/items/player_inventory.tres") as Inventory
		inventory_panel.setup(inventory, $EquipmentManager)
		if debug_items:
			_add_test_items()

func _setup_boss_bar() -> void:
	if get_tree().current_scene.get_node_or_null("BossHPBar"):
		return
	var bar := BossHPBar.new()
	bar.name = "BossHPBar"
	get_tree().current_scene.add_child.call_deferred(bar)

func _setup_skill_pool_ui() -> void:
	var ui := SkillPoolUI.new()
	ui.name = "SkillPoolUI"
	get_tree().current_scene.add_child.call_deferred(ui)
	ui.setup(_skill_pool, skill_manager)

func _add_test_items() -> void:
	if not inventory:
		return
	var showcase_ids: Array[String] = [
		"vanguard_helmet", "vanguard_cuirass", "vanguard_greaves",
		"vanguard_gauntlets", "vanguard_shield", "cinder_staff",
		"cinder_amulet", "night_blade", "night_ring", "chronoglass",
	]
	for item_id in showcase_ids:
		var item := EquipmentCatalog.get_by_id(item_id)
		if item and inventory.get_item_count(item) == 0:
			inventory.add_item(item)
	print("🎒 装备展示内容已添加到背包")


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
	var equipment := get_node_or_null("EquipmentManager") as EquipmentManager
	var reduction := clampf(equipment.get_modifier_value("damage_reduction"), 0.0, 0.75) if equipment else 0.0
	health_component.take_damage(maxi(1, int(round(amount * (1.0 - reduction)))))

func heal(amount: int) -> void:
	var equipment := get_node_or_null("EquipmentManager") as EquipmentManager
	var multiplier := 1.0 + (equipment.get_modifier_value("healing_received") if equipment else 0.0)
	health_component.heal(maxi(0, int(round(amount * multiplier))))

func cancel_region_actions() -> void:
	skill_manager.combinations.cancel("区域切换")
	skill_manager.combinations.clear_field()
	skill_manager.executor.cancel_pending_effects()
	casting.cancel_all()
	if summon_manager:
		summon_manager.clear_all()
	get_node("BuffManager").clear_temporary()

func _setup_event_bus() -> void:
	bindings.call_deferred("_setup_event_bus")

func _rebuild_perk_triggers() -> void:
	bindings._rebuild_perk_triggers()

func _setup_aim_indicator() -> void:
	casting._setup_aim_indicator()

func poll_universal_actions() -> Array[Action]:
	return input_controller.poll_universal_actions()

func _poll_universal_cast(actions: Array[Action], source: String, input_action: String) -> void:
	input_controller._poll_universal_cast(actions, source, input_action)

func resolve_action(action: Action) -> void:
	input_controller.resolve_action(action)

func _get_skill_for_source(source: String) -> SkillData:
	return input_controller._get_skill_for_source(source)

func _cast_source(source: String, context: CastContext = null) -> void:
	input_controller._cast_source(source, context)

func _cancel_charge() -> void:
	casting._cancel_charge()

func _cancel_channel() -> void:
	casting._cancel_channel()

func cast_hand_charged(hand: String, charge_power: float) -> bool:
	return casting.cast_hand_charged(hand, charge_power)

func cast_slot_charged(idx: int, charge_power: float) -> bool:
	return casting.cast_slot_charged(idx, charge_power)

func show_aim(_source: String, skill: SkillData) -> void:
	casting.show_aim(_source, skill)

func hide_aim() -> void:
	casting.hide_aim()

func _try_interact() -> void:
	input_controller._try_interact()
