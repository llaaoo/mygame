class_name TownServices
extends RefCounted
## Chapter adapter: proximity and service presentation. Inventory owns all mutations.
const MERCHANT := "river.merchant"
static var STOCK: Dictionary:
	get: return (load("res://content/frontier/town_market.tres") as MarketDefinition).initial_stock.duplicate()
const ERRORS := {"currency":"付款方河谷币不足。","payment_capacity":"收款方没有空间接收河谷币。","not_owned":"物品已离开原来的容器。","payment_or_capacity":"货币不足，或对方没有空间接收付款。","capacity":"容器空间不足，未扣除物品或货币。","materials":"货币或金属碎料不足。","maximum_level":"已达到最高强化等级。","unequip_first":"请先卸下这件装备，再带来整修。"}
const POINT := Vector2(-3210,2200)
const W := preload("res://gameplay/foundation/ui/widgets.gd")
var game: GrayriverGame
var market: MarketDefinition
var training: TrainingCatalog
var _screen: ExpeditionScreen
var _selling := true
var _selected_uid := ""
var _trade_quantity: SpinBox
var _quantity_value := 1
func service_title(owner_id: String,fallback: String) -> String:
	var profile:=game.session.conversations.catalog.profile(owner_id)
	return profile.character.title if profile else fallback
func _init(owner_game: GrayriverGame,market_profile: MarketDefinition=null,training_profile: TrainingCatalog=null,use_defaults := true) -> void:
	game=owner_game
	market=market_profile if market_profile else (load("res://content/frontier/town_market.tres") as MarketDefinition) if use_defaults else null
	training=training_profile if training_profile else TrainingCatalog.default_catalog() if use_defaults else null
func ensure_stock() -> void:
	if not market: return
	var store:=game.session.inventory
	if game.session.actor_records.get(market.actor_id,{}).get("dead",false): return
	if store.has_container(market.actor_id+".pack"): return
	store.ensure_actor(market.actor_id)
	store.begin_batch()
	for id in market.initial_stock:
		store.receive(market.actor_id,id,int(market.initial_stock[id]),true)
	store.end_batch()
func reason() -> String:
	if not market: return "此人不提供交易与整修。"
	var property_reason:=game.session.law.service_reason(market.actor_id)
	if not property_reason.is_empty():return property_reason
	if game.region_id!=market.region_id or game.player.global_position.distance_to(market.position)>market.service_range: return "请靠近这位店主的交易位置。"
	var social_reason:=game.session.conversations.reason(market.actor_id,true,180)
	if not social_reason.is_empty(): return social_reason
	if game.has_hostiles_near(game.player.global_position) or game.player.actor_context.actions.busy(): return "先结束战斗与动作。"
	return ""
func _base_price(uid: String,buying: bool) -> int:
	if not market: return 0
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item: return 0
	var definition:=store.definitions[item.definition_id] as ItemData
	var base:=maxi(definition.sell_price,8 if definition is EquipmentData else 1)
	base+=clampi(int(item.properties.get("upgrade_level",0)),0,3)*2
	return maxi(base+1,int(ceil(base*1.8))) if buying and game.session.relations.disposition(market.actor_id,"player")>=10 else base*2 if buying else base
func total_price(uid: String,buying: bool,quantity: int) -> int:
	var base:=_base_price(uid,buying)
	var item:=game.session.inventory.item(uid)
	if not item or quantity<1:return 0
	var rule: Dictionary=market.demand.get(item.definition_id,{}) if market else {}
	if buying or rule.is_empty():return base*quantity
	var wanted:=clampi(int(rule.target)-game.session.inventory.count(market.actor_id,item.definition_id),0,quantity)
	return base*quantity+wanted*int(rule.premium)
func price(uid: String,buying: bool) -> int:return total_price(uid,buying,1)
func affordable(uid: String,buying: bool,quantity: int,funds: int) -> int:
	var low:=0;var high:=quantity
	while low<high:
		var middle:=(low+high+1)/2
		if total_price(uid,buying,middle)<=funds:low=middle
		else:high=middle-1
	return low
func transact(uid: String,selling: bool,quantity := 1) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item or item.definition_id=="coin": return OperationResult.reject("不可交易")
	return store.trade_instance(market.actor_id if selling else "player","player" if selling else market.actor_id,uid,quantity,total_price(uid,not selling,quantity))
