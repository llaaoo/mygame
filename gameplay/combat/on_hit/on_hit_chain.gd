class_name OnHitChain
extends TriggeredEffect
## 命中连锁 — 闪电箭命中后弹射到附近敌人
## 
## 配置: required_skill_tag="lightning", chain_radius=120, chain_count=3, damage_ratio=0.6


@export var required_skill_tag: String = "lightning"
@export var chain_radius: float = 120.0
@export var chain_count: int = 3
@export var damage_ratio: float = 0.6  ## 每次弹射的伤害比例


static func create(tag: String, radius: float = 120.0, count: int = 3, ratio: float = 0.6) -> OnHitChain:
	var effect := OnHitChain.new()
	effect.trigger_type = CombatEvent.Type.ON_HIT
	effect.scope_source = "skill"
	effect.max_recursion = 1
	
	var cond := SkillTagCondition.new()
	cond.required_skill_tag = tag
	effect.conditions = [cond]
	
	effect.required_skill_tag = tag
	effect.chain_radius = radius
	effect.chain_count = count
	effect.damage_ratio = ratio
	return effect


func _execute(ev: CombatEvent) -> void:
	var original_target := ev.target
	if not original_target:
		return
	
	var damage: int = ev.data.get("damage", 0)
	if damage <= 0:
		return
	
	var pos: Vector2 = ev.data.get("position", original_target.global_position)
	var chain_damage := int(damage * damage_ratio)
	
	var nearby := _find_nearby_enemies(original_target, pos, chain_radius)
	var chained := 0
	for enemy in nearby:
		if chained >= chain_count:
			break
		if enemy == original_target:
			continue
		CombatExecutor.report_bonus_damage(ev.source, enemy, chain_damage, ev.skill, ["lightning", "chain"])
		chained += 1
	
	if chained > 0:
		print("⚡ OnHitChain: %s → %d 连锁目标 (dmg=%d)" % [original_target.name, chained, chain_damage])


func _find_nearby_enemies(original: Node2D, pos: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var tree := original.get_tree()
	if not tree:
		return result
	
	for enemy in tree.get_nodes_in_group("enemy"):
		if not (enemy is Node2D):
			continue
		if enemy.global_position.distance_squared_to(pos) <= radius * radius:
			result.append(enemy as Node2D)
	
	# 按距离排序，最近的先弹
	result.sort_custom(func(a: Node2D, b: Node2D): return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return result
