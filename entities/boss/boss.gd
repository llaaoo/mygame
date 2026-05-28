class_name Boss
extends Enemy
## Boss 敌人 — 纯数据驱动，通过 BossData .tres 配置
## 用 enemy.tscn 场景 + boss.gd 脚本 + .tres 数据 = 任意 Boss

## Boss 数据（唯一配置入口）
@export var boss_data: BossData

## 运行时
## 公开访问（供 BossHPBar）
var boss_name: String:
	get:
		return boss_data.boss_name if boss_data else "Boss"

var _skill_timer: float = 0.0
var _rage_mode: bool = false
var _triggered_thresholds: Array[float] = []


func _ready() -> void:
	# 从 BossData 读取所有配置
	if boss_data:
		max_hp = boss_data.max_hp
		attack_damage = boss_data.attack_damage
		detect_range = boss_data.detect_range
		move_speed = boss_data.move_speed
		attack_cooldown = boss_data.attack_cooldown
		enemy_name = boss_data.boss_name
		enemy_color = boss_data.color
		enemy_scale = Vector2(boss_data.scale, boss_data.scale)

	super._ready()

	# 覆盖 Enemy 预设的视觉（BossData 优先）
	if boss_data:
		enemy_scale = Vector2(boss_data.scale, boss_data.scale)
		enemy_color = boss_data.color
		enemy_name = boss_data.boss_name
	_apply_visuals()

	# 免疫组
	for group_name in boss_data.immune_groups:
		add_to_group(group_name)

	health_component.health_changed.connect(_check_phase)
	_setup_boss_skills()
	call_deferred("_show_boss_bar")


func _show_boss_bar() -> void:
	await get_tree().process_frame
	var bar := get_tree().get_first_node_in_group("boss_bar")
	if bar and bar.has_method("show_bar"):
		bar.show_bar(self)


func _hide_boss_bar() -> void:
	var bar := get_tree().get_first_node_in_group("boss_bar")
	if bar and bar.has_method("hide_bar"):
		bar.hide_bar()


func _setup_boss_skills() -> void:
	if not boss_data:
		return
	if not skill_manager.pool:
		skill_manager.pool = SkillPool.new()

	# 加载阶段技能和主动技能
	var to_load: Array[String] = []
	if not boss_data.active_skill_id.is_empty():
		to_load.append(boss_data.active_skill_id)
	for entry in boss_data.phase_skills:
		var sid: String = entry[1]
		if sid not in to_load:
			to_load.append(sid)

	for sid in to_load:
		if skill_manager.pool.has_skill(sid):
			continue
		var skill := load("res://gameplay/abilities/data/%s_data.tres" % sid) as SkillData
		if skill:
			match sid:
				"flame_storm":
					skill.archetype = "persistent_aoe"
					skill.aoe_visual = load("res://content/visuals/fire_aoe_visual.tres")
					skill.cast_distance = 0.0
					skill.tags = ["fire"]
				"ice_armor":
					skill.buff_resource = load("res://gameplay/abilities/data/ice_armor_buff.tres") as Buff
					skill.tags = ["ice"]
				"ice_explosion":
					skill.archetype = "persistent_aoe"
					skill.aoe_visual = load("res://content/visuals/ice_aoe_visual.tres")
					skill.tags = ["ice", "aoe"]
			skill_manager.pool.add_skill(skill)

	skill_manager.pool.build()


## ── Boss AI ──

func _on_chase_physics(delta: float) -> void:
	if boss_data and not boss_data.active_skill_id.is_empty():
		_skill_timer += delta
		var interval: float = boss_data.active_skill_interval
		if _rage_mode:
			interval *= 0.6
		if _skill_timer >= interval:
			_skill_timer = 0.0
			_cast_skill(boss_data.active_skill_id)

	if _rage_mode:
		move_speed = boss_data.move_speed * 1.8 if boss_data else 160.0
		attack_cooldown = 0.6

	super._on_chase_physics(delta)


func _check_phase(_current_hp: int, max_hp: int) -> void:
	if health_component.is_dead:
		_hide_boss_bar()
		return

	var ratio := float(health_component.hp) / float(max_hp)
	if ratio <= 0.0:
		return

	if not boss_data:
		return

	for entry in boss_data.phase_skills:
		var threshold: float = entry[0]
		var skill_id: String = entry[1]
		if ratio < threshold and threshold not in _triggered_thresholds:
			_triggered_thresholds.append(threshold)
			_cast_skill(skill_id)

	if ratio < 0.25 and not _rage_mode:
		_rage_mode = true
		print("👹 [%s] 进入狂暴模式！" % boss_data.boss_name)

	var bar := get_tree().get_first_node_in_group("boss_bar")
	if bar and bar.has_method("update_hp"):
		bar.update_hp(health_component.hp, max_hp)


func _cast_skill(skill_id: String) -> void:
	var skill := skill_manager.pool.get_skill(skill_id)
	if not skill:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and p.skill_manager and p.skill_manager.pool:
			skill = p.skill_manager.pool.get_skill(skill_id)
	if not skill:
		return

	var dir := get_player_direction() if player else Vector2.DOWN
	skill_manager.executor.execute(skill, CastContext.simple(self, dir, skill))
	print("👹 [%s] 释放 %s！" % [boss_data.boss_name, skill.display_name])


## ── 火系减伤（从 BossData.resists 读取） ──

func take_damage(amount: int) -> void:
	var actual := amount
	if boss_data and has_meta("_last_hit_tags"):
		var raw = get_meta("_last_hit_tags", [])
		if raw is Array:
			for tag in raw:
				var t: String = str(tag)
				# burning → fire 抗性映射
				var lookup: String = "fire" if t == "burning" else t
				var resist: float = boss_data.resists.get(lookup, 0.0)
				if resist > 0.0:
					actual = maxi(1, int(amount * (1.0 - resist)))
					break
	super.take_damage(actual)


func _on_died() -> void:
	_hide_boss_bar()
	super._on_died()
	if boss_data:
		print("💀 [%s] 已被击败！" % boss_data.boss_name)
