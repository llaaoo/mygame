class_name SkillExecutor
extends Node
## 核心执行器 — 调度器 + 分阶段 Modifier Pipeline
## 
## 职责：
##   1. 持有分阶段 modifier 管线（FLAT → MULTIPLY → OVERRIDE → FINAL）
##   2. execute() 统一施法入口
##   3. resolve_damage() 按阶段跑管线 → 返回最终伤害值
##   4. 按技能类型分发具体执行
##
## 阶段保证：
##   同阶段内按 priority 排序 → 消除"谁后执行谁赢"的隐式 bug
##   FLAT 永远在 MULTIPLY 之前 → 火焰戒指+20% 一定作用在基础值上

## ── 分阶段 Modifier 管线 ──
## key = DamageModifier.Stage (int), value = Array[DamageModifier] (已按 priority 排序)
var modifiers_by_stage: Dictionary = {
	DamageModifier.Stage.FLAT: [],
	DamageModifier.Stage.MULTIPLY: [],
	DamageModifier.Stage.OVERRIDE: [],
	DamageModifier.Stage.FINAL: [],
}

## ── 兼容旧代码的平铺视图（只读） ──
var modifiers: Array[DamageModifier]:
	get:
		var all: Array[DamageModifier] = []
		for stage in [DamageModifier.Stage.FLAT, DamageModifier.Stage.MULTIPLY, DamageModifier.Stage.OVERRIDE, DamageModifier.Stage.FINAL]:
			all.append_array(modifiers_by_stage[stage])
		return all


## ── 管线入口：伤害解析（分阶段） ──
## 流程：DamageContext → FLAT → MULTIPLY → OVERRIDE → FINAL → return

func resolve_damage(skill: SkillData, ctx: CastContext) -> int:
	var dc := DamageContext.from_cast(skill, ctx)
	var trace := CombatDebugger.active()

	if trace:
		trace.record(
			CombatTraceEvent.Category.DAMAGE_RESOLVE,
			CombatPhase.Phase.MODIFIER,
			"resolve_damage: %s" % skill.display_name,
			skill.get_id(), "",
			{"base_damage": dc.base_damage},
			{},
			{"tags": skill.tags}
		)

	_apply_stage(dc, DamageModifier.Stage.FLAT, trace)
	_apply_stage(dc, DamageModifier.Stage.MULTIPLY, trace)
	_apply_stage(dc, DamageModifier.Stage.OVERRIDE, trace)
	_apply_stage(dc, DamageModifier.Stage.FINAL, trace)

	var result := maxi(1, dc.final_damage)

	if trace:
		trace.final_damage = result

	return result


## 执行单个阶段的所有 modifier（带 trace）
func _apply_stage(ctx: DamageContext, stage: DamageModifier.Stage, trace: CombatTrace = null) -> void:
	var stage_names := ["FLAT", "MULTIPLY", "OVERRIDE", "FINAL"]
	for mod in modifiers_by_stage[stage]:
		if mod and mod.enabled:
			var before := ctx.final_damage
			mod.modify(ctx)
			var after := ctx.final_damage

			if trace and before != after:
				var mod_name: String = mod.get_script().get_global_name() if mod.get_script() else "UnknownModifier"
				trace.record_modifier(mod_name, stage_names[stage], before, after, ctx.tags)


## ── 统一施法入口 ──

