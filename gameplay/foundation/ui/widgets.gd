class_name FoundationWidgets
extends RefCounted
static func label(text: String, size := 14, muted := false) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_label(node,size,GameUIStyle.TEXT_MUTED if muted else GameUIStyle.TEXT_MAIN)
	return node
static func button(text: String, action: Callable, disabled := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 38
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.disabled = disabled
	node.tooltip_text = text
	GameUIStyle.apply_button(node)
	if action.is_valid(): node.pressed.connect(action)
	return node
static func card(host: Node, title: String, subtitle := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.36))
	host.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	box.add_child(label(title,20))
	if not subtitle.is_empty(): box.add_child(label(subtitle,13,true))
	return box
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
static func comparison(current: EquipmentData, candidate: EquipmentData) -> String:
	var labels := {"impact_bonus":"武器冲击加值","weapon_stamina_cost":"武器体力费用","impact_resistance":"冲击抵抗","stamina_recovery":"体力每秒回复","dodge_cost":"闪避体力费用","attack_damage":"近战攻击","strength":"力量","intelligence":"智力","endurance":"耐力","agility":"敏捷","move_speed":"移动速度","damage_reduction":"受伤减免","damage.fire":"火焰伤害","mana_cost.all":"法力费用","preparation_bonus":"准备时间","partial_boon_mana_cost":"部分消费额外MP","field_radius_bonus":"法阵半径","field_duration_bonus":"法阵持续秒数","soul_capacity_bonus":"残魂容量","soul_range_bonus":"汲魂范围","boon_duration_bonus":"恩赐持续时间","empower_damage_bonus":"释放伤害倍率","empower_mana_bonus":"释放额外法力","medium_infusion_cost":"介质灌注法力","partial_boon_damage_multiplier":"保留伤害倍率","medium_infusion_enabled":"介质灌注","partial_boon_enabled":"部分消费","hp_regen":"生命回复","max_hp":"生命上限","mp_regen":"法力回复","attack_speed":"攻击速度"}
	var before := {}
	var after := {}
	for pair in [[current,before],[candidate,after]]:
		var item := pair[0] as EquipmentData
		if not item: continue
		pair[1].merge(item.get_combined_stat_modifiers())
		pair[1].merge(item.get_combined_combat_modifiers())
		if item.casting_profile:
			for key in CastingEquipmentProfile.KEYS:
				if item.casting_profile.get(key) != 0: pair[1][key] = item.casting_profile.get(key)
	if current and current.casting_profile:
		before["medium_infusion"]=current.casting_profile.medium_infusion
		before["partial_boon_consumption"]=current.casting_profile.partial_boon_consumption
	if candidate and candidate.casting_profile:
		after["medium_infusion"]=candidate.casting_profile.medium_infusion
		after["partial_boon_consumption"]=candidate.casting_profile.partial_boon_consumption
	var keys := before.keys()
	for key in after:
		if key not in keys: keys.append(key)
	var old_weight:=current.weight if current else 0.0
	var weight_delta:=candidate.weight-old_weight
	var text := "同槽效果对照：当前 → 候选（变化）\n重量   %.1f → %.1f kg  (%+.1f kg · %s)\n"%[old_weight,candidate.weight,weight_delta,"更轻" if weight_delta<0 else "更重" if weight_delta>0 else "不变"]
	if current and current.moveset and candidate.moveset and current.moveset.weapon_type!=candidate.moveset.weapon_type:
		text+="武器类型：%s → %s；改用新连段，武技重新验证武器条件。\n"%[WeaponMoveset.TITLES.get(current.moveset.weapon_type,current.moveset.weapon_type),WeaponMoveset.TITLES.get(candidate.moveset.weapon_type,candidate.moveset.weapon_type)]
	if candidate.attack_profile and not candidate.attack_profile.ammo_id.is_empty():
		var ammo:=ItemCatalog.default_catalog().definition(candidate.attack_profile.ammo_id)
		text+="弹药：%s · 消耗真实实物。\n"%(ammo.display_name if ammo else candidate.attack_profile.ammo_id)
	text+="只读装备定义；不换装，不转移原武器涂层。\n"
	for key in keys:
		if key in ["medium_infusion","partial_boon_consumption"]:
			if bool(before.get(key,false)) or bool(after.get(key,false)):
				text+="%s   %s → %s\n"%["借阵灌注" if key=="medium_infusion" else "部分消费恩赐","启用" if before.get(key,false) else "无","启用" if after.get(key,false) else "无"]
			continue
		var a := float(before.get(key,0))
		var b := float(after.get(key,0))
		var percentage: bool = "." in key or key in ["weapon_stamina_cost","impact_resistance","dodge_cost","damage_reduction","attack_speed","preparation_bonus","boon_duration_bonus","empower_damage_bonus"]
		var factor := 100.0 if percentage else 1.0
		var suffix := "%" if percentage else ""
		var lower_cost: bool=key in ["weapon_stamina_cost","dodge_cost","preparation_bonus","mana_cost.all","partial_boon_mana_cost","empower_mana_bonus","medium_infusion_cost"]
		var impact: String="费用下降" if lower_cost and b<a else "费用上升" if lower_cost and b>a else "变化" if b!=a else "不变"
		text += "%s   %.0f%s → %.0f%s  (%+.0f%s · %s)\n" % [labels.get(key,key),a*factor,suffix,b*factor,suffix,(b-a)*factor,suffix,impact]
	return text+"没有直接属性差异。" if keys.is_empty() else text

static func disclosure(host: Node,title: String,text: String) -> void:
	var button_node:=Button.new(); button_node.text="＋ "+title
	button_node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	GameUIStyle.apply_button(button_node)
	host.add_child(button_node)
	var body:=label(text,14,true); body.visible=false; host.add_child(body)
	button_node.pressed.connect(func(): body.visible=not body.visible; button_node.text=("− " if body.visible else "＋ ")+title)
