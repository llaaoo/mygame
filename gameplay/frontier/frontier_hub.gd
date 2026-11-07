class_name FrontierHub
extends RefCounted
## A single, searchable expedition screen. Domain services own all mutations.
const W := preload("res://gameplay/frontier/frontier_widgets.gd")
const TABS := {"quests":"委托与旅程","equipment":"装备","supplies":"物品与补给","knowledge":"知识","settings":"操作设置"}
var game: GrayriverGame
var page := "quests"
var query := ""
var selected := ""
var loot_id := ""
var filter_index := 0
var _rows: VBoxContainer
var _detail: VBoxContainer
var _search: LineEdit
var _status: Label
var _open := false

func _init(owner_game: GrayriverGame) -> void: game=owner_game
func handle_shortcut(key: int) -> bool:
	var target: String = {KEY_J:"quests",KEY_O:"equipment",KEY_I:"equipment",KEY_N:"supplies",KEY_TAB:"quests"}.get(key,"")
	if target.is_empty(): return false
	if key == KEY_TAB and is_instance_valid(game.ui.modal): return false
	if is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("frontier_page","")==target:
		game.ui.close_modal()
		_open=false
	else: open(target)
	return true

func open(tab := "quests", source := "") -> void:
	page=tab
	loot_id=source
	query=""
	selected=""
	filter_index=0
	_open=true
	var root:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	var tabs:=root.tabs
	for key in TABS:
		var button := W.button(TABS[key],open.bind(key,""))
		button.toggle_mode=true
		button.button_pressed=page == key
		tabs.add_child(button)
	if page == "loot": root.add_child(W.label("遗骸 · 未取走的东西会留在原处。F尽量取走全部；点击选择，Esc关闭。",13,true))
	var tools:=root.tools
	_search=root.search
	_search.text_changed.connect(func(value: String): query=value; _refresh_rows())
	if page in ["equipment","supplies","quests"]:
		var filter := OptionButton.new()
		var choices: Array = ["全部","持有","已装备","武器","防具","饰物"] if page == "equipment" else ["全部","可使用","材料"] if page == "supplies" else ["进行中","可交付","已完成","全部"]
		for title in choices: filter.add_item(title)
		filter.item_selected.connect(func(index: int): filter_index=index; _refresh_rows())
		tools.add_child(filter)
	_status=root.status
	GameUIStyle.apply_label(_status,12,GameUIStyle.TEXT_MUTED)
	_rows=root.rows
	_detail=root.detail
	if page == "loot":
		root.add_child(W.button("F  尽量全部取走",take_all))
	game.ui.show_view("灰河谷  /  "+("战利品" if page == "loot" else TABS.get(page,"旅程")),root)
	game.ui.modal.set_meta("frontier_page",page)
	_refresh_rows()

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match page:
		"equipment":
			for id in game.catalog.equipment:
				var item: EquipmentData=game.catalog.equipment[id]
				var count:=game.equipment_service.count(id)
				var equipped:=game.equipment_service.manager().get_equipment(item.slot_type)==item
				if filter_index == 1 and count == 0 or filter_index == 2 and not equipped: continue
				if filter_index == 3 and item.slot_type not in [5,6]: continue
				if filter_index == 4 and item.slot_type > 4: continue
				if filter_index == 5 and item.slot_type not in [7,8]: continue
				result.append({"id":id,"title":item.display_name,"text":item.description,"subtitle":("已装备" if equipped else "持有 ×%d"%count if count>0 else "尚未发现")+" · "+EquipmentManager.slot_name(item.slot_type),"icon":item.get_icon_texture()})
		"supplies":
			for id in game.survival.supplies.amounts:
				var count:=game.survival.supplies.count(id)
				if count<=0: continue
				var food: bool=SurvivalCatalog.FOODS.has(id)
				if filter_index == 1 and not food or filter_index == 2 and food: continue
				result.append({"id":id,"title":game.survival.supplies.title(id),"text":"补给" if food else "施法与制造材料","subtitle":"×%d · %s"%[count,"可使用" if food else "材料"]})
		"quests":
			for quest in game.quests:
				var done:=game.progress.claims.has("quest."+quest.id)
				var ready:=quest.is_complete(game.progress) and not done
				if filter_index == 0 and done or filter_index == 1 and not ready or filter_index == 2 and not done: continue
				result.append({"id":quest.id,"title":quest.title,"text":quest.description,"subtitle":("已完成" if done else "可交付" if ready else "%d/%d项"%[quest.objective_count(game.progress),quest.required_claims.size()+quest.required_clears.size()])+(" · 正在追踪" if game.progress.tracked_quest==quest.id else "")})
		"knowledge":
			result.append({"id":"overview","title":"旅程总览与施法资料","text":game.presenter.journal_text(),"subtitle":"地点 · 设施 · 未取战利品"})
			for entry in game.progress.journal: result.append({"id":entry.id,"title":entry.title,"text":entry.text,"subtitle":"亲历记录"})
		"settings":
			result.append({"id":"controls","title":"施法与快捷操作","text":"操作设置","subtitle":"按下施法 / 松开施法"})
		"loot":
			var record: Dictionary=game.progress.loot_records.get(loot_id,{})
			for kind in ["equipment","materials"]:
				for id in record.get(kind,{}):
					var item:=game.catalog.equipment.get(id) as EquipmentData
					result.append({"id":kind+":"+id,"kind":kind,"item":id,"title":item.display_name if item else game.survival.supplies.title(id),"text":item.description if item else "剩余携带物","subtitle":"×%d"%record[kind][id],"icon":item.get_icon_texture() if item else null})
	return result

