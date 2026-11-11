class_name SkillPoolUI
extends CanvasLayer
## Shared loadout editor; real independent action/item shortcuts.

var _skill_pool: SkillPool = null
var _skill_manager: SkillManager = null
var _selected_skill: SkillData = null
var _selected_item: Dictionary={}
var _selected_choice: Dictionary={}
var _navigation: ExpeditionNavigation
var navigation_request: Callable:
	set(value):
		navigation_request=value
		if is_instance_valid(_navigation): _navigation.navigate=value; _navigation.visible=value.is_valid()
var _show_items := false
var _show_techniques := false
var _selected_technique := ""

var _background: ColorRect = null
var _panel: Panel = null
var _skill_grid: GridContainer = null
var _equip_slots: Array[PanelContainer] = []
var _equip_sources: Array[String] = []  ## "left","right","slot_0",...
var _hint_label: Label = null
var _detail_box: VBoxContainer = null


func _ready() -> void:
	layer = GameUIStyle.LAYER_MODAL
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	hide()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if visible and not get_viewport().gui_get_focus_owner() is LineEdit:
		for source in QuickslotLoadout.SOURCES:
			if event.is_action_pressed(InputBindings.action_for_source(source)):
				_bind_to_source(source)
				get_viewport().set_input_as_handled()
				return
	if visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif InputBindings.menu_key(event) == KEY_K:
		if get_tree().paused and not visible:
			return
		toggle()
		get_viewport().set_input_as_handled()


func setup(pool: SkillPool, sm: SkillManager) -> void:
	_skill_pool = pool
	_skill_manager = sm
	sm.binding_changed.connect(_on_binding_changed)
	sm.skill_upgraded.connect(_on_skill_upgraded)


func toggle() -> void:
	if visible: close()
	else: open()


func open() -> void:
	if not GameUIStyle.can_open(self): return
	_refresh_all()
	show()
	GameUIStyle.begin_modal(self)


func open_techniques() -> void:
	_selected_skill=null; _selected_item.clear(); _selected_choice.clear(); _show_items=false; _show_techniques=true; _selected_technique=""
	open()
	_refresh_all()
func open_for(skill: SkillData) -> void:
	_selected_skill=skill; _selected_item.clear(); _selected_choice.clear(); _show_items=false; _show_techniques=false; _selected_technique=""
	open()
	_hint_label.text=InputBindings.menu_help("选择来源后点击目标快捷槽；也可先绑定默认动作，再用G切换。")

func close() -> void:
	_selected_skill = null
	hide()
	GameUIStyle.end_modal(self)


func _build_ui() -> void:
	_background=ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color=GameUIStyle.modal_backdrop(.82)
	add_child(_background)
	_panel=Panel.new()
	_panel.anchor_left=0; _panel.anchor_right=1; _panel.offset_left=16; _panel.offset_right=-16
	_panel.anchor_top=0; _panel.anchor_bottom=1; _panel.offset_top=16; _panel.offset_bottom=-16
	_panel.clip_contents=true
	_panel.add_theme_stylebox_override("panel",_make_panel_bg())
	add_child(_panel)
	GameUIStyle.decorate(_panel)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	_panel.add_child(margin)
	var root:=VBoxContainer.new(); root.add_theme_constant_override("separation",16); margin.add_child(root)
	var header:=HBoxContainer.new(); root.add_child(header)
	GameUIStyle.folio_title(header,"技法与快捷编组")
	var close_button:=FoundationWidgets.button("关闭",close); close_button.size_flags_horizontal=Control.SIZE_SHRINK_END; header.add_child(close_button)
	_navigation=GameUIStyle.navigation(root,"loadout",navigation_request)
	var content:=HBoxContainer.new(); content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12); root.add_child(content)
	var library:=VBoxContainer.new(); library.size_flags_horizontal=Control.SIZE_EXPAND_FILL; library.custom_minimum_size.x=250
	content.add_child(library)
	var tabs:=HBoxContainer.new(); library.add_child(tabs)
	for pair in [["基础动作",0],["可用物品",1],["武技",2]]:
		var button:=FoundationWidgets.button(pair[0],func(): _show_items=pair[1]==1; _show_techniques=pair[1]==2; _selected_technique=""; _selected_skill=null; _selected_item.clear(); _selected_choice.clear(); _refresh_all())
		tabs.add_child(button)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	library.add_child(scroll)
	_skill_grid=GridContainer.new(); _skill_grid.columns=2; _skill_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_skill_grid.add_theme_constant_override("h_separation",8); _skill_grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(_skill_grid)
	var detail_scroll:=ScrollContainer.new(); detail_scroll.custom_minimum_size.x=230
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_child(detail_scroll)
	_detail_box=VBoxContainer.new(); _detail_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation",12); detail_scroll.add_child(_detail_box)
	var slots_scroll:=ScrollContainer.new(); slots_scroll.custom_minimum_size.x=210
	slots_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(slots_scroll)
	var slots:=VBoxContainer.new(); slots.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation",5); slots_scroll.add_child(slots)
	slots.add_child(_make_section_label("选择目标快捷键"))
	for source in QuickslotLoadout.COMBAT_SOURCES: _add_equip_slot(slots,source,InputBindings.label(InputBindings.action_for_source(source)))
	slots.add_child(_make_section_label("同样可放动作或物品"))
	for source in QuickslotLoadout.ITEM_SOURCES: _add_equip_slot(slots,source,InputBindings.label(InputBindings.action_for_source(source)))
	_hint_label=Label.new(); GameUIStyle.apply_label(_hint_label,12,GameUIStyle.TEXT_MUTED)
	_hint_label.text="选择内容 → 按快捷键或点击右侧槽位绑定   /   右键清空   /   Esc返回世界"
	_hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint_label)


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	GameUIStyle.apply_section_label(lbl)
	return lbl


