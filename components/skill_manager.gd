class_name SkillManager
extends Node
## 技能管理器 — 左手/右手 + 4 快捷键槽位
## 左右手可装备技能或留空（左手空=近战，右手空=无动作）

const MAX_SLOTS := 4

## ── 信号 ──
signal hand_changed(hand: String)          ## "left" / "right"
signal slot_changed(slot_index: int)
signal cooldown_changed(source: String, remaining: float, total: float)
signal skill_used(source: String, skill: SkillData)

## ── 左右手 ──
var left_hand_skill: SkillData = null
var right_hand_skill: SkillData = null

## ── 快捷键槽位 ──
var _slots: Array[Dictionary] = []

## ── 冷却（统一字典） ──
var _cooldowns: Dictionary = {}


func _ready() -> void:
	_slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		_slots[i] = {"skill": null, "cooldown": 0.0}
	_cooldowns["left"] = 0.0
	_cooldowns["right"] = 0.0
	for i in range(MAX_SLOTS):
		_cooldowns["slot_%d" % i] = 0.0


func _process(delta: float) -> void:
	for key in _cooldowns:
		var cd: float = _cooldowns[key]
		if cd > 0.0:
			cd = maxf(0.0, cd - delta)
			_cooldowns[key] = cd
			var total := _get_cooldown_total(key)
			if total > 0:
				cooldown_changed.emit(key, cd, total)


## ── 装备管理 ──

func equip_hand(hand: String, skill: SkillData) -> void:
	match hand:
		"left":  left_hand_skill = skill
		"right": right_hand_skill = skill
	_cooldowns[hand] = 0.0
	hand_changed.emit(hand)


func unequip_hand(hand: String) -> SkillData:
	var old: SkillData = null
	match hand:
		"left":  old = left_hand_skill;  left_hand_skill = null
		"right": old = right_hand_skill; right_hand_skill = null
	_cooldowns[hand] = 0.0
	hand_changed.emit(hand)
	return old


func equip_slot(idx: int, skill: SkillData) -> void:
	if idx < 0 or idx >= MAX_SLOTS:
		return
	_slots[idx]["skill"] = skill
	_slots[idx]["cooldown"] = 0.0
	_cooldowns["slot_%d" % idx] = 0.0
	slot_changed.emit(idx)


func unequip_slot(idx: int) -> SkillData:
	if idx < 0 or idx >= MAX_SLOTS:
		return null
	var old: SkillData = _slots[idx]["skill"]
	_slots[idx] = {"skill": null, "cooldown": 0.0}
	_cooldowns["slot_%d" % idx] = 0.0
	slot_changed.emit(idx)
	return old


func get_slot(idx: int) -> Dictionary:
	if idx < 0 or idx >= MAX_SLOTS:
		return {"skill": null, "cooldown": 0.0}
	return _slots[idx]


## ── 查询 ──

func has_left_spell() -> bool:
	return left_hand_skill != null


func has_right_spell() -> bool:
	return right_hand_skill != null


func can_use(source: String) -> bool:
	return _cooldowns.get(source, 0.0) <= 0.0


## ── 释放 ──

func use_hand(hand: String, caster: Node2D, direction: Vector2) -> bool:
	var skill: SkillData = left_hand_skill if hand == "left" else right_hand_skill
	if not skill:
		return false
	return _execute(skill, hand, caster, direction)


func use_slot(idx: int, caster: Node2D, direction: Vector2) -> bool:
	if idx < 0 or idx >= MAX_SLOTS:
		return false
	var skill: SkillData = _slots[idx]["skill"]
	if not skill:
		return false
	return _execute(skill, "slot_%d" % idx, caster, direction)


func _execute(skill: SkillData, source: String, caster: Node2D, direction: Vector2) -> bool:
	if _cooldowns.get(source, 0.0) > 0.0:
		return false

	# MP 检查
	var mana := caster.get_node_or_null("ManaComponent") as ManaComponent
	if mana and skill.mp_cost > 0 and not mana.use_mp(skill.mp_cost):
		return false

	# 按类型分发
	var ok := false
	match skill.skill_type:
		SkillData.SkillType.PROJECTILE:
			ok = _execute_projectile(skill, caster, direction)
		SkillData.SkillType.BUFF:
			ok = _execute_buff(skill, caster)
		SkillData.SkillType.AOE:
			ok = _execute_aoe(skill, caster, direction)
		SkillData.SkillType.DASH:
			ok = _execute_dash(skill, caster, direction)

	if not ok:
		if mana and skill.mp_cost > 0:
			mana.restore_mp(skill.mp_cost)
		return false

	_cooldowns[source] = skill.cooldown
	cooldown_changed.emit(source, skill.cooldown, skill.cooldown)
	skill_used.emit(source, skill)
	return true


## ── 执行器 ──

func _execute_projectile(skill: SkillData, caster: Node2D, direction: Vector2) -> bool:
	var scene := skill.projectile_scene if skill.projectile_scene else skill.scene
	if not scene:
		return false
	var instance := scene.instantiate() as Node2D
	caster.get_tree().current_scene.add_child(instance)
	instance.global_position = caster.global_position + direction * skill.cast_distance
	if instance is Projectile:
		var proj := instance as Projectile
		proj.set_direction(direction)
		proj.set_caster(caster)
		proj.damage = skill.damage
		proj.speed = skill.projectile_speed
	return true


func _execute_buff(skill: SkillData, caster: Node2D) -> bool:
	if not skill.buff_resource:
		return false
	var buff_manager := caster.get_node_or_null("BuffManager")
	if not buff_manager:
		return false
	var buff := skill.buff_resource.duplicate() as Buff
	if skill.buff_duration > 0:
		buff.duration = skill.buff_duration
	buff_manager.apply_buff(buff)
	return true


func _execute_aoe(skill: SkillData, caster: Node2D, direction: Vector2) -> bool:
	if not skill.aoe_scene:
		return false
	var instance := skill.aoe_scene.instantiate() as Node2D
	caster.get_tree().current_scene.add_child(instance)
	instance.global_position = caster.global_position + direction * skill.aoe_radius
	if "damage" in instance:
		instance.damage = skill.damage
	if instance.has_method("set_caster"):
		instance.set_caster(caster)
	return true


func _execute_dash(skill: SkillData, caster: Node2D, direction: Vector2) -> bool:
	if not caster is CharacterBody2D:
		return false
	var body := caster as CharacterBody2D
	var tween := body.create_tween()
	tween.tween_property(body, "global_position",
		body.global_position + direction * skill.dash_distance,
		skill.dash_distance / skill.dash_speed
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return true


## ── 初始化 ──

func initialize(pool: SkillPool) -> void:
	for i in range(MAX_SLOTS):
		_slots[i] = {"skill": null, "cooldown": 0.0}
		if pool and i < pool.skills.size():
			_slots[i]["skill"] = pool.skills[i]
			slot_changed.emit(i)


## ── 查询冷却（兼容旧 API） ──

func _get_cooldown_total(source: String) -> float:
	match source:
		"left":  return left_hand_skill.cooldown if left_hand_skill else 1.0
		"right": return right_hand_skill.cooldown if right_hand_skill else 1.0
	var idx := source.trim_prefix("slot_").to_int()
	if idx >= 0 and idx < MAX_SLOTS:
		var skill: SkillData = _slots[idx]["skill"]
		return skill.cooldown if skill else 1.0
	return 1.0


func get_cooldown(source: String) -> float:
	return _cooldowns.get(source, 0.0)


func get_cooldown_total(source: String) -> float:
	return _get_cooldown_total(source)