func preview_trade(uid: String,selling: bool,quantity: int) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	var store:=game.session.inventory
	return store.preview_trade_instance(market.actor_id if selling else "player","player" if selling else market.actor_id,uid,quantity,total_price(uid,not selling,quantity))
func salvage(uid: String,upgrade: bool) -> OperationResult:
	if not market or not market.equipment_services: return OperationResult.reject("此店只提供实物交易，不提供拆解或强化。")
	if not reason().is_empty(): return OperationResult.reject(reason())
	return game.session.inventory.upgrade_instance("player",uid) if upgrade else game.session.inventory.dismantle_instance("player",uid)
func show(selling := true) -> void:
	if not reason().is_empty(): game.ui.notify(reason()); return
	_selling=selling
	_selected_uid=""; _quantity_value=1
	ensure_stock()
	_screen=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	_screen.get_node("Navigation/Caption").text=service_title(market.actor_id,"整修铺")
	_screen.tabs.add_child(W.button("出售 / 拆解 / 强化" if market.equipment_services else "出售实物",show.bind(true)))
	_screen.tabs.add_child(W.button("购买实物",show.bind(false)))
	if market.production_services: _screen.tabs.add_child(W.button("店内排产",show_production))
	_screen.search.text_changed.connect(func(query: String): _rows(query))
	var hint:=W.label(("交易库存有限；装备先卸下再整修。整修保留同一件实物，涂层不会重置。" if market.equipment_services else "交易库存和店家钱袋有限；此店不提供拆解、强化或排产。")+(" 熟客购买减价10%，出售原价。" if game.session.relations.disposition(market.actor_id,"player")>=10 else " 与店主交谈、履行委托可获得熟客买价。"),12,true)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_screen.footer.add_child(hint)
	game.ui.show_view(service_title(market.actor_id,"整修铺"),_screen)
	_rows("")
func _rows(query: String) -> void:
	W.clear(_screen.rows); W.clear(_screen.detail)
	var store:=game.session.inventory
	_screen.status.text="随身河谷币 %d · 店家河谷币 %d · 金属碎料 %d"%[store.count("player","coin"),store.count(market.actor_id,"coin"),store.count("player","metal_scrap")]
	var shown: Array[String]=[]
	var containers:=store.actor_containers("player" if _selling else market.actor_id)
	if _selling: containers.append("player.gear")
	for container in containers:
		for row in store.entries(container):
			var definition:=store.definitions[row.definition] as ItemData
			if row.definition=="coin" or not query.is_empty() and not definition.display_name.contains(query): continue
			var data:=store.equipment_definition(row.uid) if definition is EquipmentData else definition
			shown.append(row.uid)
			var button:=W.button("%s ×%d · %d币"%[data.display_name,row.quantity,price(row.uid,not _selling)]+("\n已穿戴 · 先卸下" if container=="player.gear" else ""),_detail.bind(row.uid))
			button.clip_text=true; button.tooltip_text=button.text; _screen.rows.add_child(button)
	if _selected_uid in shown: _detail(_selected_uid)
	elif not shown.is_empty(): _detail(shown[0])
	else: _selected_uid=""; _screen.detail.add_child(W.label("没有可交易的实物。货币不能出售；放下的背包需先拾回。",14,true))
