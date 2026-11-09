class_name FrontierHub
extends RefCounted
## A single, searchable expedition screen. Domain services own all mutations.
const W := preload("res://gameplay/frontier/frontier_widgets.gd")
const TABS := {"actions":"整备与制作","quests":"委托与旅程","equipment":"装备","supplies":"物品与补给","knowledge":"知识","settings":"操作设置"}
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
var journal_page := "quests"
var _contexts: Dictionary={}
func remember_record(id: String) -> void:
	journal_page="knowledge"
	_contexts["knowledge"]={"query":"","selected":id,"filter":0}
func remember_context() -> void:
	_contexts[page]={"query":query,"selected":selected,"filter":filter_index}

func _init(owner_game: GrayriverGame) -> void: game=owner_game
func handle_shortcut(key: int) -> bool:
	if game.ui.modal_locked: return false
	var target: String = {KEY_J:journal_page,KEY_O:"equipment",KEY_I:"inventory",KEY_N:"supplies",KEY_TAB:"actions"}.get(key,"")
	if target.is_empty(): return false
	if key==KEY_TAB and is_instance_valid(game.ui.modal):
		if game.ui.modal.get_meta("frontier_page","").is_empty(): return false
		remember_context(); game.ui.close_modal(); _open=false; return true
	if is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("frontier_page","")==target:
		remember_context(); game.ui.close_modal()
		_open=false
	else: open(target)
	return true