func execute(skill: SkillData, context: CastContext) -> bool:
	if not skill or not context or not context.caster:
		return false

	var exec_inst := CombatExecutor.instance

	# 阶段重置：确保无论从何处调用，始终从 IDLE 开始（TriggeredEffect 链可能在 EVENT 中调用）
	if exec_inst:
		exec_inst.enter_phase(CombatPhase.Phase.IDLE)
		exec_inst.reset_chain()

	# 开始追踪（必须在阶段转移之前，确保 enter_phase 的 trace 能被记录）
	var trace := CombatDebugger.begin("cast_%s" % skill.get_id(), skill.display_name)
	if trace:
		trace.record(
			CombatTraceEvent.Category.PHASE_ENTER,
			CombatPhase.Phase.INPUT,
			"cast: %s" % skill.display_name,
			skill.get_id(), "",
			{"mp_cost": skill.mp_cost, "cooldown": skill.cooldown},
			{}
		)

	# ── MODIFIER 阶段 ──
	if exec_inst:
		exec_inst.enter_phase(CombatPhase.Phase.MODIFIER)

	# ── EFFECT 阶段 ──
	if exec_inst:
		exec_inst.enter_phase(CombatPhase.Phase.EFFECT)

	var ok := false
	var defer_store := false  ## 投射物/AoE 延迟 store，在命中时由实例负责
	match skill.skill_type:
		SkillData.SkillType.PROJECTILE:
			ok = _execute_projectile(skill, context)
			defer_store = ok
		SkillData.SkillType.BUFF:
			ok = _execute_buff(skill, context)
		SkillData.SkillType.AOE:
			ok = _execute_aoe(skill, context)
			defer_store = ok
		SkillData.SkillType.DASH:
			ok = _execute_dash(skill, context)
		SkillData.SkillType.SUMMON:
			ok = _execute_summon(skill, context)

	# ── EVENT 阶段（ON_CAST 必须在此阶段发射） ──
	if exec_inst:
		exec_inst.enter_phase(CombatPhase.Phase.EVENT)

	if ok:
		_emit_event(CombatEvent.Type.ON_CAST, context.caster, context.target, skill)

	# ── POST 阶段 ──
	if exec_inst:
		exec_inst.enter_phase(CombatPhase.Phase.POST)

	# 存储追踪
	if trace:
		trace.record(
			CombatTraceEvent.Category.SKILL_EXECUTE,
			CombatPhase.Phase.POST,
			"done: %s" % skill.display_name,
			skill.get_id(), "",
			{},
			{"success": ok, "final_damage": trace.final_damage}
		)
		if not defer_store:
			# Buff/Dash: 立即关闭 trace
			CombatDebugger.store(trace)
		# Projectile/AoE: trace 保持活跃，由实例在命中/超时后 store

	# ── 回到 IDLE ──
	if exec_inst:
		exec_inst.enter_phase(CombatPhase.Phase.IDLE)

	return ok


## 发射战斗事件 → CombatExecutor（唯一权威入口）
func _emit_event(type: CombatEvent.Type, source: Node2D, target: Node2D = null, skill: SkillData = null, extra_data: Dictionary = {}) -> void:
	var tags: Array[String] = skill.tags if skill else []
	CombatExecutor.report_cast(source, target, skill, {"tags": tags, "extra": extra_data})


## ── 投射物 ──

const _ARCHETYPE_SCENES := {
	"linear_projectile": "res://gameplay/abilities/archetypes/linear_projectile.tscn",
	"persistent_aoe": "res://gameplay/abilities/archetypes/persistent_aoe.tscn",
	"summon_entity": "res://gameplay/abilities/archetypes/summon_entity.tscn",
}


func _execute_projectile(skill: SkillData, ctx: CastContext) -> bool:
	var scene: PackedScene
	
	# 优先用 SkillData 显式指定的场景（兼容旧数据）
	if skill.projectile_scene:
		scene = skill.projectile_scene
	elif skill.scene:
		scene = skill.scene
	elif not skill.archetype.is_empty() and _ARCHETYPE_SCENES.has(skill.archetype):
		scene = load(_ARCHETYPE_SCENES[skill.archetype]) as PackedScene
	
	if not scene:
		push_warning("[SkillExecutor] 无可用 archetype 场景: %s" % skill.archetype)
		return false
	
	var instance := scene.instantiate() as Node2D
	ctx.world.add_child(instance)
	instance.global_position = ctx.caster.global_position + ctx.direction * skill.cast_distance
	
	if instance is Projectile:
		var proj := instance as Projectile
		proj.setup(skill, ctx.caster, ctx.direction)
		proj.damage = resolve_damage(skill, ctx)
		proj.set_meta("skill_data", skill)
		proj.set_meta("_combat_trace", CombatDebugger.active())
	elif instance.has_method("setup"):
		instance.setup(skill, ctx.caster, ctx.direction)
		if "damage" in instance:
			instance.damage = resolve_damage(skill, ctx)
		instance.set_meta("skill_data", skill)
		instance.set_meta("_combat_trace", CombatDebugger.active())
	
	return true