func _detail(uid: String) -> void:
	W.clear(_screen.detail)
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item: return
	if _selected_uid!=uid: _quantity_value=1
	_selected_uid=uid
	var definition:=store.definitions[item.definition_id] as ItemData
	var data:=store.equipment_definition(uid) if definition is EquipmentData else definition
	_screen.detail.add_child(W.label(data.display_name,22))
	_screen.detail.add_child(W.label(data.description+"\n"+store.state_text(uid),14,true))
	if _selling and market.demand.has(item.definition_id):
		var demand: Dictionary=market.demand[item.definition_id]
		_screen.detail.add_child(W.label("店内需求：目标%d，当前%d；缺额内每件额外%d币，整叠按缺额分段计价。"%[demand.target,store.count(market.actor_id,item.definition_id),demand.premium],14,true))
	var worn:=_selling and store.locate(uid)=="player.gear"
	if worn:
		_screen.detail.add_child(W.label("这件装备仍在身上。先卸下，属性变化和背包空间按正常换装规则检查。",14,true))
		_screen.detail.add_child(W.button("卸下这件装备",_request.bind("unequip",uid)))
	if data is EquipmentData:
		W.disclosure(_screen.detail,"当前装备属性",W.comparison(null,data))
		if data.moveset: W.disclosure(_screen.detail,"武器动作",data.moveset.describe())
	_screen.detail.add_child(W.button(("出售一件" if _selling else "购买一件")+" · %d币"%price(uid,not _selling),_request.bind("trade",uid),not preview_trade(uid,_selling,1).accepted))
	var trade_preview:=preview_trade(uid,_selling,1)
	if not trade_preview.accepted and not worn: _screen.detail.add_child(W.label("无法交易："+str(ERRORS.get(trade_preview.reason,trade_preview.reason)),14,true))
	if item.quantity>1:
		_trade_quantity=SpinBox.new(); _trade_quantity.min_value=1; _trade_quantity.max_value=item.quantity; _trade_quantity.step=1; _trade_quantity.value=mini(_quantity_value,item.quantity)
		_screen.detail.add_child(_trade_quantity)
		var totals:=W.label("",14,true); _screen.detail.add_child(totals)
		var selected_button:=W.button("出售所选数量" if _selling else "购买所选数量",_request.bind("trade_quantity",uid)); _screen.detail.add_child(selected_button)
		var stack_button:=W.button("出售整叠" if _selling else "购买整叠",_request.bind("trade_stack",uid)); _screen.detail.add_child(stack_button)
		var refresh_totals:=func(value: float):
			_quantity_value=int(value)
			var payer:=market.actor_id if _selling else "player"
			var funds:=store.count(payer,"coin")
			var total:=total_price(uid,not _selling,_quantity_value)
			var preview:=preview_trade(uid,_selling,_quantity_value)
			totals.text="总价%d币 · %s持有%d币 · 资金最多%d件"%[total,"店家" if _selling else "你",funds,affordable(uid,not _selling,item.quantity,funds)]
			if funds<total: totals.text+=" · 缺少%d币"%(total-funds)
			elif not preview.accepted: totals.text+=" · "+str(ERRORS.get(preview.reason,preview.reason))
			else: totals.text+=" · 付款后余%d币"%(funds-total)
			selected_button.disabled=not preview.accepted
			stack_button.disabled=not preview_trade(uid,_selling,item.quantity).accepted
		_trade_quantity.value_changed.connect(refresh_totals)
		refresh_totals.call(_trade_quantity.value)
	if _selling and definition is EquipmentData and market.equipment_services:
		var level:=clampi(int(item.properties.get("upgrade_level",0)),0,3)
		var refit:=EquipmentRefit.definition(str(item.properties.get("upgrade_path","balanced")))
		_screen.detail.add_child(W.label(("已固定方向："+refit.title+"\n" if level>0 else "首次可选择方向，之后保持；最高+3。\n")+refit.description,14,true))
		_screen.detail.add_child(W.button("拆解 · 获得%d金属碎料（销毁这件装备）"%store.dismantle_yield("player",uid),_request.bind("dismantle",uid)))
		_screen.detail.add_child(W.button(("强化 · "+game.survival.supplies.describe_cost(store.upgrade_cost("player",uid))) if refit.id!="balanced" else "强化 · %d币 + %d金属碎料"%[store.upgrade_cost("player",uid).coin,store.upgrade_cost("player",uid).metal_scrap],_request.bind("upgrade",uid),level>=3))
		if level==0:
			for path_id in EquipmentRefit.IDS:
				var path:=EquipmentRefit.definition(path_id)
				if path_id=="balanced" or not path.supports(definition):continue
				_screen.detail.add_child(W.label(path.description,13,true))
				_screen.detail.add_child(W.button("定向整修："+path.title+" · "+game.survival.supplies.describe_cost(store.upgrade_cost("player",uid,path_id)),_refit.bind(uid,path_id)))
	for button in _screen.detail.find_children("*","Button",true,false):
		button.clip_text=true; button.tooltip_text=button.text
func _refit(uid: String,path: String) -> void:
	if not reason().is_empty() or not market.equipment_services:return
	var result:=game.session.inventory.upgrade_instance("player",uid,path)
	game.ui.notify("已按所选方向整修；后续三阶内保持该方向。" if result.accepted else result.reason)
	if result.accepted:game._save_progress()
	_rows(_screen.search.text)