func open(tab := "quests", source := "", resume := false) -> void:
	if game.ui.modal_locked: return
	if tab in ["equipment","supplies","inventory"] and is_instance_valid(game.inventory_screen):
		game.ui.close_modal()
		game.inventory_screen.open("all" if tab=="inventory" else tab)
		return
	if _open and is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("frontier_page","")==page: remember_context()
	page=tab
	if page in ["quests","knowledge"]: journal_page=page
	loot_id=source
	var context: Dictionary=_contexts.get(page,{})
	query=str(context.get("query","")) if resume else ""
	selected=str(context.get("selected",""))
	filter_index=int(context.get("filter",0))
	_open=true
	var root:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	var tabs:=root.tabs
	var sections: Array=["quests","knowledge"] if page in ["quests","knowledge"] else ["actions","settings"]
	if page=="loot": root.get_node("Navigation").hide()
	for key in sections:
		var button := W.button({"actions":"准备清单","quests":"委托记录"}.get(key,TABS[key]),open.bind(key,""))
		button.toggle_mode=true
		button.button_pressed=page == key
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.icon=GameUIStyle.icon({"actions":"anvil","quests":"compass","equipment":"swords","supplies":"backpack","knowledge":"book-open","settings":"settings"}[key])
		button.expand_icon=true; button.add_theme_constant_override("icon_max_width",18)
		GameUIStyle.apply_button(button,GameUIStyle.GOLD,page==key)
		tabs.add_child(button)
	if page == "loot": root.footer.add_child(W.label("遗骸 · 未取走的东西会留在原处。%s尽量取走全部；点击选择，Esc关闭。"%InputBindings.label("loot_all"),13,true))
	var tools:=root.tools
	_search=root.search
	_search.text=query
	_search.text_changed.connect(func(value: String): query=value; _refresh_rows())
	if page in ["equipment","supplies","quests"]:
		var filter := OptionButton.new()
		var choices: Array = ["全部","持有","已装备","武器","防具","饰物"] if page == "equipment" else ["全部","可使用","材料"] if page == "supplies" else ["进行中","可交付","已完成","全部"]
		for title in choices: filter.add_item(title)
		filter.select(filter_index)
		filter.item_selected.connect(func(index: int): filter_index=index; _refresh_rows())
		tools.add_child(filter)
	_status=root.status
	GameUIStyle.apply_label(_status,12,GameUIStyle.TEXT_MUTED)
	_rows=root.rows
	_detail=root.detail
	if page == "loot":
		root.footer.add_child(W.button(InputBindings.label("loot_all")+"  尽量全部取走",take_all))
	game.ui.show_view("战利品" if page=="loot" else TABS.get(page,"旅程"),root,"quests" if page in ["quests","knowledge"] else "actions")
	game.ui.modal.set_meta("frontier_page",page)
	_refresh_rows()

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match page:
		"actions":
			result.append({"id":"loadout","title":"快捷栏编组","text":"用鼠标选择已学动作，再选择Q/E/R或数字槽。E和1是两个独立快捷槽；动作和物品均可绑定。","subtitle":"战斗准备"})
			result.append({"id":"sources","title":"材料与释放来源","text":"选择真实材料、法阵或残魂；选择本身不扣物资，不自动准备组合。","subtitle":"施法准备"})
			result.append({"id":"crafts","title":"制作配方","text":"查看已学配方与原料。到附近施法工作台交互，再用鼠标加工；口袋与背包余量来自同一库存。","subtitle":"营地加工"})
			result.append({"id":"supplies","title":"饮食与背包","text":"用鼠标使用、换装和整理；Q/E/R与1—0均可绑定动作或物品；用鼠标编组后，按对应键使用。","subtitle":"生存整备"})
			var target:=game.player.input_controller.interaction_target(true)
			result.append({"id":"nearby","title":"附近交互","text":"点击与F使用同一交互请求，不远程开启设施。","subtitle":target.title if is_instance_valid(target) and "title" in target else "靠近设施、人物或遗骸"})
		"equipment":
			for id in game.catalog.equipment:
				var item: EquipmentData=game.catalog.equipment[id]
				var count:=game.equipment_service.count(id)
				var equipped:=game.equipment_service.manager().get_equipment(item.slot_type)==item
				if filter_index == 1 and count == 0 or filter_index == 2 and not equipped: continue
				if filter_index == 3 and item.slot_type not in [5,6]: continue
				if filter_index == 4 and item.slot_type > 4: continue
				if filter_index == 5 and item.slot_type not in [7,8]: continue
				var store:=game.session.inventory
				var worn:=store.equipped("player")
				var sources:=store.actor_containers("player"); sources.append("player.gear")
				for source in sources:
					for row in store.entries(source):
						if row.definition!=id: continue
						var active: bool=row.uid in worn.values()
						if filter_index==2 and not active: continue
						result.append({"id":"uid:"+row.uid,"item":id,"uid":row.uid,"equipped":active,"title":item.display_name,"text":item.description,"subtitle":("已装备" if active else "背包")+" · "+EquipmentManager.slot_name(item.slot_type)+" · "+store.state_text(row.uid),"icon":item.get_icon_texture()})
				if count==0: result.append({"id":id,"title":item.display_name,"text":item.description,"subtitle":"尚未发现 · "+EquipmentManager.slot_name(item.slot_type),"icon":item.get_icon_texture()})
		"supplies":
			for id in game.survival.supplies.amounts:
				var count:=game.survival.supplies.count(id)
				if count<=0: continue
				var definition:=game.session.inventory.definitions.get(id) as ItemData
				if definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY: continue
				var food: bool=SurvivalCatalog.FOODS.has(id) or definition!=null and definition.use_profile!=null
				if filter_index == 1 and not food or filter_index == 2 and food: continue
				result.append({"id":id,"title":game.survival.supplies.title(id),"text":"补给" if food else "施法与制造材料","subtitle":"×%d · %s"%[count,"可使用" if food else "材料"]})
			for source in ["player.pocket","player.pack"]:
				if source=="player.pack" and not game.session.inventory.is_attached(source): continue
				for row in game.session.inventory.entries(source):
					var definition:=game.session.inventory.definitions.get(row.definition) as ItemData
					if not definition or not definition.use_profile or definition.use_profile.kind!=ItemUseDefinition.Kind.SPRAY: continue
					result.append({"id":"uid:"+row.uid,"item":row.definition,"uid":row.uid,"title":definition.display_name,"text":definition.description,"subtitle":("口袋 · " if source.ends_with("pocket") else "背包 · ")+game.session.inventory.state_text(row.uid)})
		"quests":
			for quest in game.quests:
				if not quest.available(game.progress): continue
				var stage:=quest.stage(game.progress)
				var done:=stage==ExplorationQuestData.Stage.REPORTED
				var ready:=stage==ExplorationQuestData.Stage.READY
				if filter_index == 0 and done or filter_index == 1 and not ready or filter_index == 2 and not done: continue
				result.append({"id":quest.id,"rank":0 if quest.id==game.progress.tracked_quest else 1 if ready else 2,"title":quest.title,"text":quest.description,"subtitle":("已完成" if done else "可交付" if ready else "%d/%d项"%[quest.objective_count(game.progress),quest.required_claims.size()+quest.required_clears.size()])+(" · 正在追踪" if game.progress.tracked_quest==quest.id else "")})
		"knowledge":
			result.append({"id":"overview","title":"旅程总览与施法资料","text":game.presenter.journal_text(),"subtitle":"地点 · 设施 · 未取战利品"})
			for entry in game.progress.journal: result.append({"id":entry.id,"title":entry.title,"text":game.catalog.record_text(entry,game.progress),"subtitle":"亲历记录"})
		"settings":
			result.append({"id":"controls","title":"施法与快捷操作","text":"操作设置","subtitle":"键位 · 输入偏好"})
			result.append({"id":"animation_demo","title":"动画与素材演示","text":"八方向预览 · 连招实战 · 法阵施法","subtitle":"独立沙盒，不改变正式旅程"})
			result.append({"id":"credits","title":"素材与许可","text":"Puny Characters · Shade · CC0\nKenney Tiny Town · CC0\nLucide Icons · ISC / MIT\nNoto Sans SC · SIL Open Font License 1.1\n\n所有新增素材均可用于商业项目，保留对应许可与署名。","subtitle":"视觉素材来源"})
		"loot":
			if game.progress.loot_records.has(loot_id): result=game.loot.instance_entries(loot_id)
	return result

