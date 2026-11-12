class_name EquipmentStatView
extends RefCounted
## Read-only projection of actual equipment definitions, including instance upgrades.
const LABELS := {"impact_bonus":"武器冲击加值","weapon_stamina_cost":"武器体力费用","impact_resistance":"冲击抵抗","stamina_recovery":"体力每秒回复","dodge_cost":"闪避体力费用","attack_damage":"近战攻击加值","strength":"力量","intelligence":"智力","endurance":"耐力","agility":"敏捷","move_speed":"移动速度","damage_reduction":"受伤减免","damage.fire":"火焰伤害","mana_cost.all":"法力费用","preparation_bonus":"准备时间","partial_boon_mana_cost":"部分消费额外MP","field_radius_bonus":"法阵半径","field_duration_bonus":"法阵持续秒数","soul_capacity_bonus":"残魂容量","soul_range_bonus":"汲魂范围","boon_duration_bonus":"恩赐持续时间","empower_damage_bonus":"释放伤害倍率","empower_mana_bonus":"释放额外法力","medium_infusion_cost":"介质灌注法力","partial_boon_damage_multiplier":"保留伤害倍率","medium_infusion_enabled":"介质灌注","partial_boon_enabled":"部分消费","hp_regen":"生命回复","max_hp":"生命上限","max_mp":"法力上限","mp_regen":"法力回复","attack_speed":"攻击速度","weight":"重量","stroke_stamina":"起手轻击体力","stroke_impact":"起手稳定削减","stroke_reach":"起手攻击距离","medium_infusion":"借阵灌注","partial_boon_consumption":"部分消费恩赐"}
const LOWER := ["weight","weapon_stamina_cost","dodge_cost","preparation_bonus","mana_cost.all","partial_boon_mana_cost","empower_mana_bonus","medium_infusion_cost","stroke_stamina"]
static func values(item: EquipmentData) -> Dictionary:
 var result: Dictionary={}
 if not item: return result
 result.merge(item.get_combined_stat_modifiers()); result.merge(item.get_combined_combat_modifiers())
 for key in item.get_combined_stat_multipliers(): result["multiplier:"+key]=item.get_combined_stat_multipliers()[key]
 if item.casting_profile:
  for key in CastingEquipmentProfile.KEYS:
   if item.casting_profile.get(key)!=0: result[key]=item.casting_profile.get(key)
  if item.casting_profile.medium_infusion:
   result.medium_infusion=1; result.medium_infusion_cost=item.casting_profile.medium_infusion_cost
  if item.casting_profile.partial_boon_consumption:
   result.partial_boon_consumption=1; result.partial_boon_mana_cost=item.casting_profile.partial_boon_mana_cost
 var stroke: AttackProfile=item.moveset.attacks[0] if item.moveset and not item.moveset.attacks.is_empty() else item.attack_profile
 if stroke:
  result.stroke_stamina=stroke.stamina_cost; result.stroke_impact=stroke.impact; result.stroke_reach=stroke.reach
 return result
static func percentage(key: String) -> bool:
 return key.begins_with("multiplier:") or "." in key or key in ["weapon_stamina_cost","impact_resistance","dodge_cost","damage_reduction","attack_speed","preparation_bonus","boon_duration_bonus","empower_damage_bonus"]
static func title(key: String) -> String:
 return str(LABELS.get(key.trim_prefix("multiplier:"),key))+ ("加成" if key.begins_with("multiplier:") else "")
static func number(key: String,value: float,signed := false) -> String:
 if key in ["medium_infusion","partial_boon_consumption"]: return "可用" if value>.5 else "无"
 var amount:=value*(100 if percentage(key) else 1)
 var digits: String=("%+.1f" if signed else "%.1f")%amount if key=="weight" else ("%+.0f" if signed else "%.0f")%amount
 return digits+("%" if percentage(key) else " kg" if key=="weight" else "")
static func rows(current: EquipmentData,candidate: EquipmentData) -> Array[Dictionary]:
 var before:=values(current); var after:=values(candidate)
 before.weight=current.weight if current else 0.0; after.weight=candidate.weight
 var keys:=after.keys()
 for key in before:
  if key not in keys: keys.append(key)
 var result: Array[Dictionary]=[]
 for key: String in keys:
  var neutral:=0.0 # Stat multipliers are additive percentages, as in ActorAttributes.
  var a:=float(before.get(key,neutral)); var b:=float(after.get(key,neutral)); var delta:=b-a
  result.append({"key":key,"title":title(key),"before":a,"after":b,"delta":delta,"benefit":delta<0 if key in LOWER else delta>0})
 return result
static func render(host: Node,current: EquipmentData,candidate: EquipmentData,compare: bool) -> void:
 var box:=VBoxContainer.new(); box.name="EquipmentComparison" if compare else "EquipmentStats"
 box.add_theme_constant_override("separation",8); box.set_meta("candidate_id",candidate.id); host.add_child(box)
 if compare:
  var panel:=PanelContainer.new(); var style:=GameUIStyle.surface_style()
  style.bg_color=Color("adb18d0b"); style.set_border_width_all(0); style.border_width_left=2; style.border_color=Color("9cac80")
  panel.add_theme_stylebox_override("panel",style); host.remove_child(box); host.add_child(panel); panel.add_child(box)
  box.add_child(FoundationWidgets.label("对比 "+(current.display_name if current else "空槽"),14))
 for row in rows(current,candidate):
  if not compare and row.key=="weight": continue
  var line:=HBoxContainer.new(); line.set_meta("stat_key",row.key); line.set_meta("before",row.before); line.set_meta("after",row.after); box.add_child(line)
  line.add_child(FoundationWidgets.label(row.title,14))
  var value:=FoundationWidgets.label((number(row.key,row.before)+" → ") if compare else "",14)
  value.text+=number(row.key,row.after); value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; line.add_child(value)
  if compare and not is_zero_approx(row.delta):
   var change:=FoundationWidgets.label(number(row.key,row.delta,true)+(" · 收益" if row.benefit else " · 代价"),12)
   change.add_theme_color_override("font_color",Color("cad8b9") if row.benefit else Color("e5af96")); box.add_child(change)
  box.add_child(HSeparator.new())
 if compare:
  var notes: PackedStringArray=[]
  if current and current.moveset and candidate.moveset and current.moveset.weapon_type!=candidate.moveset.weapon_type:
   notes.append("武器类型：%s → %s；连段随武器改变，武技需满足新武器条件。"%[WeaponMoveset.TITLES.get(current.moveset.weapon_type,current.moveset.weapon_type),WeaponMoveset.TITLES.get(candidate.moveset.weapon_type,candidate.moveset.weapon_type)])
  if candidate.attack_profile and not candidate.attack_profile.ammo_id.is_empty():
   var ammo:=ItemCatalog.default_catalog().definition(candidate.attack_profile.ammo_id)
   notes.append("所需弹药："+(ammo.display_name if ammo else candidate.attack_profile.ammo_id))
  notes.append("涂层留在原武器上，换装不会转移。")
  box.add_child(FoundationWidgets.label("\n".join(notes),12,true))
