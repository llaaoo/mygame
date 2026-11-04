class_name SpellRuleIndex
extends RefCounted
## Build once when content changes; resolution only queries an action/scope bucket.
var _actions: Dictionary = {}

func rebuild(rules: Array) -> void:
	_actions.clear()
	for rule: SpellCombinationRule in rules:
		if not _actions.has(rule.trigger_action_id):
			_actions[rule.trigger_action_id] = {"state": [], "field": [], "all": []}
		var groups: Dictionary = _actions[rule.trigger_action_id]
		groups.all.append(rule)
		groups["state" if rule.required_field_type.is_empty() else "field"].append(rule)
	for groups: Dictionary in _actions.values():
		for bucket: Array in groups.values():
			bucket.sort_custom(func(a: SpellCombinationRule, b: SpellCombinationRule): return a.priority > b.priority if a.priority != b.priority else a.id < b.id)

func for_action(id: String, scope: String = "all") -> Array:
	return _actions.get(id, {}).get(scope, [])
