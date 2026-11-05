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
		var buffs := receiver.get_node_or_null("BuffManager") as BuffManager
		if buffs:
			incoming_multiplier = buffs.get_incoming_hit_multiplier(definition, hit_tags)