func _add_equip_slot(parent: Control, source: String, label: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(198, 48)
	panel.add_theme_stylebox_override("panel", _make_slot_bg())
	panel.set_meta("display_label", label)
	parent.add_child(panel)
	_equip_slots.append(panel)
	_equip_sources.append(source)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.name = "Name"
	GameUIStyle.apply_label(name_lbl, 14, GameUIStyle.TEXT_MAIN)
	name_lbl.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.name = "Sub"
	GameUIStyle.apply_label(sub_lbl, 12, GameUIStyle.TEXT_MUTED)
	sub_lbl.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_lbl.text = label
	info.add_child(sub_lbl)

	for child in panel.find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.gui_input.connect(_on_slot_clicked.bind(source))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_slot_clicked(event: InputEvent, source: String) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_bind_to_source(source)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _skill_manager:
			_unequip(source)
			_refresh_all()

func _bind_to_source(source: String) -> void:
	if not _skill_manager: return
	var accepted:=false
	if not _selected_technique.is_empty():
		_hint_label.text="武技在连招栏装备，每个组合最多两招；法术和物品快捷槽不变。"
		return
	elif not _selected_item.is_empty():
		accepted=_skill_manager.shortcuts.bind_item(source,_selected_item.item_id,str(_selected_item.get("uid","")))
		if accepted: _selected_item.clear()
	elif _selected_skill:
		accepted=_equip(source,_selected_skill)
		if accepted: _selected_skill=null
	else:
		_hint_label.text="先在左侧选择要放入这个槽位的内容。"
		return
	_refresh_all()
	if accepted: _hint_label.text="已绑定到 "+InputBindings.labels(InputBindings.action_for_source(source))+" · 世界仍在运行，Esc返回。"


func _equip(source: String, skill: SkillData) -> bool:
	if skill.operation_id=="disperse" and not _selected_choice.is_empty() and _selected_choice.get("uid","").is_empty():
		_hint_label.text="先选择口袋中的具体喷剂。"
		return false
	if skill.combination_only:
		_hint_label.text = _combination_description(skill)
		return false
	if not _skill_manager.knows_action(skill):
		_hint_label.text = "尚未掌握：%s。探索遗迹寻找记录。" % skill.display_name
		return false
	if not _is_skill_unlocked(skill):
		_hint_label.text = "%s 需要 %s Lv.%d" % [skill.display_name, _school_name(skill.school), _unlock_level(skill)]
		return false
	var choice:=_selected_choice.duplicate(true)
	if _skill_manager.material_operations and choice.is_empty():
		if skill.get_id() in ["ignite","pulse","water_call"]: choice={"payload":"","modifier":"","uid":""}
		else:
			var operation:=SpellOperationCatalog.default_catalog().operation(skill.operation_id)
			if operation and _skill_manager.spell_forms.supports(skill): choice={"mode":"auto"}
			elif operation and not operation.default_payload.is_empty(): choice={"payload":operation.default_payload,"modifier":"","uid":""}
	return _skill_manager.equip_source(source,skill,choice)

func _unequip(source: String) -> void:
	_skill_manager.shortcuts.clear(source)

func _on_binding_changed(_source: String) -> void:
	_refresh_equip_slots()


func _on_skill_upgraded(_source: String, _skill: SkillData, _upgrade_id: String, _rank: int) -> void:
	if visible: _refresh_all()


## ── 刷新 ──

func _refresh_all() -> void:
	_refresh_grid()
	_refresh_equip_slots()
	_refresh_detail()


func _refresh_detail() -> void:
	if not _detail_box:
		return
	for child in _detail_box.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = _selected_skill.display_name if _selected_skill else "快捷项详情"
	GameUIStyle.apply_label(heading, 16, GameUIStyle.GOLD)
	_detail_box.add_child(heading)
	if not _selected_technique.is_empty():
		var data:=MartialArts.definition(_selected_technique)
		_detail_box.add_child(FoundationWidgets.label(data.art_description(InputBindings.label("weapon_art")),12,true))
		heading.text=data.title
		_detail_box.add_child(FoundationWidgets.label(data.description+"\n体力 %.0f · 冷却 %.0f秒。每个组合最多装备两招，轻点Ctrl切换；Ctrl+左键发动，长按重发，Shift显式释放附魔。"%[data.profile.stamina_cost,data.cooldown],12,true))
		var actor:=_skill_manager.get_parent() as Player
		for route in data.art_routes:
			var reference:=data.id+"/"+route.id
			var group:=MartialArts.route_group(data,route)
			var slots:=actor.actor_context.martial.route_slots(group)
			var title: String=data.title if route.form==MartialRoute.Form.BASE else data.followup_profile.title
			_detail_box.add_child(FoundationWidgets.label(route.describe()+" → "+title,12,true))
			var row:=HBoxContainer.new(); _detail_box.add_child(row)
			if reference in slots:
				row.add_child(FoundationWidgets.button("连招槽%d · 已装备"%(slots.find(reference)+1),Callable(),true))
				row.add_child(FoundationWidgets.button("移除此招",_configure_route.bind(group,slots.find(reference),"")))
			else:
				for index in range(2): row.add_child(FoundationWidgets.button("装备到连招槽%d"%(index+1),_configure_route.bind(group,index,reference),index>slots.size()))
		return
	if not _selected_item.is_empty():
		var view:=QuickslotView.item_state(_skill_manager.get_parent(),_selected_item)
		heading.text=view.title
		_detail_box.add_child(FoundationWidgets.label(view.detail+"\n点击右侧任一快捷槽绑定；右键清空。",11,true))
		return
	if not _selected_skill:
		var empty := Label.new()
		empty.text = "动作与物品：选择真实来源，再点击右侧快捷槽。E与1独立。\n\n武技：按连招配置，每个组合最多两招；轻点Ctrl切换，Ctrl+左键发动。"
		empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		GameUIStyle.apply_label(empty, 10, GameUIStyle.TEXT_MUTED)
		_detail_box.add_child(empty)
		return
	if _skill_manager.material_operations and _selected_skill.get_id() in ["ignite","pulse","water_call"]:
		var modifiers:=OptionButton.new(); modifiers.fit_to_longest_item=false
		var ids:=QuickslotMaterials.modifier_ids(_skill_manager,_selected_skill)
		for id in ids:
			modifiers.add_item("不加额外材料" if id.is_empty() else "修饰："+_skill_manager.combinations.supplies.title(id))
			if _selected_choice.get("modifier","")==id: modifiers.select(modifiers.item_count-1)
		modifiers.item_selected.connect(func(index: int): _selected_choice={"payload":"","modifier":ids[index],"uid":""})
		_detail_box.add_child(modifiers)
	if not _selected_skill.operation_id.is_empty():
		var operation:=SpellOperationCatalog.default_catalog().operation(_selected_skill.operation_id)
		var choices:=OptionButton.new(); choices.fit_to_longest_item=false; choices.clip_text=true
		choices.add_item("智能跟随最近施法元素" if _skill_manager.spell_forms.supports(_selected_skill) else "动作默认来源（G按槽切换）")
		for payload in operation.payloads:
			choices.add_item(payload.title)
			if _selected_choice.get("payload","")==payload.id: choices.select(choices.item_count-1)
		choices.item_selected.connect(func(index: int):
			_selected_choice=({"mode":"auto"} if _skill_manager.spell_forms.supports(_selected_skill) else {}) if index==0 else {"payload":operation.payloads[index-1].id,"modifier":"","uid":""}
			_refresh_detail())
		_detail_box.add_child(choices)
		if not _selected_choice.is_empty() and _selected_choice.get("mode","")!="auto":
			var payload:=operation.payload(str(_selected_choice.payload))
			if operation.action.operation_id=="disperse":
				var bottles:=OptionButton.new(); bottles.fit_to_longest_item=false
				bottles.add_item("选择具体喷剂（需在口袋）")
				var bottle_uids: Array[String]=[""]
				var store: InventoryService=_skill_manager.combinations.supplies.inventory_store
				if store:
					for row in store.entries(_skill_manager.combinations.supplies.actor_id+".pocket"):
						if row.definition!=payload.material_id: continue
						bottle_uids.append(row.uid); bottles.add_item("瓶 "+str(row.uid).trim_prefix("item.")+" · "+store.state_text(row.uid))
						if _selected_choice.get("uid","")==row.uid: bottles.select(bottles.item_count-1)
				bottles.item_selected.connect(func(index: int): _selected_choice["uid"]=bottle_uids[index])
				_detail_box.add_child(bottles)
			var modifiers:=OptionButton.new(); modifiers.fit_to_longest_item=false; modifiers.clip_text=true
			modifiers.add_item("修饰：不额外加材料")
			var modifier_ids: Array[String]=[""]
			var composed:=operation.compose(payload)
			for material: CastingMaterialData in _skill_manager.combinations.supplies.catalog.values():
				if material.supports(_selected_skill.get_id(),operation.modifier_result_id(payload,composed),composed):
					modifier_ids.append(material.id); modifiers.add_item("修饰："+material.title+" ×1")
					if _selected_choice.get("modifier","")==material.id: modifiers.select(modifiers.item_count-1)
			modifiers.item_selected.connect(func(index: int): _selected_choice["modifier"]=modifier_ids[index])
			_detail_box.add_child(modifiers)
			var source_hint: String="脚下"+FireSigil.title_for(payload.source_field) if payload.source_kind=="field" else "附近真实残魂" if payload.source_kind=="soul" else ""
			_detail_box.add_child(FoundationWidgets.label(payload.describe(_skill_manager.get_parent().actor_context.rules.timed_fields if _skill_manager.get_parent().get("actor_context") else false)+"\n必需来源："+(source_hint if not source_hint.is_empty() else "无额外场地来源")+"\n实物："+(_skill_manager.combinations.supplies.title(payload.material_id)+" ×"+str(payload.quantity) if not payload.material_id.is_empty() else "不消耗材料")+"\n绑定后固定此来源；不自动准备条件或串联动作。",11,true))
	if not _is_skill_unlocked(_selected_skill):
		var locked := Label.new()
		locked.text = "未解锁 · %s Lv.%d" % [_school_name(_selected_skill.school), _unlock_level(_selected_skill)]
		if _skill_manager and not _skill_manager.knows_action(_selected_skill):
			locked.text = "尚未掌握 · 探索寻找技能记录"
		if _selected_skill.combination_only:
			locked.text = _combination_description(_selected_skill)
		GameUIStyle.apply_label(locked, 10, Color(0.94, 0.5, 0.32, 1.0))
		_detail_box.add_child(locked)
	var desc := Label.new()
	desc.text = _selected_skill.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(desc, 10, GameUIStyle.TEXT_MAIN)
	_detail_box.add_child(desc)
	var stats := Label.new()
	stats.text = _format_skill_stats(_selected_skill)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(stats, 10, GameUIStyle.TEXT_MUTED)
	_detail_box.add_child(stats)
	if not _selected_skill.mechanics.is_empty():
		var mechanics := Label.new()
		mechanics.text = _selected_skill.mechanics
		mechanics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		GameUIStyle.apply_label(mechanics, 10, Color(0.64, 0.82, 0.92, 1.0))
		_detail_box.add_child(mechanics)
	var build := Label.new()
	var branches: Array[String] = []
	for upgrade in _selected_skill.upgrades:
		if upgrade:
			branches.append(str(upgrade.get("branch")))
	var synergy_names: Array[String] = []
	for synergy in _selected_skill.synergies:
		if synergy:
			synergy_names.append(str(synergy.get("display_name")))
	build.text = "强化: %s\n联动: %s" % [", ".join(branches), ", ".join(synergy_names) if not synergy_names.is_empty() else "无"]
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(build, 9, GameUIStyle.TEXT_MUTED)
	_detail_box.add_child(build)


func _format_skill_stats(skill: SkillData) -> String:
	if not skill.operation_id.is_empty():
		return InputBindings.menu_help("G轮盘按快捷槽选择来源，查看实际费用与条件。\n蓄力/引导按住所编组键，其余按设置按下或松开施放。")
	var lines: Array[String] = [
		"%s · %s" % [_type_name(skill.skill_type), skill.role],
		"伤害 %d  |  法力 %d  |  冷却 %.1fs" % [skill.damage, skill.mp_cost, skill.cooldown],
	]
	match skill.skill_type:
		SkillData.SkillType.PROJECTILE:
			lines.append("弹速 %.0f  |  数量 %d  |  穿透 %d" % [skill.projectile_speed, skill.projectile_count, skill.projectile_pierce])
		SkillData.SkillType.AOE:
			var radius := skill.aoe_visual.radius if skill.aoe_visual else skill.aoe_radius
			var lifetime := skill.aoe_visual.lifetime if skill.aoe_visual else skill.aoe_lifetime
			lines.append("半径 %.0f  |  持续 %.1fs  |  命中 %d" % [radius, lifetime, skill.aoe_max_hits_per_target])
		SkillData.SkillType.BUFF:
			lines.append("持续 %.1fs" % skill.buff_duration)
		SkillData.SkillType.DASH:
			lines.append("距离 %.0f  |  速度 %.0f" % [skill.dash_distance, skill.dash_speed])
		SkillData.SkillType.SUMMON:
			if skill.summon_data:
				lines.append("召唤生命 %d  |  伤害 %d  |  存在 %.0fs" % [skill.summon_data.max_hp, skill.summon_data.damage, skill.summon_data.lifetime])
	return "\n".join(lines)


func _refresh_grid() -> void:
	for child in _skill_grid.get_children():
		child.queue_free()
	_skill_grid.columns=2
	if _show_techniques:
		_refresh_techniques(); return
	if _show_items:
		_refresh_items(); return
	if not _skill_pool: return
	for skill in _skill_pool.skills:
		if not skill: continue
		if _skill_manager.material_operations and (skill.combination_only or _skill_manager.canonical_action(skill)!=skill): continue
		if _skill_manager.restrict_actions and not _skill_manager.knows_action(skill):
			var visible_result := false
			for rule in _skill_manager.combinations.rules:
				if rule.result_skill.get_id() == skill.get_id() and _skill_manager.combinations.learned_rules.has(rule.id):
					visible_result = true
			if not visible_result:
				continue
		var card := _make_skill_card(skill)
		_skill_grid.add_child(card)


func _make_skill_card(skill: SkillData) -> PanelContainer:
	var unlocked := _is_skill_unlocked(skill)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(116, 112)
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_bg(skill == _selected_skill))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.texture = InterfaceIcons.skill(skill)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if unlocked else Color(0.34, 0.36, 0.4, 0.78)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var nm := Label.new()
	nm.text = skill.display_name
	GameUIStyle.apply_label(nm, 14, GameUIStyle.TEXT_MAIN)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(nm)

	var tp := Label.new()
	tp.text = "基础 %d MP"%skill.mp_cost+(" · %.1f秒冷却"%skill.cooldown if skill.cooldown>0 else "") if unlocked else "%s Lv.%d"%[_school_name(skill.school),_unlock_level(skill)]
	if not skill.operation_id.is_empty():
		tp.text="选来源 · G"
	elif skill.combination_only:
		tp.text = "组合结果"
	tp.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tp.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_font_size(tp,12)
	tp.add_theme_color_override("font_color", GameUIStyle.TEXT_MUTED if unlocked else GameUIStyle.GOLD)
	tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tp)

	for child in card.find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.gui_input.connect(_on_card_clicked.bind(skill))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "%s\n%s\n%s" % [skill.description, skill.mechanics, "已解锁" if unlocked else "%s Lv.%d 解锁" % [_school_name(skill.school), _unlock_level(skill)]]
	if skill.combination_only:
		card.tooltip_text = skill.description
	return card