func _refresh_rows() -> void:
	if not is_instance_valid(_rows): return
	W.clear(_rows)
	var available:=entries().filter(func(entry: Dictionary): return query.is_empty() or query.to_lower() in (entry.title+entry.text).to_lower())
	available.sort_custom(func(a: Dictionary,b: Dictionary): return a.title.naturalnocasecmp_to(b.title)<0)
	_status.text="%d项 · 背包 %d/%d格 · 水囊 %d/%d"%[available.size(),game.player.inventory.capacity-game.player.inventory.empty_slot_count(),game.player.inventory.capacity,SurvivalCatalog.water_count(game.survival.supplies),SurvivalCatalog.WATER_CAPACITY]
	if not available.any(func(entry: Dictionary): return entry.id==selected): selected=available[0].id if not available.is_empty() else ""
	for entry in available:
		var button:=W.button(entry.title+"\n"+entry.subtitle,_select.bind(entry.id))
		button.name="Entry_"+str(entry.id).replace(":","_")
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode=true
		button.button_pressed=entry.id==selected
		button.custom_minimum_size.y=58
		button.clip_text=true
		if entry.get("icon"):
			button.icon=entry.icon
			button.expand_icon=true
			button.add_theme_constant_override("icon_max_width",34)
		_rows.add_child(button)
	if available.is_empty(): _rows.add_child(W.label("没有符合条件的项目。",14,true))
	_show_detail()

func _select(id: String) -> void:
	selected=id
	for child in _rows.get_children():
		if child is Button: child.button_pressed=child.name=="Entry_"+id.replace(":","_")
	_show_detail()