## ── Buff ──

func _execute_buff(skill: SkillData, ctx: CastContext) -> bool:
	if not skill.buff_resource:
		return false
	var buff_manager := ctx.caster.get_node_or_null("BuffManager")
	if not buff_manager:
		return false
	var buff := skill.buff_resource.duplicate() as Buff
	if skill.buff_duration > 0:
		buff.duration = skill.buff_duration
	buff_manager.apply_buff(buff)
	# trace 由 BuffManager.apply_buff 统一记录
	return true


## ── AoE ──

func _execute_aoe(skill: SkillData, ctx: CastContext) -> bool:
	var scene: PackedScene
	
	# 优先用 SkillData 显式指定的场景（兼容旧数据）
	if skill.aoe_scene:
		scene = skill.aoe_scene
	elif not skill.archetype.is_empty() and _ARCHETYPE_SCENES.has(skill.archetype):
		scene = load(_ARCHETYPE_SCENES[skill.archetype]) as PackedScene
	
	if not scene:
		push_warning("[SkillExecutor] 无可用 AoE archetype 场景: %s" % skill.archetype)
		return false
	
	var instance := scene.instantiate() as Node2D
	ctx.world.add_child(instance)
	# 若指定了 target_position（如触发施法），直接放在目标位置
	if ctx.target_position != Vector2.ZERO:
		instance.global_position = ctx.target_position
	else:
		instance.global_position = ctx.caster.global_position + ctx.direction * skill.cast_distance
	
	if instance.has_method("setup"):
		instance.setup(skill, ctx.caster)
	else:
		if "damage" in instance:
			instance.damage = resolve_damage(skill, ctx)
		if instance.has_method("set_caster"):
			instance.set_caster(ctx.caster)
	
	instance.set_meta("skill_data", skill)
	instance.set_meta("_combat_trace", CombatDebugger.active())
	return true


## ── 位移（Dash） ──