func _on_card_clicked(event: InputEvent, skill: SkillData) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected_skill = skill
		_selected_item.clear(); _selected_choice.clear()
		_refresh_all()


func _refresh_equip_slots() -> void:
	for i in range(_equip_sources.size()):
		var src := _equip_sources[i]
		var panel := _equip_slots[i]
		var skill: SkillData = null
		var inst: SkillInstance = null
		inst = _skill_manager.get_instance(src)
		if inst:
			skill = inst.data

		var hbox := panel.get_child(0) as HBoxContainer
		var tex := hbox.get_node("Icon") as TextureRect
		var vbox := hbox.get_child(1) as VBoxContainer
		var name_lbl := vbox.get_node("Name") as Label
		var sub_lbl := vbox.get_node("Sub") as Label
		var action:=InputBindings.action_for_source(src)
		var display_label := "快捷键 "+InputBindings.labels(action)

		if skill:
			var skill_icon := InterfaceIcons.skill(skill)
			if skill_icon: tex.texture = skill_icon; tex.modulate = Color(1,1,1,1)
			else: tex.texture = null; tex.modulate = Color(1,1,1,0.3)
			name_lbl.text = skill.display_name
			var total_ranks := 0
			for rank in inst.upgrade_ranks.values():
				total_ranks += int(rank)
			var choice:=_skill_manager.shortcuts.selection(src)
			var operation:=SpellOperationCatalog.default_catalog().operation(skill.operation_id)
			var payload:=operation.payload(str(choice.get("payload",""))) if operation else null
			sub_lbl.text=display_label+(" · 固定"+payload.title if payload else " · 跟随G" if operation else " · 动作")+(" · 强化%d"%total_ranks if total_ranks>0 else "")
		elif _skill_manager.shortcuts.binding(src).get("kind","")=="technique":
			var data:=MartialArts.definition(_skill_manager.shortcuts.binding(src).technique_id)
			tex.texture=GameUIStyle.icon("swords"); tex.modulate=Color.WHITE
			name_lbl.text=data.title; sub_lbl.text=display_label+" · 武技"
			panel.tooltip_text=data.description
		elif _skill_manager.shortcuts.binding(src).get("kind","")=="item":
			var view:=QuickslotView.item_state(_skill_manager.get_parent(),_skill_manager.shortcuts.binding(src))
			tex.texture=view.icon; tex.modulate=Color.WHITE
			name_lbl.text=view.title+" ×%d"%view.count
			sub_lbl.text=display_label+" · 物品"
			panel.tooltip_text=view.detail
		else:
			tex.texture = null; tex.modulate = Color(1,1,1,0.1)
			name_lbl.text = "空"
			sub_lbl.text = display_label

		if _selected_skill and skill and skill.get_id() == _selected_skill.get_id():
			panel.add_theme_stylebox_override("panel", _make_slot_bg(Color(0.3, 0.5, 0.3)))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_bg())