func _refresh_rows() -> void:
	if not is_instance_valid(_rows): return
	W.clear(_rows)
	var available:=entries().filter(func(entry: Dictionary): return query.is_empty() or query.to_lower() in (entry.title+entry.text).to_lower())
	available.sort_custom(func(a: Dictionary,b: Dictionary):
		if page=="quests" and a.rank!=b.rank: return a.rank<b.rank
		return a.title.naturalnocasecmp_to(b.title)<0)
	_status.text="%d项 · 背包 %d/%d格 · 水囊 %d/%d"%[available.size(),game.player.inventory.capacity-game.player.inventory.empty_slot_count(),game.player.inventory.capacity,SurvivalCatalog.water_count(game.survival.supplies),SurvivalCatalog.WATER_CAPACITY]
	if not available.any(func(entry: Dictionary): return entry.id==selected):
		selected=available[0].id if not available.is_empty() else ""
		if page=="settings" and available.any(func(entry: Dictionary): return entry.id=="controls"): selected="controls"
		if page=="quests" and available.any(func(entry: Dictionary): return entry.id==game.progress.tracked_quest): selected=game.progress.tracked_quest
	for entry in available:
		var button:=W.button(entry.title+"\n"+entry.subtitle,_select.bind(entry.id))
		button.name="Entry_"+str(entry.id).replace(":","_")
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode=true
		button.button_pressed=entry.id==selected
		GameUIStyle.apply_button(button,GameUIStyle.ACCENT,entry.id==selected)
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
	remember_context()
	for child in _rows.get_children():
		if child is Button:
			child.button_pressed=child.name=="Entry_"+id.replace(":","_")
			GameUIStyle.apply_button(child,GameUIStyle.ACCENT,child.button_pressed)
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
		"actions":
			match entry.id:
				"loadout": _detail.add_child(W.button("打开快捷栏编组",_open_loadout))
				"sources": _detail.add_child(W.button("选择释放来源",game.workshop.show_materials))
				"supplies": _detail.add_child(W.button("打开物品与补给",open.bind("supplies","")))
				"crafts":
					var supplies:=game.survival.supplies
					for id in supplies.crafting_recipes:
						if supplies.knows_recipe(id): card.add_child(W.label(supplies.title(id)+" ← "+supplies.describe_cost(supplies.crafting_recipes[id].inputs),13,true))
					var target:=game.player.input_controller.interaction_target(true)
					if target is ExplorationInteractable and target.callback==game.workshop.show_crafts: _detail.add_child(W.button("使用附近工作台",_interact.bind(weakref(target))))
					else: card.add_child(W.label("靠近施法工作台后，可按F或点击屏幕中的交互按钮。",13,true))
				"nearby":
					var target:=game.player.input_controller.interaction_target(true)
					if is_instance_valid(target): _detail.add_child(W.button("使用附近目标",_interact.bind(weakref(target))))
					else: card.add_child(W.label("当前没有足够近的交互目标。",13,true))
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
					_detail.add_child(W.button("卸下装备" if entry.get("equipped",false) else "装备这件",_change_equipment.bind(id,bool(entry.get("equipped",false)),str(entry.get("uid",""))),not reason.is_empty() or game.equipment_service.count(id)<=0))
					if not str(entry.get("uid","")).is_empty(): _binding_picker(id,str(entry.uid))
					if game.equipment_service.count(id)==0:
						var sources: Dictionary={}
						for region: ExplorationRegionData in game.catalog.regions.values():
							for encounter in region.encounters:
								if encounter.character and encounter.character.equipment.any(func(worn): return worn.id==id): sources[region.title+" · "+encounter.character.title]=true
							for discovery in region.discoveries:
								if id in discovery.equipment: sources[region.title+" · "+discovery.title]=true
						for source in sources: compare.add_child(W.label("线索："+source,12,true))
			if page=="loot": _detail.add_child(W.button("取走这一项",_take_selected.bind(entry.kind,id,str(entry.get("uid","")))))
		"supplies":
			var id: String=entry.get("item",entry.id)
			var store:=game.session.inventory
			var pocket:=store.count_in("player.pocket",id)
			var packed:=store.count_in("player.pack",id)
			card.add_child(W.label("随身口袋 ×%d · 背包 ×%d\n战斗施法与进食只使用随身口袋。"%[pocket,packed],13,true))
			var reason:=game.equipment_service.change_reason()
			if not reason.is_empty(): card.add_child(W.label(reason,13,true))
			_detail.add_child(W.button("移一份到随身口袋",_repack.bind(id,true,str(entry.get("uid",""))),packed==0 or not str(entry.get("uid","")).is_empty() and store.locate(entry.uid)!="player.pack" or not reason.is_empty()))
			_detail.add_child(W.button("移一份到背包",_repack.bind(id,false,str(entry.get("uid",""))),pocket==0 or not str(entry.get("uid","")).is_empty() and store.locate(entry.uid)!="player.pocket" or not reason.is_empty()))
			if SurvivalCatalog.FOODS.has(id):
				var food: Dictionary=SurvivalCatalog.FOODS[id]
				card.add_child(W.label("饱食 %+.0f · 饮水 %+.0f · 疲劳 %+.0f\n持续 %.0f秒"%[food.nutrition,food.hydration,food.fatigue,food.duration],14))
				_detail.add_child(W.button("使用一份",_use_supply.bind(id)))
			elif game.survival.supplies.catalog.has(id): card.add_child(W.label(game.survival.supplies.catalog[id].description,14))
			var uses: Array[String]=[]
			var used_operations: Dictionary={}
			for operation in SpellOperationCatalog.default_catalog().operations:
				for payload in operation.payloads:
					if payload.material_id==id:
						uses.append(operation.action.display_name+" · "+payload.title)
						used_operations[operation.action.get_id()]=operation.action
			if not uses.is_empty():
				W.disclosure(_detail,"施法用途 · %d种"%uses.size(),"\n".join(uses))
				for action: SkillData in used_operations.values(): _detail.add_child(W.button("配置"+action.display_name,game.workshop.show_action.bind(action),not game.player.skill_manager.knows_action(action)))
			var definition:=store.definitions.get(id) as ItemData
			if definition and definition.use_profile:
				var use:=definition.use_profile
				if use.kind==ItemUseDefinition.Kind.SPRAY: _detail.add_child(W.button("装填这瓶喷剂",_prepare_sprayer.bind(id,str(entry.get("uid","")))))
				if use.kind!=ItemUseDefinition.Kind.SPRAY: _detail.add_child(W.button("瞄准投掷" if use.kind==ItemUseDefinition.Kind.THROWABLE else "涂附当前主手武器",_use_item.bind(str(entry.get("uid",id)),use.kind==ItemUseDefinition.Kind.THROWABLE)))
			if SurvivalCatalog.FOODS.has(id) or definition and definition.use_profile:
				_binding_picker(id,str(entry.get("uid","")) if definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else "")
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
				_detail.add_child(W.button("在镇中报告",_report.bind(quest),not game.is_at_base() or not quest.can_claim(game.progress,game.player.stats_component)))
		"knowledge":
			_detail.add_child(W.button("查看元素关系与亲历验证",game.ui.elements_requested.emit))
			_detail.add_child(W.button("查看实验路线记录",game.trial_recorder.show_page))
			_detail.add_child(W.button("查看已学制造配方",game.workshop.show_crafts))
		"settings":
			if entry.id=="credits": return
			if entry.id=="animation_demo":
				card.add_child(W.label("原素材八方向与逐帧预览；两组真实规则实战演示。进入前保存正式旅程，演示中的装备、学习和F5/F9仅属于内存沙盒。返回时恢复正式存档。",14))
				card.add_child(W.button("打开动画试验室",_open_animation_demo))
				return
			var toggle:=CheckButton.new()
			toggle.text="按下即施放普通基础动作"
			toggle.button_pressed=FrontierControls.quick_cast
			toggle.toggled.connect(func(value: bool):
				if not FrontierControls.set_quick_cast(value): game.ui.notify("本次设置已生效，但未保存到磁盘。"))
			card.add_child(toggle)
			card.add_child(preload("res://gameplay/foundation/ui/binding_editor.tscn").instantiate())
			card.add_child(W.label("关闭时按住预览、松开施放。蓄力与引导仍需按住；Shift只表示显式消费恩赐。每次只执行一个基础动作，不自动组合。\n\nWASD 移动 · 空格闪避 · F交互\nQ/E/R与1—0 独立快捷槽 · K绑定动作或物品\nTab 远征面板 · J委托 · I行囊 · O穿戴 · N补给 · G地图\n右键按住格挡 · Alt冲刺 · 左键短按轻击、长按重击 · Ctrl+左键武技（可长按） · Ctrl+Shift+左键释放附魔 · B放下背包\n地图滚轮缩放、中键/右键拖动、左键放路标。",14))

