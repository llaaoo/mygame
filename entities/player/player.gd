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
var _on_buff_expire_cast: GenericTriggeredCast = null  ## 通用：Buff过期→释放技能
var _on_kill_fire_trigger: GenericTriggeredCast = null  ## 火系击杀→烈焰风暴

var _on_hit_fire_status: OnHitApplyStatus = null  ## 持有引用防 GC
var _on_hit_ice_status: OnHitApplyStatus = null   ## 冰→冻结
var _on_hit_poison_status: OnHitApplyStatus = null  ## 毒→中毒
var _on_hit_chain: OnHitChain = null                ## 闪电→连锁

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

## ── 瞄准状态（跨状态保持） ──
var aiming_sources: Dictionary = {}
var cancel_aim: bool = false
## ── 蓄力状态 ──
var _charging_source: String = ""       ## 正在蓄力的槽位
var _charge_power: float = 0.0          ## 当前蓄力倍率
var _charge_skill: SkillData = null     ## 正在蓄力的技能数据
## ── 引导状态 ──
var _channeling_source: String = ""     ## 正在引导的槽位
var _channel_skill: SkillData = null    ## 正在引导的技能
var _channel_timer: float = 0.0         ## tick 累加器
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


func _enter_tree() -> void:
	# 必须在 _ready 之前注册，否则第一帧 _input 可能触发 Missing action 错误
	_register_interact_key()


