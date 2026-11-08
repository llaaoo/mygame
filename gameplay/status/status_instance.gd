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
var source_id := ""
var source_resolver: Callable

func _init(id: int, buff: Buff, source: Node2D = null, skill: SkillData = null) -> void:
	serial = id
	definition = buff
	remaining = buff.duration
	source_ref = weakref(source) if is_instance_valid(source) else null
	if is_instance_valid(source) and "actor_context" in source and source.actor_context: source_id=source.actor_context.id
	source_skill = skill
	var stats := source.get_node_or_null("StatsComponent") if is_instance_valid(source) else null
	if stats:
		source_magic = stats.magic_damage

func source() -> Node2D:
	var current:=source_ref.get_ref() as Node2D if source_ref else null
	if is_instance_valid(current) and not current.is_queued_for_deletion(): return current
	return source_resolver.call(source_id) as Node2D if source_resolver.is_valid() and not source_id.is_empty() else null
