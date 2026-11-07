class_name Player
extends CharacterBody2D
var actor_context: ActorContext
var world_provider: Callable

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
@export var character_definition: ActorCharacterData

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
var ui_blocked: bool = false:
	set(value):
		if ui_blocked == value:
			return
		ui_blocked = value
		if value:
			cancel_active_input("打开菜单：动作取消")

## ── 运行时移动速度（基础 + 敏捷加成） ──
var move_speed: float = 300.0

## ── 状态机 ──
var casting: PlayerCastingController
var input_controller: PlayerInputController
var bindings: PlayerCombatBindings
var field_work: PlayerFieldWork
var survival: SurvivalService
var aiming_sources: Dictionary:
	get: return casting.aiming_sources if casting else {}
var state_machine: Node

func _enter_tree() -> void:
	InputBindings.install()

func _ready() -> void:
	if inventory: inventory=inventory.duplicate(true) as Inventory
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

	# Attributes share the same body definition/formula as authored NPCs.
	if character_definition: ActorCombatModel.initialize_body(self, character_definition)
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
	if character_definition:
		if not character_definition.skills.is_empty(): ActorCombatModel.configure_actions(self, character_definition)
		ActorCombatModel.configure_equipment(self, character_definition)
	ActorEquipmentVisual.install(self)

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
	if exploration_mode:
		field_work = PlayerFieldWork.new(self)
		add_child(field_work)
		var work_state := preload("res://entities/player/states/work.gd").new()
		work_state.name = "work"
		work_state.entity = self
		state_machine.add_child(work_state)
		state_machine.states["work"] = work_state

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
	ActorCombatModel.rebuild(self)

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

func restore_mp(amount: int, source := "skill") -> void:
	mana_component.restore_mp(amount, source)

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
	ActorCombatModel.setup_scaling(skill_manager)

## 场景级服务由Player装配，事件与熟练度绑定由PlayerCombatBindings管理。
var quest_manager: QuestManager = null
var summon_manager: SummonManager = null
var mastery_manager: SkillMasteryManager = null

## 输入意图与施法过程委托给PlayerInputController和PlayerCastingController。

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
	var panel = WorldScope.presentation(self).get_node_or_null("InventoryPanel")
	if not panel:
		var panel_scene = load("res://ui/inventory_panel.tscn") as PackedScene
		if panel_scene:
			panel = panel_scene.instantiate()
			panel.name = "InventoryPanel"
			WorldScope.presentation(self).add_child.call_deferred(panel)

	if panel and panel is InventoryPanel:
		inventory_panel = panel
		if not inventory:
			inventory = load("res://content/items/player_inventory.tres") as Inventory
		inventory_panel.setup(inventory, $EquipmentManager)
		if debug_items:
			_add_test_items()

func _setup_boss_bar() -> void:
	if WorldScope.presentation(self).get_node_or_null("BossHPBar"):
		return
	var bar := BossHPBar.new()
	bar.name = "BossHPBar"
	WorldScope.presentation(self).add_child.call_deferred(bar)

func _setup_skill_pool_ui() -> void:
	var ui := SkillPoolUI.new()
	skill_pool_ui=ui
	ui.name = "SkillPoolUI"
	WorldScope.presentation(self).add_child.call_deferred(ui)
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
	health_component.take_damage(ActorCombatModel.incoming_damage(self,amount))

func heal(amount: int, source := "skill") -> void:
	var equipment := get_node_or_null("EquipmentManager") as EquipmentManager
	var multiplier := 1.0 + (equipment.get_modifier_value("healing_received") if equipment else 0.0)
	health_component.heal(maxi(0, int(round(amount * multiplier))), source)

func cancel_active_input(reason: String) -> void:
	if casting:
		casting.cancel_all()
	if skill_manager and skill_manager.combinations:
		skill_manager.combinations.cancel(reason)
	if actor_context:
		if actor_context.actions:
			actor_context.actions.clear_input()
		if actor_context.item_actions:
			actor_context.item_actions.cancel()
		if actor_context.spray:
			actor_context.spray.stop()
	if field_work:
		field_work.cancel(reason)
		field_work.close_panel()


func cancel_region_actions() -> void:
	if actor_context and actor_context.actions: actor_context.actions.cancel("region_left")
	if actor_context and actor_context.item_actions: actor_context.item_actions.cancel()
	if actor_context and actor_context.spray: actor_context.spray.stop()
	skill_manager.combinations.supplies.clear_selection()
	if field_work:
		field_work.cancel("区域切换：作业取消")
		field_work.close_panel()
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
