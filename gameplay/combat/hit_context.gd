class_name HitContext
extends RefCounted
var source: Node2D
var target: Node2D
var skill: SkillData
var damage: int
var position: Vector2
var tags: Array
var family_id: String
var periodic := false
var incoming_multiplier := 1.0

func _init(caster: Node2D, receiver: Node2D, amount: int, point: Vector2, definition: SkillData, hit_tags: Array, family: String) -> void:
	source = caster
	target = receiver
	damage = maxi(0, amount)
	position = point
	skill = definition
	tags = hit_tags.duplicate()
	periodic = "dot" in tags
	family_id = family
	if is_instance_valid(receiver):
		incoming_multiplier = incoming_factor(receiver, definition, hit_tags)

static func incoming_factor(receiver: Node2D, definition: SkillData, hit_tags: Array) -> float:
	if not is_instance_valid(receiver): return 1.0
	var buffs := receiver.get_node_or_null("BuffManager") as BuffManager
	var factor := buffs.get_incoming_hit_multiplier(definition, hit_tags) if buffs else 1.0
	var stats := receiver.get_node_or_null("StatsComponent") as StatsComponent
	if stats and ("dot" in hit_tags or "environment" in hit_tags or "trap" in hit_tags): factor *= stats.hazard_damage_multiplier
	return factor
