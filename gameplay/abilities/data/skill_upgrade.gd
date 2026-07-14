class_name SkillUpgrade
extends Resource
## Data-driven upgrade applied to a per-slot SkillData runtime copy.

@export var id: String = ""
@export var display_name: String = "未命名强化"
@export_multiline var description: String = ""
@export var branch: String = "通用"
@export_range(1, 10, 1) var max_rank: int = 1
@export var prerequisite_id: String = ""
@export_range(0, 10, 1) var prerequisite_rank: int = 0
@export var added_tags: Array[String] = []

## Supported keys use either flat addition or compounded multiplication:
## damage.flat, damage.multiplier, damage_scaling.flat,
## cooldown.multiplier, mp_cost.multiplier, channel_mp_per_sec.multiplier, range.multiplier,
## projectile_speed.multiplier, cast_distance.multiplier,
## projectile_count.flat, projectile_spread.flat, projectile_pierce.flat,
## projectile_lifetime.multiplier, homing_strength.flat,
## visual_scale.multiplier, aoe_radius.multiplier, aoe_lifetime.multiplier,
## aoe_tick_interval.multiplier, aoe_max_hits.flat,
## buff_duration.multiplier, dash_distance.multiplier, dash_speed.multiplier,
## summon_hp.multiplier, summon_damage.multiplier, summon_duration.multiplier.
@export var modifiers: Dictionary = {}


func can_apply(applied_ranks: Dictionary) -> bool:
	if prerequisite_id.is_empty():
		return true
	return int(applied_ranks.get(prerequisite_id, 0)) >= prerequisite_rank


func apply_to(skill: SkillData, rank: int) -> void:
	if not skill or rank <= 0:
		return
	for tag in added_tags:
		if not skill.tags.has(tag):
			skill.tags.append(tag)
	for key in modifiers:
		_apply_modifier(skill, str(key), float(modifiers[key]), rank)


func _apply_modifier(skill: SkillData, key: String, amount: float, rank: int) -> void:
	var multiplier := pow(1.0 + amount, rank)
	match key:
		"damage.flat":
			skill.damage = maxi(0, skill.damage + int(round(amount * rank)))
		"damage.multiplier":
			skill.damage = maxi(0, int(round(skill.damage * multiplier)))
		"damage_scaling.flat":
			skill.damage_scaling = maxf(0.0, skill.damage_scaling + amount * rank)
		"cooldown.multiplier":
			skill.cooldown = maxf(0.1, skill.cooldown * multiplier)
		"mp_cost.multiplier":
			skill.mp_cost = maxi(0, int(round(skill.mp_cost * multiplier)))
		"channel_mp_per_sec.multiplier":
			skill.channel_mp_per_sec = maxf(0.0, skill.channel_mp_per_sec * multiplier)
		"range.multiplier":
			skill.range = maxf(0.0, skill.range * multiplier)
		"projectile_speed.multiplier":
			skill.projectile_speed = maxf(1.0, skill.projectile_speed * multiplier)
		"cast_distance.multiplier":
			skill.cast_distance = maxf(0.0, skill.cast_distance * multiplier)
		"projectile_count.flat":
			skill.projectile_count = clampi(skill.projectile_count + int(round(amount * rank)), 1, 12)
		"projectile_spread.flat":
			skill.projectile_spread_degrees = maxf(0.0, skill.projectile_spread_degrees + amount * rank)
		"projectile_pierce.flat":
			skill.projectile_pierce = clampi(skill.projectile_pierce + int(round(amount * rank)), 0, 8)
		"projectile_lifetime.multiplier":
			skill.projectile_lifetime = maxf(0.1, skill.projectile_lifetime * multiplier)
		"homing_strength.flat":
			skill.homing_strength = maxf(0.0, skill.homing_strength + amount * rank)
		"visual_scale.multiplier":
			if skill.visual:
				skill.visual.scale = maxf(0.01, skill.visual.scale * multiplier)
		"aoe_radius.multiplier":
			skill.aoe_radius = maxf(1.0, skill.aoe_radius * multiplier)
			if skill.aoe_visual:
				skill.aoe_visual.radius = maxf(1.0, skill.aoe_visual.radius * multiplier)
		"aoe_lifetime.multiplier":
			skill.aoe_lifetime = maxf(0.05, skill.aoe_lifetime * multiplier)
			if skill.aoe_visual:
				skill.aoe_visual.lifetime = maxf(0.05, skill.aoe_visual.lifetime * multiplier)
		"aoe_tick_interval.multiplier":
			skill.aoe_tick_interval = maxf(0.05, skill.aoe_tick_interval * multiplier)
		"aoe_max_hits.flat":
			skill.aoe_max_hits_per_target = clampi(skill.aoe_max_hits_per_target + int(round(amount * rank)), 1, 30)
		"buff_duration.multiplier":
			skill.buff_duration = maxf(0.0, skill.buff_duration * multiplier)
		"dash_distance.multiplier":
			skill.dash_distance = maxf(1.0, skill.dash_distance * multiplier)
		"dash_speed.multiplier":
			skill.dash_speed = maxf(1.0, skill.dash_speed * multiplier)
		"summon_hp.multiplier":
			if skill.summon_data:
				skill.summon_data.max_hp = maxi(1, int(round(skill.summon_data.max_hp * multiplier)))
		"summon_damage.multiplier":
			if skill.summon_data:
				skill.summon_data.damage = maxi(1, int(round(skill.summon_data.damage * multiplier)))
		"summon_duration.multiplier":
			if skill.summon_data:
				skill.summon_data.lifetime = maxf(0.0, skill.summon_data.lifetime * multiplier)
		_:
			push_warning("[SkillUpgrade] Unsupported modifier key: %s" % key)
