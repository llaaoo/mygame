class_name ActorAttributes
extends RefCounted
## Rebuild direct attributes from bases and active contributions; no inverse arithmetic.
var actor: Node
var bases: Dictionary = {}
var _last: Dictionary = {}
var _intrinsic: Dictionary = {}
var _external: Dictionary = {}

func _init(owner_actor: Node) -> void:
	actor = owner_actor

func set_bases(values: Dictionary) -> void:
	for key in values:
		if _last.has(key):
			_external[key] = float(_external.get(key, 0)) + read_value(key) - float(_last[key])
		elif bases.has(key) and not _intrinsic.has(key):
			_external[key] = float(bases[key]) - float(values[key])
		_intrinsic[key] = float(values[key])
		bases[key] = float(values[key]) + float(_external.get(key, 0))
		_last[key] = read_value(key)

func restore_bases(values: Dictionary) -> void:
	bases = values.duplicate()
	_last.clear()
	_intrinsic.clear()
	_external.clear()

func base_value(key: String) -> float:
	return float(bases.get(key, read_value(key)))

func primary_value(key: String, base: float, instances: Array[StatusInstance]) -> int:
	var flat := 0.0
	var percent := 0.0
	for instance in instances:
		flat += float(instance.definition.stat_modifiers.get(key, 0)) * instance.stacks
		percent += float(instance.definition.stat_multipliers.get(key, 0)) * instance.stacks
	return maxi(1, roundi((base + flat) * maxf(0.0, 1.0 + percent)))

func rebuild(instances: Array[StatusInstance]) -> void:
	var keys: Dictionary = {}
	for key in _last:
		keys[key] = true
	for instance in instances:
		for key in instance.definition.stat_modifiers:
			keys[key] = true
		for key in instance.definition.stat_multipliers:
			keys[key] = true
		if instance.definition.speed_multiplier != 1.0:
			keys["move_speed"] = true
	for key: String in keys:
		if key in Buff.PRIMARY_STATS:
			continue
		var current := read_value(key)
		if not bases.has(key):
			bases[key] = current
		elif _last.has(key) and not is_equal_approx(current, _last[key]):
			# Legacy direct rewards become a base delta instead of being lost on expiry.
			bases[key] += current - float(_last[key])
			_external[key] = float(_external.get(key, 0)) + current - float(_last[key])
		var flat := 0.0
		var percent := 0.0
		var speed := 1.0
		for instance in instances:
			flat += float(instance.definition.stat_modifiers.get(key, 0)) * instance.stacks
			percent += float(instance.definition.stat_multipliers.get(key, 0)) * instance.stacks
			if key == "move_speed":
				speed *= pow(instance.definition.speed_multiplier, instance.stacks)
		var value := (float(bases[key]) + flat) * maxf(0.0, 1.0 + percent) * speed
		write_value(key, value)
		_last[key] = read_value(key)

func read_value(key: String) -> float:
	var target := _target(key)
	var property := "max_mp" if key == "max_mana" else key
	return float(target.get(property)) if target and property in target else 0.0

func write_value(key: String, value: float) -> void:
	var target := _target(key)
	var property := "max_mp" if key == "max_mana" else key
	if not target or property not in target:
		return
	target.set(property, value if key == "move_speed" else roundi(maxf(1.0, value) if key in ["max_hp", "max_mana"] else value))

func _target(key: String) -> Node:
	match key:
		"max_hp": return actor.get_node_or_null("HealthComponent")
		"max_mana": return actor.get_node_or_null("ManaComponent")
		"attack_damage":
			var combat := actor.get_node_or_null("CombatComponent")
			return combat if combat else actor
	return actor
