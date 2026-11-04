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

func _init(caster: Node2D, receiver: Node2D, amount: int, point: Vector2, definition: SkillData, hit_tags: Array, family: String) -> void:
	source = caster
	target = receiver
	damage = maxi(0, amount)
	position = point
	skill = definition
	tags = hit_tags.duplicate()
	periodic = "dot" in tags
	family_id = family
