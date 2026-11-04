class_name StatusInstance
extends RefCounted
## Definition resources contain no clocks, stacks or actor ownership.
var serial: int
var definition: Buff
var remaining: float
var stacks := 1
var elapsed := 0.0
var source_ref: WeakRef
var source_skill: SkillData
var source_magic := 0.0

func _init(id: int, buff: Buff, source: Node2D = null, skill: SkillData = null) -> void:
	serial = id
	definition = buff
	remaining = buff.duration
	source_ref = weakref(source) if is_instance_valid(source) else null
	source_skill = skill
	var stats := source.get_node_or_null("StatsComponent") if is_instance_valid(source) else null
	if stats:
		source_magic = stats.magic_damage

func source() -> Node2D:
	return source_ref.get_ref() as Node2D if source_ref else null