func _ready() -> void:
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
		sprite.scale = Vector2(0.5, 0.5)
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
	_skill_pool = load("res://gameplay/abilities/registry/player_skill_pool.tres") as SkillPool
	if not _skill_pool:
		_skill_pool = SkillPool.new()

	# 2. 确保所有技能在池中（纯数据，archetype 驱动场景加载）
	if not _skill_pool.has_skill("fireball"):
		var fireball := load("res://gameplay/abilities/data/fireball_data.tres") as SkillData
		if fireball:
			fireball.archetype = "linear_projectile"
			fireball.visual = load("res://content/visuals/fire_visual.tres")
			fireball.projectile_speed = 500.0
			fireball.damage = 25
			fireball.damage_scaling = 1.0
			fireball.mp_cost = 15
			fireball.skill_type = SkillData.SkillType.PROJECTILE
			fireball.tags = ["fire"]
			_skill_pool.add_skill(fireball)

	for sid in ["ice_armor", "flame_storm", "shadow_step", "ice_explosion", "poison_cloud", "lightning_bolt", "summon_skeleton", "charged_fireball", "ice_storm"]:
		if not _skill_pool.has_skill(sid):
			var skill := load("res://gameplay/abilities/data/%s_data.tres" % sid) as SkillData
			if skill:
				match sid:
					"ice_armor":
						skill.buff_resource = load("res://gameplay/abilities/data/ice_armor_buff.tres") as Buff
						skill.tags = ["ice"]
					"flame_storm":
						skill.archetype = "persistent_aoe"
						skill.aoe_visual = load("res://content/visuals/fire_aoe_visual.tres")
						skill.cast_distance = 150.0
						skill.damage = 30
						skill.damage_scaling = 1.2
						skill.tags = ["fire"]
					"shadow_step":
						skill.buff_resource = load("res://gameplay/abilities/data/shadow_step_buff.tres") as Buff
						skill.tags = ["shadow"]
					"ice_explosion":
						skill.archetype = "persistent_aoe"
						skill.aoe_visual = load("res://content/visuals/ice_aoe_visual.tres")
						skill.damage = 25
						skill.damage_scaling = 0.8
						skill.mp_cost = 20
						skill.cooldown = 8.0
						skill.tags = ["ice", "aoe"]
					"poison_cloud":
						skill.archetype = "persistent_aoe"
						skill.aoe_visual = load("res://content/visuals/poison_aoe_visual.tres")
						skill.cast_distance = 200.0
						skill.damage = 15
						skill.damage_scaling = 0.6
						skill.mp_cost = 25
						skill.cooldown = 6.0
						skill.tags = ["poison"]
					"lightning_bolt":
						skill.archetype = "linear_projectile"
						skill.visual = load("res://content/visuals/lightning_visual.tres")
						skill.projectile_speed = 600.0
						skill.damage = 35
						skill.damage_scaling = 1.2
						skill.mp_cost = 15
						skill.cooldown = 3.0
						skill.tags = ["lightning"]
					"summon_skeleton":
						skill.archetype = "summon_entity"
						skill.summon_data = load("res://content/summons/skeleton_warrior.tres") as SummonData
						skill.mp_cost = 30
						skill.cooldown = 8.0
						skill.damage = 0
						skill.damage_scaling = 0.0
						skill.tags = ["summon", "shadow"]
					"charged_fireball":
						skill.archetype = "linear_projectile"
						skill.visual = load("res://content/visuals/fire_visual.tres")
						skill.projectile_speed = 600.0
						skill.damage = 40
						skill.damage_scaling = 1.2
						skill.mp_cost = 20
						skill.cooldown = 3.0
						skill.cast_type = "charge"
						skill.charge_duration = 1.2
						skill.tags = ["fire", "charge"]
					"ice_storm":
						skill.archetype = "persistent_aoe"
						skill.aoe_visual = load("res://content/visuals/ice_aoe_visual.tres")
						skill.cast_distance = 200.0
						skill.damage = 12
						skill.damage_scaling = 0.4
						skill.mp_cost = 0
						skill.cooldown = 0.0
						skill.cast_type = "channel"
						skill.channel_mp_per_sec = 15.0
						skill.channel_tick_interval = 0.4
						skill.aoe_radius = 60.0
						skill.aoe_lifetime = 0.3
						skill.tags = ["ice", "channel"]
				_skill_pool.add_skill(skill)

	# 3. 构建索引
	_skill_pool.build()

	# 4. 注入 pool 到 skill_manager（供 loadout 使用）
	skill_manager.pool = _skill_pool

	# 5. 应用装备映射表
	var loadout := SkillLoadout.create(
		"ice_armor",    # 左手
		"fireball",     # 右手
		["flame_storm", "ice_storm", "ice_explosion", "charged_fireball"]  # 快捷键 1-4
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
## CombatExecutor / CombatEventBus / WorldTime 现在由 GameRuntime 统一管理
## Player 只做自己的 TriggeredEffect 注册 + CombatDebugger + QuestManager
func _setup_event_bus() -> void:
	# 等待 GameRuntime 初始化完成（它负责创建 CombatExecutor / CombatEventBus / WorldTime）
	# ⚠️ 必须 await，否则 _ensure_runtime_ready 内部 yield 后后续代码立即执行，
	# 此时 CombatEventBus.instance 为 null，subscribe_static 静默失败
	await _ensure_runtime_ready()

	# ON_KILL 对敌人 → 额外经验（持有引用防止 Resource GC）
	_on_kill_effect = OnKillBonusExp.create_for_player(15)
	_register_triggered_effects(_on_kill_effect)

	# 低血量触发器（配置化，DEFAULT_LOW_HP_TRIGGERS 可扩展）
	_setup_low_hp_triggers()
	health_component.health_changed.connect(_check_low_hp_shadow_step)

	# 技能熟练度系统（上古卷轴式）
	_setup_mastery()

	# ON_HIT 火焰技能 → 挂 burning 状态
	_on_hit_fire_status = OnHitApplyStatus.create("fire", "res://gameplay/abilities/data/burning.tres")
	_register_triggered_effects(_on_hit_fire_status)

	# ON_HIT 冰霜技能 → 挂 frozen 减速
	_on_hit_ice_status = OnHitApplyStatus.create("ice", "res://gameplay/abilities/data/frozen.tres")
	_register_triggered_effects(_on_hit_ice_status)

	# ON_HIT 毒素技能 → 挂 poison DOT
	_on_hit_poison_status = OnHitApplyStatus.create("poison", "res://gameplay/abilities/data/poison.tres")
	_register_triggered_effects(_on_hit_poison_status)

	# ON_HIT 闪电技能 → 连锁弹射
	_on_hit_chain = OnHitChain.create("lightning", 120.0, 3, 0.6)
	_register_triggered_effects(_on_hit_chain)

	# EffectGraph：ON_HIT 火焰技能
	_register_graph_demo()

	# 战斗调试器
	_setup_combat_debugger()

	# QuestManager（接在 EventBus 之后）
	_setup_quest_manager()


## 确保 GameRuntime 已初始化（CombatExecutor / CombatEventBus 可用）
func _ensure_runtime_ready() -> void:
	var gr := GameRuntime.instance
	if not gr:
		# GameRuntime 还未初始化，等待一帧
		await get_tree().process_frame
		_ensure_runtime_ready()
		return

	# 如果 CombatExecutor 仍不可用，等待
	if not CombatExecutor.instance:
		await get_tree().process_frame
		_ensure_runtime_ready()
		return

	if not CombatEventBus.instance:
		await get_tree().process_frame
		_ensure_runtime_ready()
		return

	print("📡 GameRuntime 就绪: CombatExecutor=%s, CombatEventBus=%s" % [
		"✅" if CombatExecutor.instance else "❌",
		"✅" if CombatEventBus.instance else "❌"
	])


func _register_triggered_effects(effect: TriggeredEffect) -> void:
	effect.register()
	print("⚡ 已注册触发效果: ", effect.get_script().get_global_name())


## ── 通用触发施法 工厂方法 ──

## 冰霜护盾过期 → 冰爆
func _create_buff_expire_trigger() -> GenericTriggeredCast:
	var trigger := GenericTriggeredCast.new()
	trigger.trigger_type = CombatEvent.Type.ON_STATUS_REMOVED
	trigger.scope_source = "skill"
	trigger.max_recursion = 0
	trigger.cast_skill_id = "ice_explosion"
	trigger.caster_mode = GenericTriggeredCast.CasterMode.SELF
	trigger.target_mode = GenericTriggeredCast.TargetMode.CASTER_POSITION
	trigger.consume_mp = false

	var cond := BuffNameCondition.new()
	cond.required_buff_name = "冰霜护盾"
	trigger.conditions = [cond]

	return trigger


## 低血量触发器（配置化 — 读取 LowHpTriggerData 列表）
var _low_hp_triggers: Array[LowHpTriggerData] = []
var _low_hp_cooldowns: Dictionary = {}  ## trigger → 剩余冷却秒数

const DEFAULT_LOW_HP_TRIGGERS: Array = [
	# hp_threshold, skill_id, target_mode, cooldown
	[0.3, "shadow_step", 5, 15.0],  # 5 = TargetMode.ESCAPE
]

func _setup_low_hp_triggers() -> void:
	for raw in DEFAULT_LOW_HP_TRIGGERS:
		var t := LowHpTriggerData.new()
		t.hp_threshold = raw[0]
		t.cast_skill_id = raw[1]
		t.target_mode = raw[2]
		t.cooldown = raw[3]
		_low_hp_triggers.append(t)
		_low_hp_cooldowns[t] = 0.0

func _check_low_hp_shadow_step(_current_hp: int, max_hp: int) -> void:
	if health_component.is_dead:
		return
	var ratio := float(health_component.hp) / float(max_hp)
	for trigger in _low_hp_triggers:
		var cd: float = _low_hp_cooldowns.get(trigger, 0.0)
		if cd > 0:
			continue
		if ratio >= trigger.hp_threshold:
			continue
		# 触发！
		_low_hp_cooldowns[trigger] = trigger.cooldown

		var gtc := GenericTriggeredCast.new()
		gtc.cast_skill_id = trigger.cast_skill_id
		gtc.caster_mode = GenericTriggeredCast.CasterMode.PLAYER
		gtc.target_mode = trigger.target_mode
		gtc.consume_mp = false

		# 构造一个虚拟 ON_DAMAGE 事件触发
		var ev := CombatEvent.create(CombatEvent.Type.ON_DAMAGE, null, self)
		gtc._execute(ev)
		print("🆘 [LowHP] 血量 %.0f%% → %s！" % [ratio * 100, trigger.cast_skill_id])


## 通用模板：事件+标签→技能（复制此模板创建新触发器）
func _create_generic_trigger(event_type: CombatEvent.Type, required_tag: String, skill_id: String) -> GenericTriggeredCast:
	var trigger := GenericTriggeredCast.new()
	trigger.trigger_type = event_type
	trigger.scope_source = "skill"
	trigger.max_recursion = 0
	trigger.cast_skill_id = skill_id
	trigger.caster_mode = GenericTriggeredCast.CasterMode.PLAYER
	trigger.target_mode = GenericTriggeredCast.TargetMode.EVENT_TARGET
	trigger.consume_mp = false

	var cond := SkillTagCondition.new()
	cond.required_skill_tag = required_tag
	trigger.conditions = [cond]

	return trigger


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


## ── Quest 系统 ──
## WorldTime 现在由 GameRuntime 统一管理，Player 不再创建

var quest_manager: QuestManager = null
var summon_manager: SummonManager = null
var mastery_manager: SkillMasteryManager = null


func _setup_quest_manager() -> void:
	if quest_manager:
		return
	quest_manager = QuestManager.new()
	quest_manager.name = "QuestManager"
	get_tree().current_scene.add_child.call_deferred(quest_manager)

	# 任务追踪 UI
	var tracker := QuestTracker.new()
	tracker.name = "QuestTracker"
	get_tree().current_scene.add_child.call_deferred(tracker)
	call_deferred("_setup_quest_tracker", tracker)


func _setup_quest_tracker(tracker: QuestTracker) -> void:
	tracker.setup(quest_manager)


func _tag_quest_objects() -> void:
	# 给场景中的 NPC 和 Chest 加 quest 标签
	for node in get_tree().get_nodes_in_group("interactable"):
		if node.is_in_group("villager") or node.is_in_group("chest"):
			continue
		if node.name.begins_with("NPC"):
			node.add_to_group("villager")
		elif node.name.begins_with("Chest"):
			node.add_to_group("chest")


## ── Action Layer ── 统一输入 → 意图 → 执行 ──
##
## 双轨过渡:
##   poll_actions()          → PlayerAction (旧, @deprecated)
##   poll_universal_actions() → Action      (新, Player/NPC/Enemy 统一)
##   try_action()            → PlayerAction (旧)
##   resolve_action()        → Action      (新)

const INTERACT_RANGE: float = 80.0


## ── 新 API: 通用 Action ──

## 每帧产生通用 Action 列表（Player/NPC/Enemy/Boss 共享此类型）
func poll_universal_actions() -> Array[Action]:
	if ui_blocked or health_component.is_dead:
		return []

	var actions: Array[Action] = []

	# 移动
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.05:
		actions.append(Action.move(input_dir, self))

	# 闪避
	if Input.is_action_just_pressed("dodge"):
		actions.append(Action.dodge(input_dir if input_dir.length() > 0.1 else facing_direction, self))

	# 近战（左键 = 无左手技能时直接近战）
	if Input.is_action_just_pressed("attack") and not skill_manager.has_left_spell():
		actions.append(Action.melee(self))

	# 技能（左手/右手/快捷键1-4）
	for pair in [["left", "attack"], ["right", "skill"]]:
		_poll_universal_cast(actions, pair[0], pair[1])
	for i in range(4):
		_poll_universal_cast(actions, "slot_%d" % i, "skill_%d" % (i + 1))

	# 交互
	if Input.is_action_just_pressed("interact"):
		actions.append(Action.interact(self))

	return actions


func _poll_universal_cast(actions: Array[Action], source: String, input_action: String) -> void:
	if not _can_cast_source(source):
		return
	if Input.is_action_just_pressed(input_action):
		var a := Action.cast(source, get_mouse_direction(), self)
		a.skill_source = source  # CAST_PRESS
		actions.append(a)
	elif Input.is_action_just_released(input_action):
		var a := Action.cast(source, get_mouse_direction(), self)
		a.skill_source = source
		a.params["release"] = true  # CAST_RELEASE
		actions.append(a)


## 通用 Action 路由（替代 try_action）
## 执行前统一通过 ActionResolver 验证
func resolve_action(action: Action) -> void:
	# 统一验证（CAST 的验证在 CAST_RELEASE 分支内单独处理，CAST_PRESS 不验证）
	if action.action_type != Action.ActionType.CAST:
		if not ActionResolver.validate(self, action):
			return

	match action.action_type:
		Action.ActionType.MELEE:
			aiming_sources.clear()
			hide_aim()
			state_machine.transition_to("attack")

		Action.ActionType.DODGE:
			_cancel_charge()
			_cancel_channel()
			aiming_sources.clear()
			hide_aim()
			state_machine.transition_to("dodge")

		Action.ActionType.INTERACT:
			_try_interact()

		Action.ActionType.CAST:
			if action.params.get("release", false):
				# CAST_RELEASE — 验证后才执行
				if _charging_source != "":
					# 蓄力释放：取消蓄力，正常施放
					aiming_sources.erase(action.skill_source)
					_cast_source(action.skill_source)
					state_machine.transition_to("skill")
					if aiming_sources.is_empty():
						hide_aim()
					return
				if _channeling_source != "":
					# 引导松开：停止引导
					_cancel_channel()
					aiming_sources.erase(action.skill_source)
					if aiming_sources.is_empty():
						hide_aim()
					return
				if not ActionResolver.validate(self, action):
					# MP/冷却不足，清除瞄准但不执行
					aiming_sources.erase(action.skill_source)
					if aiming_sources.is_empty():
						hide_aim()
					return
				if aiming_sources.has(action.skill_source):
					aiming_sources.erase(action.skill_source)
					_cast_source(action.skill_source)
					state_machine.transition_to("skill")
				if aiming_sources.is_empty():
					hide_aim()
			else:
				# CAST_PRESS — 总是显示瞄准
				aiming_sources[action.skill_source] = true
				var skill := _get_skill_for_source(action.skill_source)
				if skill:
					# 蓄力技能：进入蓄力状态
					if skill.cast_type == "charge":
						_begin_charge(action.skill_source, skill)
					# 引导技能：进入引导状态
					elif skill.cast_type == "channel":
						_begin_channel(action.skill_source, skill)
					else:
						show_aim(action.skill_source, skill)


## ── 旧 API: PlayerAction (@deprecated, 保留向后兼容) ──

## 每帧从原始 Input 产生 Action 列表（供各 State 调用）
func poll_actions() -> Array[PlayerAction]:
	if ui_blocked or health_component.is_dead:
		return []

	var actions: Array[PlayerAction] = []

	# 移动
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.05:
		var a := PlayerAction.new()
		a.type = PlayerAction.Type.MOVE
		a.direction = input_dir
		actions.append(a)

	# 闪避
	if Input.is_action_just_pressed("dodge"):
		var a := PlayerAction.new()
		a.type = PlayerAction.Type.DODGE
		actions.append(a)

	# 近战（左键 = 无左手技能时直接近战）
	if Input.is_action_just_pressed("attack") and not skill_manager.has_left_spell():
		var a := PlayerAction.new()
		a.type = PlayerAction.Type.MELEE
		actions.append(a)

	# 技能按下/释放（左手/右手/快捷键1-4）
	for pair in [["left", "attack"], ["right", "skill"]]:
		_poll_skill_action(actions, pair[0], pair[1])
	for i in range(4):
		_poll_skill_action(actions, "slot_%d" % i, "skill_%d" % (i + 1))

	# 交互
	if Input.is_action_just_pressed("interact"):
		var a := PlayerAction.new()
		a.type = PlayerAction.Type.INTERACT
		actions.append(a)

	return actions


func _poll_skill_action(actions: Array[PlayerAction], source: String, input_action: String) -> void:
	if not _can_cast_source(source):
		return

	if Input.is_action_just_pressed(input_action):
		var a := PlayerAction.new()
		a.type = PlayerAction.Type.CAST_PRESS
		a.skill_source = source
		actions.append(a)
	elif Input.is_action_just_released(input_action):
		var a := PlayerAction.new()
		a.type = PlayerAction.Type.CAST_RELEASE
		a.skill_source = source
		actions.append(a)


## 尝试执行单个 Action（验证 + 路由）
func try_action(action: PlayerAction) -> void:
	match action.type:
		PlayerAction.Type.MELEE:
			aiming_sources.clear()
			hide_aim()
			state_machine.transition_to("attack")

		PlayerAction.Type.DODGE:
			state_machine.transition_to("dodge")

		PlayerAction.Type.INTERACT:
			_try_interact()

		PlayerAction.Type.CAST_PRESS:
			aiming_sources[action.skill_source] = true
			var skill := _get_skill_for_source(action.skill_source)
			if skill:
				show_aim(action.skill_source, skill)

		PlayerAction.Type.CAST_RELEASE:
			if aiming_sources.has(action.skill_source):
				aiming_sources.erase(action.skill_source)
				_cast_source(action.skill_source)
				state_machine.transition_to("skill")
			if aiming_sources.is_empty():
				hide_aim()


## 技能查找/施放辅助

func _can_cast_source(source: String) -> bool:
	match source:
		"left":  return skill_manager.has_left_spell()
		"right": return skill_manager.has_right_spell()
		_:
			var idx := source.trim_prefix("slot_").to_int()
			var inst: SkillInstance = skill_manager.get_slot(idx)
			return inst != null and inst.data != null


func _get_skill_for_source(source: String) -> SkillData:
	var sm = skill_manager
	match source:
		"left":  return sm.left_hand.data if sm.left_hand else null
		"right": return sm.right_hand.data if sm.right_hand else null
		_:
			var inst: SkillInstance = sm.get_slot(source.trim_prefix("slot_").to_int())
			return inst.data if inst else null


func _cast_source(source: String) -> void:
	# 蓄力技能释放时传递 charge_power
	if _charge_skill and _charge_source_matches(source):
		var charge := _charge_power
		_cancel_charge()
		match source:
			"left", "right":
				cast_hand_charged(source, charge)
			_:
				cast_slot_charged(source.trim_prefix("slot_").to_int(), charge)
		return
	match source:
		"left", "right":
			cast_hand(source)
		_:
			cast_slot(source.trim_prefix("slot_").to_int())


func _charge_source_matches(source: String) -> bool:
	return source == _charging_source or (
		_charging_source.begins_with("slot_") and source.begins_with("slot_") and
		_charging_source.trim_prefix("slot_").to_int() == source.trim_prefix("slot_").to_int())


## ── 蓄力系统 ──

func _begin_charge(source: String, skill: SkillData) -> void:
	_charging_source = source
	_charge_skill = skill
	_charge_power = 0.0
	show_aim(source, skill)
	print("⏳ [Charge] 开始蓄力: %s (%.1fs 满蓄)" % [skill.display_name, skill.charge_duration])


func _cancel_charge() -> void:
	if _charging_source != "":
		print("⏹️ [Charge] 取消蓄力: %s" % _charge_skill.display_name if _charge_skill else "?")
	_charging_source = ""
	_charge_skill = null
	_charge_power = 0.0


## ── 引导系统 ──

func _begin_channel(source: String, skill: SkillData) -> void:
	_channeling_source = source
	_channel_skill = skill
	_channel_timer = 0.0
	show_aim(source, skill)
	print("🌀 [Channel] 开始引导: %s (MP %.0f/s)" % [skill.display_name, skill.channel_mp_per_sec])


func _cancel_channel() -> void:
	if _channeling_source != "":
		print("⏹️ [Channel] 停止引导: %s" % _channel_skill.display_name if _channel_skill else "?")
	_channeling_source = ""
	_channel_skill = null
	_channel_timer = 0.0


func _channel_tick() -> void:
	if not _channel_skill:
		return
	# 引导每次 tick 直接释放技能（不经过冷却/蓄力逻辑）
	var ctx := CastContext.simple(self, get_mouse_direction(), _channel_skill)
	ctx.charge_power = 1.0
	skill_manager.executor.execute(_channel_skill, ctx)


func cast_hand_charged(hand: String, charge_power: float) -> bool:
	var ctx := CastContext.simple(self, get_mouse_direction(), _get_skill_for_source(hand))
	ctx.charge_power = charge_power
	return skill_manager.use_hand_with_context(hand, self, ctx)


func cast_slot_charged(idx: int, charge_power: float) -> bool:
	var ctx := CastContext.simple(self, get_mouse_direction(), _get_skill_for_source("slot_%d" % idx))
	ctx.charge_power = charge_power
	return skill_manager.use_slot_with_context(idx, self, ctx)


## ── 交互键 ──

func _register_interact_key() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event := InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("interact", event)


func _try_interact() -> void:
	var balloon := DialogueBalloon.active
	if balloon != null and is_instance_valid(balloon) and balloon.has_method("advance"):
		balloon.advance()
		get_viewport().set_input_as_handled()
		return
	if DialogueBalloon.just_closed_frame == Engine.get_process_frames():
		get_viewport().set_input_as_handled()
		return

	var nearest: Node2D = null
	var nearest_dist: float = INTERACT_RANGE

	for node in get_tree().get_nodes_in_group("interactable"):
		var target := node as Node2D
		if not target:
			continue
		var dist := global_position.distance_to(target.global_position)
		if dist < nearest_dist:
			nearest = target
			nearest_dist = dist

	if nearest:
		var interactable := nearest.get_node_or_null("Interactable") as Interactable
		if interactable:
			interactable.interact(self)
			# 发射交互事件（供 Quest 等系统监听）
			if CombatEventBus.instance:
				var ev := CombatEvent.create(CombatEvent.Type.ON_INTERACT, self, nearest)
				CombatEventBus.instance.emit(ev)


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

func _setup_mastery() -> void:
	mastery_manager = SkillMasteryManager.new()
	mastery_manager.name = "MasteryManager"
	add_child(mastery_manager)
	mastery_manager.setup(self)
	mastery_manager.perk_unlocked.connect(_on_perk_unlocked)

	# 施法时加 XP
	skill_manager.skill_used.connect(_on_skill_used_for_mastery)

	# 命中时加 XP（按伤害）
	if CombatEventBus.instance:
		CombatEventBus.instance.subscribe(CombatEvent.Type.ON_HIT, _on_player_hit_for_mastery)
		CombatEventBus.instance.subscribe(CombatEvent.Type.ON_KILL, _on_player_kill_for_mastery)
	_rebuild_perk_triggers()


func _rebuild_perk_triggers() -> void:
	if not mastery_manager:
		return
	if _on_buff_expire_cast:
		_on_buff_expire_cast.unregister()
		_on_buff_expire_cast = null
	if _on_kill_fire_trigger:
		_on_kill_fire_trigger.unregister()
		_on_kill_fire_trigger = null
	for perk in mastery_manager.get_unlocked_trigger_perks():
		var trigger := mastery_manager.build_trigger_effect(perk)
		if not trigger:
			continue
		match perk.perk_id:
			"alteration_shatter":
				_on_buff_expire_cast = trigger
			"destruction_firestorm":
				_on_kill_fire_trigger = trigger
			_:
				pass
		_register_triggered_effects(trigger)


func _on_perk_unlocked(_school: int, perk_id: String) -> void:
	if not mastery_manager:
		return
	var perk := mastery_manager.get_perk(perk_id)
	if not perk:
		return
	var trigger := mastery_manager.build_trigger_effect(perk)
	if trigger:
		match perk.perk_id:
			"alteration_shatter":
				_on_buff_expire_cast = trigger
			"destruction_firestorm":
				_on_kill_fire_trigger = trigger
			_:
				pass
		_register_triggered_effects(trigger)


func _on_skill_used_for_mastery(_source: String, skill: SkillData) -> void:
	if mastery_manager:
		mastery_manager.on_skill_cast(skill)


func _on_player_hit_for_mastery(ev: CombatEvent) -> void:
	if ev.source != self:
		return
	if not mastery_manager:
		return
	var school := SkillMastery.School.DESTRUCTION
	if ev.skill:
		school = _guess_school_from_skill(ev.skill)
	elif ev.data.has("tags"):
		var tags: Array = ev.data.get("tags", []) as Array
		if "summon" in tags:
			school = SkillMastery.School.CONJURATION
		elif "shadow" in tags:
			school = SkillMastery.School.ILLUSION
	var damage: int = ev.data.get("damage", 0)
	if damage > 0:
		mastery_manager.on_deal_damage(school, damage)


func _on_player_kill_for_mastery(ev: CombatEvent) -> void:
	if ev.source != self:
		return
	if not mastery_manager:
		return
	var school := SkillMastery.School.DESTRUCTION
	if ev.skill:
		school = _guess_school_from_skill(ev.skill)
	elif ev.data.has("tags"):
		var tags: Array = ev.data.get("tags", []) as Array
		if "summon" in tags:
			school = SkillMastery.School.CONJURATION
		elif "shadow" in tags:
			school = SkillMastery.School.ILLUSION
	mastery_manager.on_kill(school)


func _guess_school_from_skill(skill: SkillData) -> SkillMastery.School:
	var tags := skill.tags
	if "summon" in tags:
		return SkillMastery.School.CONJURATION
	if "ice" in tags and skill.skill_type == SkillData.SkillType.BUFF:
		return SkillMastery.School.ALTERATION
	if "shadow" in tags and skill.skill_type == SkillData.SkillType.DASH:
		return SkillMastery.School.ILLUSION
	return SkillMastery.School.DESTRUCTION


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
	var helmet = load("res://content/items/examples/iron_helmet.tres")
	var armor = load("res://content/items/examples/leather_armor.tres")
	var boots = load("res://content/items/examples/iron_boots.tres")
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


func _process(delta: float) -> void:
	# 低血量触发器冷却递减
	for trigger in _low_hp_cooldowns:
		var cd: float = _low_hp_cooldowns[trigger]
		if cd > 0:
			_low_hp_cooldowns[trigger] = cd - delta

	# 蓄力累加
	if _charging_source != "" and _charge_skill:
		_charge_power = minf(1.0, _charge_power + delta / _charge_skill.charge_duration)
		# 更新瞄准指示器大小反映蓄力进度
		if _aim_dot and _aim_dot.visible:
			_aim_dot.scale = Vector2(0.08, 0.08) * (0.5 + _charge_power * 1.0)

	# 引导 tick
	if _channeling_source != "" and _channel_skill:
		_channel_timer += delta
		if _channel_timer >= _channel_skill.channel_tick_interval:
			_channel_timer -= _channel_skill.channel_tick_interval
			# 消耗 MP
			var mp_cost := int(_channel_skill.channel_mp_per_sec * _channel_skill.channel_tick_interval)
			if mana_component and not mana_component.use_mp(mp_cost):
				_cancel_channel()
			else:
				_channel_tick()

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
		SkillData.SkillType.SUMMON:     return Color(0.7, 0.4, 1.0, 0.6)
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
