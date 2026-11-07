class_name InterfaceIcons
extends RefCounted
## Presentation only; icons never decide costs, selection or gameplay.
static func skill(data: SkillData) -> Texture2D:
	var id: String={"inscribe":"hexagon","disperse":"flask-conical","attune":"sparkles","extract":"compass","project":"zap","shape":"hexagon","step":"wind","sustain":"snowflake"}.get(data.operation_id,"")
	if id.is_empty(): id={"ignite":"flame","pulse":"sparkles","water_call":"droplet","focus":"sparkles","soul_harvest":"compass"}.get(data.get_id(),"sparkles")
	return GameUIStyle.icon(id)
static func item(data: ItemData) -> Texture2D:
	if data is EquipmentData: return data.get_icon_texture()
	var id: String={"ration":"utensils","broth":"utensils","tea":"flask-conical","clean_water":"droplet","dirty_water":"droplet"}.get(data.id,"backpack")
	if data.use_profile:
		id="flask-conical"
		if data.use_profile.kind==ItemUseDefinition.Kind.COATING: id="swords"
	return GameUIStyle.icon(id)
