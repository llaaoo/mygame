class_name ActorAnimationCatalog
extends Resource
## Only registered equipment-free profiles may be restored from corpse records.
@export var profiles: Array[ActorAnimationProfile]=[]
static func default_catalog() -> ActorAnimationCatalog:
	return load("res://content/animations/live_profiles.tres") as ActorAnimationCatalog
func definition(id: StringName) -> ActorAnimationProfile:
	for profile in profiles:
		if profile and profile.id==id and profile.equipment_free: return profile
	return profiles[0] if not profiles.is_empty() else null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	if profiles.is_empty(): errors.append("Empty live animation catalog")
	for profile in profiles:
		if not profile or not profile.equipment_free: errors.append("Baked equipment profile in live catalog"); continue
		if seen.has(profile.id): errors.append("Duplicate live animation identity")
		seen[profile.id]=true; errors.append_array(profile.validation_errors())
	return errors