func _show_detail() -> void:
	W.clear(_detail)
	if page=="supplies":
		var needs:=W.card(_detail,game.survival.status_line(),game.survival.timers_line())
		if game.survival.needs.nutrition<=20: needs.add_child(W.label("饱食不足：食物可改善生命回复。",13,true))
		if game.survival.needs.hydration<=20: needs.add_child(W.label("饮水不足：清水可改善法力回复。",13,true))
		if game.survival.needs.fatigue>=60: needs.add_child(W.label("疲劳影响准备：茶或休整可缓解。",13,true))
		needs.add_child(W.button("查看恢复与休整规则",game.survival.show_rules))
		if game.survival.supplies.count("dirty_water")>0: needs.add_child(W.button("倒掉未净化水",game.survival.begin_discard))
	var rows:=entries().filter(func(entry: Dictionary): return entry.id==selected)
	if rows.is_empty():
		_detail.add_child(W.label("选择左侧项目查看详情。",16,true))
		return
	var entry: Dictionary=rows[0]
	var card:=W.card(_detail,entry.title,entry.subtitle)
	card.add_child(W.label(entry.text,14))
	match page:
		"equipment","loot":
			var id: String=entry.get("item",entry.id)
			var item:=game.catalog.equipment.get(id) as EquipmentData
			if item:
				var current:=game.equipment_service.manager().get_equipment(item.slot_type)
				var compare:=W.card(_detail,"与当前装备比较",current.display_name if current else "当前同槽为空")
				compare.add_child(W.label(W.comparison(current,item),13))
				if page=="equipment":
					var reason:=game.equipment_service.change_reason()
					if not reason.is_empty(): _detail.add_child(W.label(reason,13,true))
					_detail.add_child(W.button("卸下装备" if current==item else "装备这件",_change_equipment.bind(id,current==item),not reason.is_empty() or game.equipment_service.count(id)<=0))
					if game.equipment_service.count(id)==0:
						var sources: Dictionary={}
						for region: ExplorationRegionData in game.catalog.regions.values():
							for encounter in region.encounters:
								if encounter.character and encounter.character.equipment.any(func(worn): return worn.id==id): sources[region.title+" · "+encounter.character.title]=true
							for discovery in region.discoveries:
								if id in discovery.equipment: sources[region.title+" · "+discovery.title]=true
						for source in sources: compare.add_child(W.label("线索："+source,12,true))
			if page=="loot": _detail.add_child(W.button("取走这一项",_take_selected.bind(entry.kind,id)))
		"supplies":
			var id: String=entry.id
			var store:=game.session.inventory
			var pocket:=store.count_in("player.pocket",id)
			var packed:=store.count_in("player.pack",id)
			card.add_child(W.label("随身口袋 ×%d · 背包 ×%d\n战斗施法与进食只使用随身口袋。"%[pocket,packed],13,true))
			var reason:=game.equipment_service.change_reason()
			if not reason.is_empty(): card.add_child(W.label(reason,13,true))
			_detail.add_child(W.button("移一份到随身口袋",_repack.bind(id,true),packed==0 or not reason.is_empty()))
			_detail.add_child(W.button("移一份到背包",_repack.bind(id,false),pocket==0 or not reason.is_empty()))
			if SurvivalCatalog.FOODS.has(id):
				var food: Dictionary=SurvivalCatalog.FOODS[id]
				card.add_child(W.label("饱食 %+.0f · 饮水 %+.0f · 疲劳 %+.0f\n持续 %.0f秒"%[food.nutrition,food.hydration,food.fatigue,food.duration],14))
				_detail.add_child(W.button("使用一份",_use_supply.bind(id)))
			elif game.survival.supplies.catalog.has(id): card.add_child(W.label(game.survival.supplies.catalog[id].description,14))
			for operation in SpellOperationCatalog.default_catalog().operations:
				for payload in operation.payloads:
					if payload.material_id!=id: continue
					card.add_child(W.label("用于："+operation.action.display_name+"\n"+payload.describe(),13,true))
					_detail.add_child(W.button("查看释放介质选项",game.workshop.show_action.bind(operation.action),not game.player.skill_manager.knows_action(operation.action)))
			_detail.add_child(W.button("查看本次施法材料",func(): game.workshop.show_materials()))
		"quests":
			var quest: ExplorationQuestData
			for candidate in game.quests:
				if candidate.id==entry.id: quest=candidate
			for id in quest.required_claims:
				var goal:=game.guidance.objective(id)
				card.add_child(W.label(("✓ " if game.progress.claims.has(id) else "○ ")+goal.title,14,game.progress.claims.has(id)))
			for id in quest.required_clears: card.add_child(W.label(("✓ " if game.progress.cleared.has(id) else "○ ")+"处理"+game.catalog.regions[id].title+"的威胁",14))
			card.add_child(W.label("报告奖励：%d属性点"%quest.attribute_points,13,true))
			if not game.progress.claims.has("quest."+quest.id):
				_detail.add_child(W.button("追踪这个委托",_pin.bind(quest.id)))
				_detail.add_child(W.button("在镇中报告",_report.bind(quest),not game.is_at_base() or not quest.is_complete(game.progress)))
		"knowledge":
			_detail.add_child(W.button("查看元素关系与亲历验证",game.ui.elements_requested.emit))
			_detail.add_child(W.button("查看实验路线记录",game.trial_recorder.show_page))
			_detail.add_child(W.button("查看已学制造配方",game.workshop.show_crafts))
		"settings":
			var toggle:=CheckButton.new()
			toggle.text="按下即施放普通基础动作"
			toggle.button_pressed=FrontierControls.quick_cast
			toggle.toggled.connect(func(value: bool):
				if not FrontierControls.set_quick_cast(value): game.ui.notify("本次设置已生效，但未保存到磁盘。"))
			card.add_child(toggle)
			card.add_child(preload("res://gameplay/foundation/ui/binding_editor.tscn").instantiate())
			card.add_child(W.label("关闭时按住预览、松开施放。蓄力与引导仍需按住；Shift只表示显式消费恩赐。每次只执行一个基础动作，不自动组合。\n\nWASD 移动 · 空格闪避 · E交互\n1—6 基础动作 · 7烤饼 · 8清水 · 9茶 · 0炖汤\nTab 远征面板 · J委托 · I/O装备 · N补给 · G地图\nV按住格挡 · Alt冲刺 · Ctrl+左键重击 · B放下背包\n地图滚轮缩放、中键/右键拖动、左键放路标。",14))

