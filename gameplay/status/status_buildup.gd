class_name StatusBuildup
extends RefCounted
## Per-target, serializable partial exposure. BuffManager owns its clock/lifetime.
var _entries: Dictionary={}
func add(definition: WeaponEnchantment,amount: float) -> bool:
	var entry: Dictionary=_entries.get(definition.id,{"value":0.0,"delay":0.0})
	entry.value=minf(definition.threshold,float(entry.value)+amount)
	entry.delay=definition.decay_delay
	_entries[definition.id]=entry
	if float(entry.value)+.0001>=definition.threshold:
		_entries.erase(definition.id)
		return true
	return false
func tick(delta: float) -> void:
	for id: String in _entries.keys():
		var definition:=WeaponEnchantment.definition(id)
		var entry: Dictionary=_entries[id]
		var fading:=maxf(0,delta-float(entry.delay))
		entry.delay=maxf(0,float(entry.delay)-delta)
		entry.value=maxf(0,float(entry.value)-fading*definition.decay_rate)
		if float(entry.value)<=0: _entries.erase(id)
func clear() -> void: _entries.clear()
func snapshot() -> Dictionary: return _entries.duplicate(true)
func restore(data: Dictionary,elapsed:=0.0) -> void:
	_entries=data.duplicate(true) if valid(data) else {}
	tick(maxf(0,elapsed))
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()>WeaponEnchantment.IDS.size(): return false
	for id in data:
		if not id is String: return false
		var definition:=WeaponEnchantment.definition(str(id))
		var entry=data[id]
		if not definition or not entry is Dictionary or entry.size()!=2: return false
		for key in ["value","delay"]:
			if typeof(entry.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(entry[key])) or float(entry[key])<0: return false
		if float(entry.value)>=definition.threshold or float(entry.delay)>definition.decay_delay: return false
	return true
