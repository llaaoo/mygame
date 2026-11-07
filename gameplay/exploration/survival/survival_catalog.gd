class_name SurvivalCatalog
extends RefCounted
## Provisions share inventory; their needs/timers stay separate from spell payloads.
const TITLES := {"grain": "谷粮", "herb": "苦叶", "ration": "烤饼", "broth": "苦叶炖汤", "tea": "醒神茶", "clean_water": "饮用水", "dirty_water": "未净化水"}
const WATER_CAPACITY := 4
const FOODS := {
	"ration": {"nutrition": 45.0, "hydration": 0.0, "fatigue": 0.0, "duration": 180.0, "seconds": 1.5, "text": "饱食+45；180秒食物恢复：生命回复+0.6/秒。同类食物替换，不叠加。"},
	"broth": {"nutrition": 35.0, "hydration": 20.0, "fatigue": -8.0, "duration": 240.0, "seconds": 1.5, "text": "饱食+35、饮水+20、疲劳-8；240秒生命回复+0.4/秒、法力回复+0.5/秒，替换原食物。"},
	"tea": {"nutrition": 0.0, "hydration": 25.0, "fatigue": -15.0, "duration": 150.0, "seconds": 0.5, "text": "0.5秒饮用；饮水+25、疲劳-15；解除当前中毒，150秒法力回复+1/秒；不提供持续毒免疫。"},
	"clean_water": {"nutrition": 0.0, "hydration": 40.0, "fatigue": 0.0, "duration": 120.0, "seconds": 1.0, "text": "饮水+40，120秒法力回复+0.5/秒；同类饮水刷新，不叠加。"},
	"dirty_water": {"nutrition": 0.0, "hydration": 25.0, "fatigue": 0.0, "duration": 0.0, "seconds": 1.0, "text": "应急饮水+25，但会施加中毒；不获得饮水恢复增益。可先过滤煮沸。"}
}
const RECIPES := {
	"ration": {"inputs": {"grain": 1}, "output": "ration", "unlock": ""},
	"purify": {"inputs": {"dirty_water": 1, "charcoal": 1}, "output": "clean_water", "unlock": ""},
	"tea": {"inputs": {"herb": 1, "clean_water": 1}, "output": "tea", "unlock": "survival.archive_recipe"},
	"broth": {"inputs": {"ration": 1, "herb": 1, "clean_water": 1}, "output": "broth", "unlock": "survival.drain_recipe"}
}

static func water_count(supplies: CastingSupplies) -> int:
	return supplies.count("clean_water") + supplies.count("dirty_water")