func _pin(id: String) -> void:
	game.guidance.pin(id)
	_refresh_rows()
func _report(quest: ExplorationQuestData) -> void:
	if game.progress_service.claim_quest(quest): _refresh_rows()
func _change_equipment(id: String, active: bool) -> void:
	var ok:=game.equipment_service.unequip(game.catalog.equipment[id].slot_type) if active else game.equipment_service.equip(id)
	if not ok: game.ui.notify("无法换装：检查附近威胁与背包空间。")
	_refresh_rows()
func _use_supply(id: String) -> void:
	game.ui.close_modal()
	_open=false
	game.survival.begin_eating(id)
func _take_selected(kind: String, id: String) -> void:
	var taken:=game.loot.take(loot_id,kind,id)
	game.ui.notify("已收好。" if taken>0 else "容量不足或已离开遗骸；物品仍在原处。")
	_refresh_rows()
func take_all() -> void:
	if page!="loot" or not is_instance_valid(game.ui.modal): return
	var taken:=game.loot.take(loot_id)
	game.ui.notify("收好%d件物品，未能携带的留在原处。"%taken if taken>0 else "没有取走物品，检查背包与水囊容量。")
	_refresh_rows()

func _repack(id: String,to_pocket: bool) -> void:
	if not game.equipment_service.change_reason().is_empty(): return
	var store:=game.session.inventory
	if not store.containers["player.pack"].attached:
		game.ui.notify("先拾回背包再整理物品。")
		return
	var source:="player.pack" if to_pocket else "player.pocket"
	var destination:="player.pocket" if to_pocket else "player.pack"
	for row in store.entries(source):
		if row.definition!=id: continue
		var result:=store.commit(store.preview(source,destination,row.uid,1))
		if not result.accepted: game.ui.notify("目标容器没有足够空间。")
		else:
			game.survival.supplies.changed.emit()
			game._save_progress()
		_refresh_rows()
		return