func _open_loadout() -> void:
	game.ui.close_modal()
	game.player.skill_pool_ui.open()
func _interact(reference: WeakRef) -> void:
	var target:=reference.get_ref() as Node2D
	if not is_instance_valid(target) or game.player.input_controller.interaction_target(true)!=target:
		game.ui.notify("目标已不在附近。")
		return
	game.ui.close_modal()
	if not game.player.input_controller.request_interaction(target): game.ui.notify("当前无法交互，请结束动作后重试。")
func _pin(id: String) -> void:
	game.guidance.pin(id)
	_refresh_rows()
func _report(quest: ExplorationQuestData) -> void:
	if game.progress_service.claim_quest(quest): _refresh_rows()
func _change_equipment(id: String, active: bool,uid := "") -> void:
	var ok:=game.equipment_service.unequip(game.catalog.equipment[id].slot_type) if active else game.equipment_service.equip(id,uid)
	if not ok: game.ui.notify("无法换装：检查附近威胁与背包空间。")
	_refresh_rows()
func _use_supply(id: String) -> void:
	game.ui.close_modal()
	_open=false
	game.survival.begin_eating(id)
func _take_selected(kind: String, id: String,uid := "") -> void:
	var taken:=game.loot.take(loot_id,kind,id,uid)
	game.ui.notify("已收好。" if taken>0 else "容量不足或已离开遗骸；物品仍在原处。")
	_refresh_rows()