## ── 样式 ──

func _make_panel_bg() -> StyleBoxFlat:
	return GameUIStyle.panel_style(0.985, 6, GameUIStyle.BORDER_STRONG, 1)


func _make_card_bg(selected: bool = false) -> StyleBoxFlat:
	return GameUIStyle.surface_style(selected, 4)


func _make_slot_bg(color_override := Color(0.12, 0.12, 0.18, 0.9)) -> StyleBoxFlat:
	var sb := GameUIStyle.surface_style(false, 4)
	if color_override != Color(0.12, 0.12, 0.18, 0.9):
		sb.bg_color = GameUIStyle.SURFACE_RAISED
		sb.border_color = GameUIStyle.ACCENT
		sb.border_width_left=2
	return sb


func _type_name(t: int) -> String:
	match t:
		SkillData.SkillType.PROJECTILE: return "投射"
		SkillData.SkillType.BUFF:       return "增益"
		SkillData.SkillType.AOE:        return "范围"
		SkillData.SkillType.DASH:       return "位移"
		SkillData.SkillType.SUMMON:     return "召唤"
	return "法术"


func _combination_description(skill: SkillData) -> String:
	if _skill_manager and _skill_manager.combinations:
		for rule in _skill_manager.combinations.rules:
			if rule.result_skill.get_id() == skill.get_id():
				var trigger: SkillData = _skill_pool.get_skill(rule.trigger_action_id)
				return "组合结果：%s + %s → %s" % [rule.condition_label(), trigger.display_name if trigger else rule.trigger_action_id, skill.display_name]
	return "组合结果，不能直接装备"