func _request(method: String,uid: String) -> void:
	var focused:=_screen.get_viewport().gui_get_focus_owner()
	var focus_text: String=focused.text if focused is Button else ""
	var item:=game.session.inventory.item(uid)
	var quantity:=item.quantity if method=="trade_stack" and item else _quantity_value if method=="trade_quantity" else 1
	var trade:=method.begins_with("trade")
	var result: OperationResult
	if method=="unequip":
		var definition:=game.session.inventory.definitions.get(item.definition_id) as EquipmentData if item else null
		var matching: bool=definition and game.session.inventory.equipped("player").get(str(definition.slot_type),"")==uid
		result=OperationResult.success() if matching and reason().is_empty() and game.equipment_service.unequip(definition.slot_type) else OperationResult.reject("unequip_first")
	else: result=transact(uid,_selling,quantity) if trade else salvage(uid,method=="upgrade")
	game.ui.notify("完成："+("交易 ×%d"%result.moved if trade else {"dismantle":"拆解","upgrade":"强化","unequip":"卸下装备"}[method]) if result.accepted else "未完成："+str(ERRORS.get(result.reason,result.reason)))
	if result.accepted: game._save_progress()
	_rows(_screen.search.text)
	for button in _screen.detail.find_children("*","Button",true,false):
		if not focus_text.is_empty() and button.text==focus_text: button.grab_focus(); break

func show_training() -> void:
	if not training: return
	if not game.session.law.service_reason(training.actor_id).is_empty():game.ui.notify(game.session.law.service_reason(training.actor_id));return
	var npc:=game.session.actor_for_id(training.actor_id)
	if not is_instance_valid(npc) or not game.session.conversations.reason(training.actor_id,true,150).is_empty(): game.ui.notify("请靠近当值的训练师。"); return
	var options: Array[Dictionary]=[]
	for offer in training.offers:
		var data:=offer.technique
		var known: bool=game.player.actor_context.martial.learned.has(data.id)
		var refused:=TechniqueLearning.reason(offer,game.player.actor_context)
		var price_text:=game.player.skill_manager.combinations.supplies.describe_cost(offer.costs)
		if offer.costs.size()==1 and offer.costs.has("coin"): price_text="%d币"%offer.costs.coin
		options.append({"title":data.title+(" · 已学会" if known else " · "+price_text)+(_requirements_hint(offer) if not known else ""),"disabled":not refused.is_empty(),"callback":_teach.bind(offer.id)})
	for id in training.fieldcraft_skills:
		var skill:=FieldcraftCatalog.default_catalog().skill(id)
		var refused:=FieldcraftLearning.reason(skill,game.player.actor_context)
		options.append({"title":"野外技艺："+skill.title+" · "+game.survival.supplies.describe_cost(skill.costs)+("\n"+refused if not refused.is_empty() else ""),"disabled":not refused.is_empty(),"callback":_teach_fieldcraft.bind(skill.id)})
	options.append({"title":"查看武技与连招","callback":_open_techniques})
	options.append({"title":"分配已有属性点","callback":game.presenter._show_training})
	game.ui.show_panel(service_title(training.actor_id,"训练师"),"武技只解锁知识，到K查看连招与配置；使用消耗体力与实物资源。\n\n野外技艺解锁遗骸的专业处理与对应制造配方。先学剥皮，再学取牙或摘腺；作坊留有入门书和小刀。未处理部位会保留，携刀站定作业，留意附近危险。",options)
func _teach(id: String) -> void:
	if not game.session.law.service_reason(training.actor_id).is_empty():return
	var npc:=game.session.actor_for_id(training.actor_id)
	var context:=game.player.actor_context
	var offer:=training.offer(id)
	if not is_instance_valid(npc) or not game.session.conversations.reason(training.actor_id,true,150).is_empty() or not offer: return
	var result:=TechniqueLearning.purchase(offer,context,training.actor_id)
	game.ui.notify("已学会"+offer.technique.title+" · 连招后按"+InputBindings.label("weapon_art")+"发动，K查看条件，无需占快捷槽。" if result.accepted else str(ERRORS.get(result.reason,result.reason)))
	game._save_progress(); show_training()
func _teach_fieldcraft(id: String) -> void:
	if not game.session.law.service_reason(training.actor_id).is_empty():return
	if not training or id not in training.fieldcraft_skills or not is_instance_valid(game.session.actor_for_id(training.actor_id)) or not game.session.conversations.reason(training.actor_id,true,150).is_empty(): return
	var skill:=FieldcraftCatalog.default_catalog().skill(id)
	var result:=FieldcraftLearning.purchase(skill,game.player.actor_context,training.actor_id)
	game.ui.notify("已学会"+skill.title+"；携带小刀，在遗骸详情选择专业处理。" if result.accepted else result.reason)
	game.knowledge_changed();game._save_progress();show_training()
