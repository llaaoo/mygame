class_name WeaponEnchantment
extends Resource
## Immutable chemistry for a real coating, independent of weapon delivery shape.
const IDS := ["flame","venom"]
@export var id := ""
@export var title := ""
@export var tags: Array[String]=[]
@export var color := Color.WHITE
@export var bonus_damage := 6
@export var buildup := 35.0
@export var threshold := 100.0
@export var decay_delay := 3.0
@export var decay_rate := 20.0
@export var status: Buff
@export var release_damage := 18
@export var release_buildup := 100.0
static func definition(key: String) -> WeaponEnchantment:
	return load("res://content/enchantments/%s.tres"%key) as WeaponEnchantment if key in IDS else null
func valid() -> bool:
	return id in IDS and status!=null and not status.status_id.is_empty() and bonus_damage>0 and release_damage>0 and is_finite(buildup) and buildup>0 and is_finite(threshold) and threshold>0 and is_finite(decay_delay) and decay_delay>=0 and is_finite(decay_rate) and decay_rate>0 and is_finite(release_buildup) and release_buildup>0 and not tags.is_empty()
func describe() -> String:
	return "%s：命中附加%d伤害，积累%.0f/%.0f后%s；停手%.0f秒后每秒消退%.0f。Shift+武技消耗整层附魔释放，元素伤害%d。"%[title,bonus_damage,buildup,threshold,status.display_name,decay_delay,decay_rate,release_damage]
