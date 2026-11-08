class_name SurvivalNeeds
extends RefCounted
## Long-term needs. Bound actors query BuffManager for every provision clock.
var nutrition := 100.0
var hydration := 100.0
var fatigue := 0.0
var harvests: Dictionary = {}
var _effects: WeakRef
# Legacy snapshot input and standalone-model adapter, never ticked when bound.
var _meal := ""
var _meal_remaining := 0.0
var _water_remaining := 0.0
var _tea_remaining := 0.0
var meal: String:
	get: return str(_manager().provision("meal").id) if _manager() else _meal
	set(value):
		_meal=value
		if _manager():
			var entry:=ProvisionCatalog.default_catalog().definition(value)
			_manager().set_provision("meal",value,entry.effect.duration if entry and entry.effect else 0)
var meal_remaining: float:
	get: return float(_manager().provision("meal").remaining) if _manager() else _meal_remaining
	set(value):
		_meal_remaining=value
		if _manager(): _manager().set_provision("meal",meal,value)
var water_remaining: float:
	get: return float(_manager().provision("water").remaining) if _manager() else _water_remaining
	set(value):
		_water_remaining=value
		if _manager(): _manager().set_provision("water","clean_water",value)
var tea_remaining: float:
	get: return float(_manager().provision("tea").remaining) if _manager() else _tea_remaining
	set(value):
		_tea_remaining=value
		if _manager(): _manager().set_provision("tea","tea",value)

func _manager() -> BuffManager: return _effects.get_ref() as BuffManager if _effects else null
func bind_effects(manager: BuffManager,import_legacy: bool) -> void:
	_effects=weakref(manager)
	if not import_legacy: return
	for row in [["meal",_meal,_meal_remaining],["water","clean_water",_water_remaining],["tea","tea",_tea_remaining]]:
		var existing:=manager.provision(row[0])
		var remainder: float=float(row[2])
		if existing.id==row[1] and float(existing.remaining)>0: remainder=minf(remainder,float(existing.remaining))
		manager.set_provision(row[0],row[1],remainder,true)

func tick(delta: float,endurance: int,sheltered := false) -> void:
	var resilience:=clampf(1-maxf(0,endurance-10)*.02,.7,1)
	var exposure:=.25 if sheltered else 1.0
	nutrition=maxf(0,nutrition-delta/15.0*resilience*exposure)
	hydration=maxf(0,hydration-delta/10.0*resilience*exposure)
	fatigue=minf(100,fatigue+delta*.04*resilience*(0 if sheltered else 1))
	if not _manager():
		_meal_remaining=maxf(0,_meal_remaining-delta)
		_water_remaining=maxf(0,_water_remaining-delta)
		_tea_remaining=maxf(0,_tea_remaining-delta)
		if _meal_remaining==0: _meal=""
	for id in harvests.keys():
		harvests[id]=maxf(0,float(harvests[id])-delta)
		if harvests[id]==0: harvests.erase(id)

func exert(amount: float,endurance: int) -> void:
	fatigue=clampf(fatigue+amount*clampf(1-maxf(0,endurance-10)*.02,.7,1),0,100)

func consume(id: String) -> void:
	var definition:=ProvisionCatalog.default_catalog().definition(id)
	if not definition: return
	nutrition=clampf(nutrition+definition.nutrition,0,100)
	hydration=clampf(hydration+definition.hydration,0,100)
	fatigue=clampf(fatigue+definition.fatigue,0,100)
	if _manager():
		if definition.effect: _manager().apply_buff(definition.effect)
		return
	if not definition.effect: return
	match definition.effect.provision_group:
		"meal": _meal=id; _meal_remaining=definition.effect.duration
		"water": _water_remaining=definition.effect.duration
		"tea": _tea_remaining=definition.effect.duration

func preparation_multiplier() -> float:
	return 1.25 if fatigue>=85 else 1.15 if fatigue>=60 else 1.0

func recovery() -> Dictionary:
	var tired:=.5 if fatigue>=85 else 1.0
	var result: Dictionary={"health_multiplier":(.35 if nutrition<=20 else 1.0)*tired,"mana_multiplier":(.35 if hydration<=20 else 1.0)*tired}
	result.merge(_manager().provision_recovery() if _manager() else _legacy_recovery(),true)
	return result

func _legacy_recovery() -> Dictionary:
	var result: Dictionary={"health_bonus":0.0,"mana_bonus":0.0,"stamina_bonus":0.0,"mana_sources":{}}
	for row in [[meal,meal_remaining],["clean_water",water_remaining],["tea",tea_remaining]]:
		var entry:=ProvisionCatalog.default_catalog().definition(row[0])
		if row[1]<=0 or not entry or not entry.effect: continue
		var buff:=entry.effect
		result.health_bonus+=buff.health_recovery_bonus; result.mana_bonus+=buff.mana_recovery_bonus; result.stamina_bonus+=buff.stamina_recovery_bonus
		result.mana_sources["food" if buff.provision_group=="meal" else buff.provision_group]=buff.mana_recovery_bonus
	return result

func serialize() -> Dictionary:
	return {"nutrition":nutrition,"hydration":hydration,"fatigue":fatigue,"meal":meal,"meal_remaining":meal_remaining,"water_remaining":water_remaining,"tea_remaining":tea_remaining,"harvests":harvests.duplicate()}

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in ["nutrition","hydration","fatigue","meal_remaining","water_remaining","tea_remaining"]:
		var value: Variant=data.get(key,100.0 if key in ["nutrition","hydration"] else 0.0)
		if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or float(value)<0: return false
		if key in ["nutrition","hydration","fatigue"] and value>100: return false
		var maximum:=0.0
		for entry in ProvisionCatalog.default_catalog().provisions:
			if entry.effect and entry.effect.provision_group=={"meal_remaining":"meal","water_remaining":"water","tea_remaining":"tea"}.get(key,""): maximum=maxf(maximum,entry.effect.duration)
		if key in ["meal_remaining","water_remaining","tea_remaining"] and value>maximum: return false
	var food_id: Variant=data.get("meal","")
	if not food_id is String or not data.get("harvests",{}) is Dictionary: return false
	if not food_id.is_empty():
		var entry:=ProvisionCatalog.default_catalog().definition(food_id)
		if not entry or not entry.effect or entry.effect.provision_group!="meal": return false
	for id in data.get("harvests",{}):
		var value: Variant=data.harvests[id]
		if not id is String or typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value<0 or value>86400: return false
	for key in ["hp","mp"]:
		if data.has(key) and (not data[key] is int or data[key]<0): return false
	return true

func restore(data: Dictionary) -> void:
	if not valid(data): data={}
	nutrition=float(data.get("nutrition",100)); hydration=float(data.get("hydration",100)); fatigue=float(data.get("fatigue",0))
	# Migration input only; bound effects are restored through CampaignSession.
	_meal=str(data.get("meal","")); _meal_remaining=float(data.get("meal_remaining",0))
	_water_remaining=float(data.get("water_remaining",0)); _tea_remaining=float(data.get("tea_remaining",0))
	harvests=data.get("harvests",{}).duplicate()