func _open_techniques() -> void:
	game.ui.close_modal()
	game.player.skill_pool_ui.open_techniques()
func _requirements_hint(offer: LearningOffer) -> String:
	var parts: PackedStringArray=[]
	for requirement in offer.requirements: parts.append(requirement.hint)
	var refused:=game.player.actor_context.martial.learn_reason(offer.technique.id)
	if not refused.is_empty() and refused!="已学会": parts.append(refused)
	return "\n"+"；".join(parts) if not parts.is_empty() else ""

func show_production() -> void:
	if not market or not market.production_services: return
	if not reason().is_empty(): game.ui.notify(reason()); return
	game.session.production.advance()
	var screen:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	screen.get_node("Navigation/Caption").text="店内排产"
	screen.search.placeholder_text="搜索配方或原料…"
	screen.status.text="原料与成品属于店家 · 可出售采集材料供货，再购买真实成品"
	screen.footer.add_child(W.button("回到整修铺",show.bind(false)))
	var live_rows: Array[Dictionary]=[]
	for definition in game.session.production.catalog.entries:
		if definition.actor_id!=market.actor_id: continue
		var title:=game.player.skill_manager.combinations.supplies.title(definition.recipe.output_id)
		var card:=W.card(screen.rows,title+" ×%d"%definition.recipe.output_count,"每批%.0f游戏小时"%definition.work_hours)
		var input_label:=W.label("",14,true); card.add_child(input_label)
		var label:=W.label("",14,true); card.add_child(label)
		var button:=W.button("",Callable()); card.add_child(button)
		button.pressed.connect(func(): _production_request(definition.id,bool(button.get_meta("cancel_order",false))))
		var row: Dictionary={"id":definition.id,"title":title,"label":label,"button":button,"inputs":input_label,"host":card.get_parent(),"search":title+game.player.skill_manager.combinations.supplies.describe_cost(definition.recipe.inputs)}
		live_rows.append(row); _refresh_production_row(row)
	screen.search.text_changed.connect(func(query: String):
		for row in live_rows: row.host.visible=query.is_empty() or str(row.search).contains(query))
	var timer:=Timer.new(); timer.wait_time=1; timer.autostart=true; screen.add_child(timer)
	timer.timeout.connect(func():
		for row in live_rows: _refresh_production_row(row))
	screen.detail.add_child(W.label("排产不预扣原料、不预留货品。工期完成时检查店家真实库存并加工；缺料或满库会等候，恢复后重新计工期。停止不会扣原料；已完成成品留在店内。休息推进工期，离线不推进，不会补满货物或生成河谷币。",14,true))
	game.ui.show_view(service_title(market.actor_id,"整修铺")+" · 店内排产",screen)
func _refresh_production_row(row: Dictionary) -> void:
	var state:=game.session.production.status(row.id)
	var definition:=game.session.production.catalog.definition(row.id)
	var inputs: PackedStringArray=[]
	for key in definition.recipe.inputs:
		inputs.append("%s ×%d（店存%d）"%[game.player.skill_manager.combinations.supplies.title(key),definition.recipe.inputs[key],game.session.inventory.count(definition.actor_id,key)])
	row.inputs.text="原料："+" · ".join(inputs)
	var detail: String="未排产"
	if state.scheduled:
		detail="等候原料/库容；恢复后重新计工期" if state.blocked else "剩余%.1f游戏小时 · %d批"%[state.remaining*WorldTime.instance.time_scale/3600.0,state.batches]
	if not str(state.reason).is_empty(): detail+=" · "+str({"materials":"缺少配方原料","capacity":"成品库容不足","producer_dead":"生产者已死亡，排产终止"}.get(state.reason,state.reason))
	row.label.text="店存%d · "%state.stock+detail
	row.button.text="停止排产" if state.scheduled else "安排一批 · "+str(row.title)
	row.button.set_meta("cancel_order",state.scheduled)
	row.button.disabled=state.reason=="producer_dead"
func _production_request(id: String,cancel_order: bool) -> void:
	if not reason().is_empty(): game.ui.notify(reason()); return
	if cancel_order: game.session.production.cancel(id)
	else:
		var result:=game.session.production.start(id)
		game.ui.notify("已安排一批，完成后返回整修铺购买。" if result.accepted else "未排产："+result.reason)
	if cancel_order: game.ui.notify("已停止排产。")
	game._save_progress(); show_production()
