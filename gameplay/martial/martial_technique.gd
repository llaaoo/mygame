class_name MartialTechnique
extends Resource
@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export var weapon_type := ""
@export var cooldown := 6.0
@export var price := 8
@export var profile: AttackProfile
@export var prerequisites: Array[String]=[]
@export var exclusive_group := ""
@export var release_reach := 140.0
@export var release_angle := 110.0
@export var release_speed := 600.0
func valid() -> bool:
	return not id.is_empty() and not title.is_empty() and weapon_type in WeaponMoveset.TITLES and is_finite(cooldown) and cooldown>=0 and cooldown<=86400 and price>=0 and profile!=null and profile.valid() and is_finite(release_reach) and release_reach>0 and release_reach<=400 and is_finite(release_angle) and release_angle>0 and release_angle<=360 and is_finite(release_speed) and release_speed>0 and release_speed<=1200