func _is_skill_unlocked(skill: SkillData) -> bool:
	if _skill_manager and not _skill_manager.knows_action(skill):
		return false
	if skill.combination_only:
		return false
	var player := get_tree().get_first_node_in_group("player") as Player
	return not player or not player.mastery_manager or player.mastery_manager.is_spell_unlocked(skill)


func _unlock_level(skill: SkillData) -> int:
	var player := get_tree().get_first_node_in_group("player") as Player
	return player.mastery_manager.get_spell_unlock_level(skill) if player and player.mastery_manager else 1


func _school_name(school: int) -> String:
	match school:
		SkillMastery.School.DESTRUCTION: return "毁灭"
		SkillMastery.School.CONJURATION: return "召唤"
		SkillMastery.School.RESTORATION: return "恢复"
		SkillMastery.School.ALTERATION: return "变化"
		SkillMastery.School.ILLUSION: return "幻术"
	return "精通"


func _type_color(t: int) -> Color:
	match t:
		SkillData.SkillType.PROJECTILE: return Color(1.0, 0.5, 0.3)
		SkillData.SkillType.BUFF:       return Color(0.3, 0.7, 1.0)
		SkillData.SkillType.AOE:        return Color(1.0, 0.3, 0.3)
		SkillData.SkillType.DASH:       return Color(0.3, 1.0, 0.5)
		SkillData.SkillType.SUMMON:     return Color(0.7, 0.4, 1.0)
	return Color.GRAY

