class_name SurvivalNeeds
extends RefCounted
## Persistent expedition state, advanced only by the existing simulation clock.
var nutrition := 100.0
var hydration := 100.0
var fatigue := 0.0
var meal := ""
var meal_remaining := 0.0
var water_remaining := 0.0
var tea_remaining := 0.0
var harvests: Dictionary = {}

func tick(delta: float, endurance: int, sheltered := false) -> void:
	var resilience := clampf(1 - maxf(0, endurance - 10) * .02, .7, 1)
	var exposure := .25 if sheltered else 1.0
	nutrition = maxf(0, nutrition - delta / 15.0 * resilience * exposure)
	hydration = maxf(0, hydration - delta / 10.0 * resilience * exposure)
	fatigue = minf(100, fatigue + delta * .04 * resilience * (0 if sheltered else 1))
	meal_remaining = maxf(0, meal_remaining - delta)
	water_remaining = maxf(0, water_remaining - delta)
	tea_remaining = maxf(0, tea_remaining - delta)
	if meal_remaining == 0: meal = ""
	for id in harvests.keys():
		harvests[id] = maxf(0, float(harvests[id]) - delta)
		if harvests[id] == 0: harvests.erase(id)

func exert(amount: float, endurance: int) -> void:
	fatigue = clampf(fatigue + amount * clampf(1 - maxf(0, endurance - 10) * .02, .7, 1), 0, 100)

func consume(id: String) -> void:
	var food: Dictionary = SurvivalCatalog.FOODS[id]
	nutrition = clampf(nutrition + float(food.nutrition), 0, 100)
	hydration = clampf(hydration + float(food.hydration), 0, 100)
	fatigue = clampf(fatigue + float(food.fatigue), 0, 100)
	match id:
		"ration", "broth":
			meal = id
			meal_remaining = food.duration
		"clean_water": water_remaining = food.duration
		"tea": tea_remaining = food.duration

func preparation_multiplier() -> float:
	return 1.25 if fatigue >= 85 else 1.15 if fatigue >= 60 else 1.0

func recovery() -> Dictionary:
	var tired := .5 if fatigue >= 85 else 1.0
	return {"health_multiplier": (.35 if nutrition <= 20 else 1.0) * tired, "mana_multiplier": (.35 if hydration <= 20 else 1.0) * tired, "health_bonus": (.6 if meal == "ration" else .4 if meal == "broth" else 0.0) if meal_remaining > 0 else 0.0, "mana_bonus": (.5 if water_remaining > 0 else 0.0) + (1.0 if tea_remaining > 0 else 0.0) + (.5 if meal == "broth" and meal_remaining > 0 else 0.0)}

func serialize() -> Dictionary:
	return {"nutrition": nutrition, "hydration": hydration, "fatigue": fatigue, "meal": meal, "meal_remaining": meal_remaining, "water_remaining": water_remaining, "tea_remaining": tea_remaining, "harvests": harvests.duplicate()}

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in ["nutrition", "hydration", "fatigue", "meal_remaining", "water_remaining", "tea_remaining"]:
		var value: Variant = data.get(key, 100.0 if key in ["nutrition", "hydration"] else 0.0)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) < 0: return false
		if key in ["nutrition", "hydration", "fatigue"] and float(value) > 100: return false
		if key in ["meal_remaining", "water_remaining", "tea_remaining"] and float(value) > float({"meal_remaining": 240, "water_remaining": 120, "tea_remaining": 150}[key]): return false
	if data.get("meal", "") not in ["", "ration", "broth"] or not data.get("harvests", {}) is Dictionary: return false
	for id in data.get("harvests", {}):
		var value: Variant = data.harvests[id]
		if not id is String or typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) < 0 or float(value) > 240: return false
	for key in ["hp", "mp"]:
		if data.has(key) and (not data[key] is int or int(data[key]) < 0): return false
	return true

func restore(data: Dictionary) -> void:
	if not valid(data): data = {}
	nutrition = float(data.get("nutrition", 100))
	hydration = float(data.get("hydration", 100))
	fatigue = float(data.get("fatigue", 0))
	meal = str(data.get("meal", ""))
	meal_remaining = minf(240, float(data.get("meal_remaining", 0)))
	water_remaining = minf(120, float(data.get("water_remaining", 0)))
	tea_remaining = minf(150, float(data.get("tea_remaining", 0)))
	harvests = data.get("harvests", {}).duplicate()
