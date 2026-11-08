class_name SurvivalCatalog
extends RefCounted
## Provisions share inventory; their needs/timers stay separate from spell payloads.
const TITLES := {"grain": "谷粮", "herb": "苦叶", "ration": "烤饼", "broth": "苦叶炖汤", "tea": "醒神茶", "clean_water": "饮用水", "dirty_water": "未净化水"}
const WATER_CAPACITY := 4
static var FOODS: Dictionary:
	get: return ProvisionCatalog.default_catalog().legacy_projection()
const RECIPES := {
	"ration": {"inputs": {"grain": 1}, "output": "ration", "unlock": ""},
	"purify": {"inputs": {"dirty_water": 1, "charcoal": 1}, "output": "clean_water", "unlock": ""},
	"tea": {"inputs": {"herb": 1, "clean_water": 1}, "output": "tea", "unlock": "survival.archive_recipe"},
	"broth": {"inputs": {"ration": 1, "herb": 1, "clean_water": 1}, "output": "broth", "unlock": "survival.drain_recipe"}
}

static func water_count(supplies: CastingSupplies) -> int:
	return supplies.count("clean_water") + supplies.count("dirty_water")