func _refresh_items() -> void:
	var actor:=_skill_manager.get_parent() as Player
	if not actor or not actor.actor_context: return
	var store:=actor.actor_context.items
	for source in store.actor_containers(actor.actor_context.id)+[actor.actor_context.id+".gear"]:
		for row in store.entries(source):
			var definition:=store.definitions.get(row.definition) as ItemData
			if not definition or not (definition is EquipmentData or definition.use_profile or SurvivalCatalog.FOODS.has(definition.id)): continue
			var uid: String=row.uid if definition is EquipmentData or definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else ""
			var binding: Dictionary={"kind":"item","item_id":definition.id,"uid":uid}
			var card:=PanelContainer.new(); card.custom_minimum_size=Vector2(132,92)
			card.add_theme_stylebox_override("panel",_make_slot_bg())
			var box:=VBoxContainer.new(); card.add_child(box)
			box.add_child(FoundationWidgets.label(definition.display_name,13))
			box.add_child(FoundationWidgets.label(("口袋" if source.ends_with(".pocket") else "装备" if source.ends_with(".gear") else "背包")+" · ×%d"%row.quantity+" "+store.state_text(row.uid),11,true))
			for child in card.find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
			card.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
					_selected_item=binding; _selected_skill=null; _selected_choice.clear(); _refresh_detail())
			_skill_grid.add_child(card)

func _refresh_techniques() -> void:
	if not _skill_manager: return
	var actor:=_skill_manager.get_parent() as Player
	if not actor or not actor.actor_context: return
	_skill_grid.columns=1
	for id in MartialArts.IDS:
		var data:=MartialArts.definition(id)
		var known: bool=actor.actor_context.martial.learned.has(id)
		var button:=FoundationWidgets.button(data.title+(" · 已学" if known else " · 训练师或武技书"),_select_technique.bind(id),not known)
		_skill_grid.add_child(button)
func _select_technique(id: String) -> void:
	_selected_skill=null; _selected_item.clear(); _selected_choice.clear(); _selected_technique=id
	_refresh_detail()
func _configure_route(group: String,index: int,reference: String) -> void:
	var actor:=_skill_manager.get_parent() as Player
	var accepted:=actor.actor_context.martial.remove_route(group,index) if reference.is_empty() else actor.actor_context.martial.equip_route(reference,index)
	_hint_label.text="连招配置已更新；同组合最多两招。" if accepted else "无法配置这条连招路线。"
	if accepted:
		_skill_manager.binding_changed.emit("martial_routes")
	_refresh_detail()
