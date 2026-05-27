class_name GenericTriggeredCast
extends TriggeredEffect
## 通用触发施法 — 纯数据驱动的事件→技能映射
##
## 配合 conditions[] 过滤事件，匹配后在指定位置释放指定技能。
## 一条 .tres = 一个战斗互操作规则，零新代码。
##
## 示例 .tres:
##   trigger_type = ON_STATUS_REMOVED
##   conditions = [BuffNameCondition("冰霜护盾")]
##   cast_skill_id = "ice_explosion"
##   caster_mode = SELF
##   target_mode = CASTER_POSITION

## ── 施法者选择 ──
enum CasterMode {
	SELF,           ## 触发者自身（ev.target）
	EVENT_SOURCE,   ## 事件发起方（ev.source）
	EVENT_TARGET,   ## 事件承受方（ev.target，同 SELF）
	PLAYER,         ## 始终使用玩家作为施法者
}

## ── 目标/位置选择 ──
enum TargetMode {
	SELF,            ## 自身位置
	EVENT_SOURCE,    ## 事件发起方位置
	EVENT_TARGET,    ## 事件承受方位置
	NEAREST_ENEMY,   ## 施法者最近敌人
	CASTER_POSITION, ## 施法者脚下
	ESCAPE,          ## 加权逃离所有敌人方向
}

## ── 配置（纯数据，.tres 可编辑） ──
@export var cast_skill_id: String = ""         ## 技能池中的技能 id
@export var caster_mode: CasterMode = CasterMode.SELF
@export var target_mode: TargetMode = TargetMode.CASTER_POSITION
@export var consume_mp: bool = false           ## 是否消耗 MP


func _execute(ev: CombatEvent) -> void:
	if cast_skill_id.is_empty():
		return

	var skill := _find_skill(ev)
	if not skill:
		return

	var caster := _resolve_caster(ev)
	if not caster:
		return

	var target_pos := _resolve_target_position(ev, caster)
	var ctx := CastContext.at_position(caster, target_pos, skill)

	# MP 检查
	if consume_mp and skill.mp_cost > 0:
		var mana := caster.get_node_or_null("ManaComponent") as ManaComponent
		if mana and not mana.use_mp(skill.mp_cost):
			return

	var executor := _find_executor(caster)
	if not executor:
		return

	executor.execute(skill, ctx)
	print("⚡ [GenericTriggeredCast] %s → %s (caster=%s)" % [
		CombatEvent.Type.keys()[ev.type],
		skill.display_name,
		caster.name
	])


## ── 技能查找 ──

func _find_skill(ev: CombatEvent) -> SkillData:
	# 从触发者身上找 SkillManager → pool → 按 id 查找
	var target := ev.target
	if not target:
		return null

	var sm := target.get_node_or_null("SkillManager") as SkillManager
	if sm and sm.pool:
		var skill := sm.pool.get_skill(cast_skill_id)
		if skill:
			return skill

	# Fallback: 全局搜索所有 player 的 SkillManager
	var tree := target.get_tree()
	if tree:
		for node in tree.get_nodes_in_group("player"):
			var fallback_sm := node.get_node_or_null("SkillManager") as SkillManager
			if fallback_sm and fallback_sm.pool:
				var skill := fallback_sm.pool.get_skill(cast_skill_id)
				if skill:
					return skill
	return null


## ── 解析施法者 ──

func _resolve_caster(ev: CombatEvent) -> Node2D:
	match caster_mode:
		CasterMode.SELF, CasterMode.EVENT_TARGET:
			return ev.target as Node2D
		CasterMode.EVENT_SOURCE:
			return ev.source as Node2D
		CasterMode.PLAYER:
			var tree := ev.target.get_tree() if ev.target else null
			if tree:
				return tree.get_first_node_in_group("player") as Node2D
			return null
	return null


## ── 解析目标位置 ──

func _resolve_target_position(ev: CombatEvent, caster: Node2D) -> Vector2:
	match target_mode:
		TargetMode.SELF, TargetMode.CASTER_POSITION:
			return caster.global_position
		TargetMode.EVENT_SOURCE:
			var src := ev.source
			return src.global_position if src and "global_position" in src else caster.global_position
		TargetMode.EVENT_TARGET:
			var tgt := ev.target
			return tgt.global_position if tgt and "global_position" in tgt else caster.global_position
		TargetMode.NEAREST_ENEMY:
			return _find_nearest_enemy_position(caster)
		TargetMode.ESCAPE:
			return caster.global_position + _get_escape_direction(caster) * 250.0

	return caster.global_position


func _find_nearest_enemy_position(caster: Node2D) -> Vector2:
	var nearest: Vector2 = caster.global_position
	var nearest_dist: float = INF
	var tree := caster.get_tree()
	if not tree:
		return nearest

	for enemy in tree.get_nodes_in_group("enemy"):
		var epos: Vector2 = enemy.global_position
		var dist := caster.global_position.distance_to(epos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = epos
	return nearest


## 加权逃离方向（远离所有近处敌人，用于 TargetMode.ESCAPE）
const ESCAPE_RADIUS: float = 300.0

func _get_escape_direction(caster: Node2D) -> Vector2:
	var threat_sum := Vector2.ZERO
	var tree := caster.get_tree()
	if not tree:
		return Vector2.UP
	for node in tree.get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if not enemy:
			continue
		var to_enemy: Vector2 = enemy.global_position - caster.global_position
		var dist: float = to_enemy.length()
		if dist > ESCAPE_RADIUS:
			continue
		var weight := 1.0 / maxf(dist, 10.0)
		threat_sum -= to_enemy.normalized() * weight
	if threat_sum.length_squared() > 0.01:
		return threat_sum.normalized()
	return Vector2.UP


## ── 查找 SkillExecutor ──

func _find_executor(entity: Node2D) -> SkillExecutor:
	var sm := entity.get_node_or_null("SkillManager") as SkillManager
	if sm and sm.executor:
		return sm.executor
	var tree := entity.get_tree()
	if tree:
		for node in tree.get_nodes_in_group("player"):
			var fallback_sm := node.get_node_or_null("SkillManager") as SkillManager
			if fallback_sm and fallback_sm.executor:
				return fallback_sm.executor
	return null
