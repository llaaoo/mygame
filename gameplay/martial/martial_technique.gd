class_name MartialTechnique
extends Resource
@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export var weapon_type := ""
@export var cooldown := 6.0
@export var price := 8
@export var profile: AttackProfile
@export var charged_profile: AttackProfile
@export var charged_followup_profile: AttackProfile
## An explicit input can take this route after a confirmed normal stroke.
@export var followup_after: Array[int]=[]
@export var followup_profile: AttackProfile
@export var art_routes: Array[MartialRoute]=[]
@export var prerequisites: Array[String]=[]
@export var exclusive_group := ""
@export var release_reach := 140.0
@export var release_angle := 110.0
@export var release_speed := 600.0
func valid() -> bool:
	for variant in [charged_profile,charged_followup_profile]:
		if variant and (not variant.valid() or variant.title.is_empty() or (weapon_type=="bow")!=(variant.projectile_speed>0)): return false
	if charged_followup_profile and not followup_profile: return false
	var routes: Dictionary={}
	for route in art_routes:
		if not route or not route.valid() or routes.has(route.id) or route.form==MartialRoute.Form.FOLLOWUP and not followup_profile: return false
		routes[route.id]=true
	if followup_after.is_empty()!=(followup_profile==null): return false
	if followup_profile and (not followup_profile.valid() or followup_profile.title.is_empty() or (weapon_type=="bow")!=(followup_profile.projectile_speed>0)): return false
	var seen: Dictionary={}
	for stage in followup_after:
		if stage<0 or seen.has(stage): return false
		seen[stage]=true
	return not id.is_empty() and not title.is_empty() and weapon_type in WeaponMoveset.TITLES and is_finite(cooldown) and cooldown>=0 and cooldown<=86400 and price>=0 and profile!=null and profile.valid() and is_finite(release_reach) and release_reach>0 and release_reach<=400 and is_finite(release_angle) and release_angle>0 and release_angle<=360 and is_finite(release_speed) and release_speed>0 and release_speed<=1200

func attack_form(linked: bool,charged := false) -> AttackProfile:
	if charged:
		return charged_followup_profile if linked else charged_profile
	return followup_profile if linked else profile

func followup_description() -> String:
	if not followup_profile: return ""
	var stages:=PackedStringArray()
	for stage in followup_after: stages.append(str(stage+1))
	return "接势 · %s：普攻第%s段造成未格挡的有效伤害后，在收招/接续窗口手动按武技键。起手%.2f秒 · 距离%.0f · 扇面%.0f° · 推移%.0f · 体力%.0f；沿用同一冷却。Ctrl+武技键固定常规形式，Shift仍显式释放附魔。"%[followup_profile.title,"/".join(stages),followup_profile.windup,followup_profile.reach,followup_profile.angle_degrees,followup_profile.push_distance,followup_profile.stamina_cost]
func art_route(route_id: String) -> MartialRoute:
	for route in art_routes:
		if route.id==route_id: return route
	return null
func art_description(key_label: String) -> String:
	if art_routes.is_empty(): return "此武技尚无连招路线，可选择独立快捷绑定。"
	var text:="学习后无需占用快捷槽。共用武技键：%s；完成收招后开始窗口，短按速发，长按蓄力重发；Shift+该键显式释放附魔。"%key_label
	for route in art_routes:
		text+="\n%s → %s · %.1f秒窗口"%[route.describe(),followup_profile.title if route.form==MartialRoute.Form.FOLLOWUP else title,route.window]
	return text