func take_all() -> void:
	if page!="loot" or not is_instance_valid(game.ui.modal): return
	var taken:=game.loot.take(loot_id)
	game.ui.notify("收好%d件物品，未能携带的留在原处。"%taken if taken>0 else "没有取走物品，检查背包与水囊容量。")
	_refresh_rows()

func _repack(id: String,to_pocket: bool,uid := "") -> void:
	if not game.equipment_service.change_reason().is_empty(): return
	var store:=game.session.inventory
	if not store.is_attached("player.pack"):
		game.ui.notify("先拾回背包再整理物品。")
		return
	var source:="player.pack" if to_pocket else "player.pocket"
	var destination:="player.pocket" if to_pocket else "player.pack"
	for row in store.entries(source):
		if row.definition!=id or not uid.is_empty() and row.uid!=uid: continue
		var result:=store.commit(store.preview(source,destination,row.uid,1))
		if not result.accepted: game.ui.notify("目标容器没有足够空间。")
		else:
			game.survival.supplies.changed.emit()
			game._save_progress()
		_refresh_rows()
		return

func _use_item(id: String,aim: bool) -> void:
	game.ui.close_modal()
	game.player.actor_context.actions.input_suppressed=.15
	if not game.player.actor_context.item_actions.begin(id,aim,game.player.get_mouse_direction()): game.ui.notify("无法使用：检查口袋、武器和当前动作。")
func _binding_picker(id: String,uid: String) -> void:
	var row:=HBoxContainer.new(); _detail.add_child(row)
	var picker:=OptionButton.new(); picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for source in QuickslotLoadout.SOURCES: picker.add_item(InputBindings.label(InputBindings.action_for_source(source)))
	row.add_child(picker)
	row.add_child(W.button("绑定所选快捷槽",func():
		var source: String=QuickslotLoadout.SOURCES[picker.selected]
		var ok:=game.player.skill_manager.shortcuts.bind_item(source,id,uid)
		game.ui.notify("已绑定到"+InputBindings.label(InputBindings.action_for_source(source))+"："+game.survival.supplies.title(id) if ok else "无法绑定这件物品。")))

func _prepare_sprayer(id: String,uid: String) -> void:
	if game.session.prepare_sprayer("player",id,uid): game.ui.notify("已选择这瓶喷剂；可编组喷洒，或在K直接把这瓶绑定到快捷槽，按住使用。")

func _open_animation_demo() -> void:
	if game._switching or not game.ready_for_play: return
	game.player.cancel_active_input("打开动画试验室")
	if game.persistence_enabled and not SaveManager.instance.save_game(game.save_slot):
		game.ui.notify("正式旅程未能保存，保留当前游戏。")
		return
	game.get_tree().call_deferred("change_scene_to_file","res://demos/animation_gallery.tscn")
