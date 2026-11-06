class_name PlayerCombatBindings
extends Node

var player: Player
var _on_kill_effect: OnKillBonusExp = null
var _on_hit_effect: TriggeredEffect = null
var _on_buff_expire_cast: GenericTriggeredCast = null  ## 通用：Buff过期→释放技能
var _on_kill_fire_trigger: GenericTriggeredCast = null  ## 火系击杀→烈焰风暴
var _synergy_resolver: SkillSynergyResolver = null
var _low_hp_triggers: Array[LowHpTriggerData] = []
var _low_hp_cooldowns: Dictionary = {}  ## trigger → 剩余冷却秒数
const DEFAULT_LOW_HP_TRIGGERS: Array = [[0.3, "shadow_step", 5, 15.0]]
var _owned_effects: Array[TriggeredEffect] = []

func _init(actor: Player) -> void:
	player = actor

func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)

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
	player.health_component.health_changed.connect(_check_low_hp_shadow_step)

	# 技能熟练度系统（上古卷轴式）
	_setup_mastery()

	_synergy_resolver = SkillSynergyResolver.new()
	_synergy_resolver.name = "SkillSynergyResolver"
	player.add_child(_synergy_resolver)
	_synergy_resolver.setup(player)
	_synergy_resolver.reaction_triggered.connect(_show_reaction)

	# EffectGraph：ON_HIT 火焰技能
	_register_graph_demo()

	# 战斗调试器
	_setup_combat_debugger()

	# QuestManager（接在 EventBus 之后）
	_setup_quest_manager()

func _ensure_runtime_ready() -> void:
	var runtime := GameRuntime.instance
	if runtime and not runtime.get_combat_executor():
		await runtime.runtimes_ready

func _register_triggered_effects(effect: TriggeredEffect) -> void:
	if effect not in _owned_effects:
		_owned_effects.append(effect)
	effect.register()
	print("⚡ 已注册触发效果: ", effect.get_script().get_global_name())

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
	cond.removal_reason = "expired"
	trigger.conditions = [cond]

	return trigger

func _setup_low_hp_triggers() -> void:
	if player.exploration_mode:
		return
	for raw in DEFAULT_LOW_HP_TRIGGERS:
		var t := LowHpTriggerData.new()
		t.hp_threshold = raw[0]
		t.cast_skill_id = raw[1]
		t.target_mode = raw[2]
		t.cooldown = raw[3]
		_low_hp_triggers.append(t)
		_low_hp_cooldowns[t] = 0.0

func _check_low_hp_shadow_step(_current_hp: int, max_hp: int) -> void:
	if player.health_component.is_dead:
		return
	var ratio := float(player.health_component.hp) / float(max_hp)
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
		var ev := CombatEvent.create(CombatEvent.Type.ON_DAMAGE, null, player)
		gtc._execute(ev)
		print("🆘 [LowHP] 血量 %.0f%% → %s！" % [ratio * 100, trigger.cast_skill_id])

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

func _register_graph_demo() -> void:
	if player.exploration_mode:
		return
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
	_register_triggered_effects(effect)
	print("🧠 已注册 EffectGraph: ", effect.graph.root.node_name if effect.graph else "(flat)")

func _setup_combat_debugger() -> void:
	# 开发模式下默认开启追踪
	if OS.is_debug_build():
		CombatDebugger.enabled = true
		print("📊 CombatDebugger: trace enabled")

	# 挂载 Debug UI（按 ~ 切换）
	var debug_ui := CombatDebugUI.new()
	debug_ui.name = "CombatDebugUI"
	player.get_parent().add_child.call_deferred(debug_ui)

func _setup_quest_manager() -> void:
	if player.quest_manager:
		return
	player.quest_manager = QuestManager.new()
	player.quest_manager.name = "QuestManager"
	player.get_parent().add_child.call_deferred(player.quest_manager)

	# 任务追踪 UI
	var tracker := QuestTracker.new()
	tracker.name = "QuestTracker"
	player.get_parent().add_child.call_deferred(tracker)
	call_deferred("_setup_quest_tracker", tracker)

func _setup_quest_tracker(tracker: QuestTracker) -> void:
	tracker.setup(player.quest_manager)

func _tag_quest_objects() -> void:
	# 给场景中的 NPC 和 Chest 加 quest 标签
	for node in get_tree().get_nodes_in_group("interactable"):
		if node.is_in_group("villager") or node.is_in_group("chest"):
			continue
		if node.name.begins_with("NPC"):
			node.add_to_group("villager")
		elif node.name.begins_with("Chest"):
			node.add_to_group("chest")

func _setup_mastery() -> void:
	player.mastery_manager = SkillMasteryManager.new()
	player.mastery_manager.name = "MasteryManager"
	player.add_child(player.mastery_manager)
	player.mastery_manager.setup(player)
	player.mastery_manager.perk_unlocked.connect(_on_perk_unlocked)

	# 施法时加 XP
	player.skill_manager.skill_used.connect(_on_skill_used_for_mastery)

	# 命中时加 XP（按伤害）
	if CombatEventBus.instance:
		CombatEventBus.instance.subscribe(CombatEvent.Type.ON_HIT, _on_player_hit_for_mastery)
		CombatEventBus.instance.subscribe(CombatEvent.Type.ON_KILL, _on_player_kill_for_mastery)
	_rebuild_perk_triggers()

func _rebuild_perk_triggers() -> void:
	if not player.mastery_manager:
		return
	if _on_buff_expire_cast:
		_on_buff_expire_cast.unregister()
		_on_buff_expire_cast = null
	if _on_kill_fire_trigger:
		_on_kill_fire_trigger.unregister()
		_on_kill_fire_trigger = null
	for perk in player.mastery_manager.get_unlocked_trigger_perks():
		var trigger := player.mastery_manager.build_trigger_effect(perk)
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
	if not player.mastery_manager:
		return
	var perk := player.mastery_manager.get_perk(perk_id)
	if not perk:
		return
	var trigger := player.mastery_manager.build_trigger_effect(perk)
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
	if player.mastery_manager:
		player.mastery_manager.on_skill_cast(skill)

func _on_player_hit_for_mastery(ev: CombatEvent) -> void:
	if "dot" in ev.data.get("tags", []):
		return
	if ev.source != player:
		return
	if not player.mastery_manager:
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
		player.mastery_manager.on_deal_damage(school, damage)

func _on_player_kill_for_mastery(ev: CombatEvent) -> void:
	if ev.source != player:
		return
	if not player.mastery_manager:
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
	player.mastery_manager.on_kill(school)

func _guess_school_from_skill(skill: SkillData) -> SkillMastery.School:
	return skill.school

func tick(delta: float) -> void:
	for trigger in _low_hp_cooldowns:
		_low_hp_cooldowns[trigger] = maxf(0, float(_low_hp_cooldowns[trigger]) - delta)

func _exit_tree() -> void:
	for effect in _owned_effects:
		effect.unregister()
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_HIT, _on_player_hit_for_mastery)
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_KILL, _on_player_kill_for_mastery)

func _show_reaction(title: String, position: Vector2) -> void:
	var world := CastContext.default_world(player)
	if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion():
		DamageNumber.spawn_reaction(world, title, position - Vector2(0, 25))