func _execute_dash(skill: SkillData, ctx: CastContext) -> bool:
	if not ctx.caster is CharacterBody2D:
		return false
	var body := ctx.caster as CharacterBody2D
	var target_pos := body.global_position + ctx.direction * skill.dash_distance

	if skill.buff_resource:
		target_pos = _find_shadow_step_target(body, ctx.direction, skill.dash_distance)

	var tween := body.create_tween()
	tween.tween_property(body, "global_position", target_pos,
		body.global_position.distance_to(target_pos) / skill.dash_speed
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	if skill.buff_resource:
		# trace：在 tween 之前记录 Buff（避免异步导致 trace 已关闭）
		var buff_preview := skill.buff_resource.duplicate() as Buff
		if skill.buff_duration > 0:
			buff_preview.duration = skill.buff_duration
		_record_buff_trace(buff_preview, ctx.caster.name)

		tween.tween_callback(_apply_dash_buff.bind(skill, ctx.caster))
	return true


func _find_shadow_step_target(body: CharacterBody2D, direction: Vector2, max_dist: float) -> Vector2:
	var best_target := Vector2.INF
	var best_dist := max_dist

	for enemy in body.get_tree().get_nodes_in_group("enemy"):
		var epos: Vector2 = enemy.global_position
		var to_enemy := epos - body.global_position
		var proj_dist := to_enemy.dot(direction)
		if proj_dist <= 0 or proj_dist > max_dist:
			continue
		var lateral := (to_enemy - direction * proj_dist).length()
		if lateral > 80:
			continue
		if proj_dist < best_dist:
			best_dist = proj_dist
			best_target = epos + direction * 40.0

	if best_target != Vector2.INF:
		return best_target
	return body.global_position + direction * max_dist


## ── 召唤 ──

func _execute_summon(skill: SkillData, ctx: CastContext) -> bool:
	if not skill.summon_data:
		push_warning("[SkillExecutor] 召唤技能缺少 summon_data: %s" % skill.display_name)
		return false

	var player := ctx.caster as Player
	if not player:
		push_warning("[SkillExecutor] 召唤技能只能由 Player 使用")
		return false

	var manager := player.get_node_or_null("SummonManager") as SummonManager
	if not manager:
		push_warning("[SkillExecutor] Player 缺少 SummonManager")
		return false

	if not manager.can_summon():
		print("⚠️ [SkillExecutor] 召唤物已达上限 (%d)，无法召唤" % SummonManager.MAX_SUMMONS)
		return false

	var scene: PackedScene = load(_ARCHETYPE_SCENES["summon_entity"]) as PackedScene
	if not scene:
		return false

	var instance := scene.instantiate() as SummonEntity
	ctx.world.add_child(instance)

	# 在玩家身后生成
	var spawn_pos := ctx.caster.global_position - ctx.direction * 50.0
	# 加一点随机偏移，多个召唤物不重叠
	spawn_pos += Vector2(randf_range(-30, 30), randf_range(-30, 30))
	instance.global_position = spawn_pos

	instance.setup(skill.summon_data, player, manager)
	instance.set_meta("skill_data", skill)

	return true


func _apply_dash_buff(skill: SkillData, caster: Node2D) -> void:
	var buff_manager := caster.get_node_or_null("BuffManager")
	if not buff_manager:
		return
	var buff := skill.buff_resource.duplicate() as Buff
	if skill.buff_duration > 0:
		buff.duration = skill.buff_duration
	buff_manager.apply_buff(buff)


## ── Buff Trace ──

## 描述 Buff 效果为可读字符串（委托给 Buff.describe()）
func _describe_buff(buff: Buff) -> String:
	return buff.describe()


## 在活跃 trace 中记录 Buff 应用
func _record_buff_trace(buff: Buff, caster_name: String) -> void:
	var trace := CombatDebugger.active()
	if not trace:
		return
	var desc := _describe_buff(buff)
	trace.record(
		CombatTraceEvent.Category.EVENT_EMIT,
		CombatPhase.Phase.EFFECT,
		"BUFF → %s" % caster_name, "", "",
		{},
		{"effect": desc}
	)


## ── Modifier 管理（分阶段版本） ──

## 添加 modifier 到对应阶段桶，自动按 priority 排序
func add_modifier(mod: DamageModifier) -> void:
	if not mod:
		return
	var bucket: Array = modifiers_by_stage[mod.stage]
	if mod in bucket:
		return
	bucket.append(mod)
	_sort_bucket(mod.stage)


## 移除 modifier
func remove_modifier(mod: DamageModifier) -> void:
	if not mod:
		return
	var bucket: Array = modifiers_by_stage[mod.stage]
	var idx := bucket.find(mod)
	if idx >= 0:
		bucket.remove_at(idx)


## 按类名移除（方便 Buff 卸载时用）
func remove_modifiers_of_class(class_name_str: String) -> void:
	for stage in [DamageModifier.Stage.FLAT, DamageModifier.Stage.MULTIPLY, DamageModifier.Stage.OVERRIDE, DamageModifier.Stage.FINAL]:
		var to_remove: Array = []
		for mod in modifiers_by_stage[stage]:
			if mod.get_script() and mod.get_script().get_global_name() == class_name_str:
				to_remove.append(mod)
		for mod in to_remove:
			modifiers_by_stage[stage].erase(mod)


## 清空所有 modifier（切换场景/重置用）
func clear_modifiers() -> void:
	for stage in [DamageModifier.Stage.FLAT, DamageModifier.Stage.MULTIPLY, DamageModifier.Stage.OVERRIDE, DamageModifier.Stage.FINAL]:
		modifiers_by_stage[stage].clear()


## 桶内排序：priority 小的先执行
func _sort_bucket(stage: DamageModifier.Stage) -> void:
	modifiers_by_stage[stage].sort_custom(func(a: DamageModifier, b: DamageModifier): return a.priority < b.priority)
