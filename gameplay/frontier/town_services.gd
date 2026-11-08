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
func _init(owner_game: GrayriverGame,market_profile: MarketDefinition=null,training_profile: TrainingCatalog=null) -> void:
	game=owner_game
	market=market_profile if market_profile else load("res://content/frontier/town_market.tres") as MarketDefinition
	training=training_profile if training_profile else TrainingCatalog.default_catalog()
func ensure_stock() -> void:
	var store:=game.session.inventory
	if store.has_container(market.actor_id+".pack"): return
	store.ensure_actor(market.actor_id)
	store.begin_batch()
	for id in market.initial_stock:
		store.receive(market.actor_id,id,int(market.initial_stock[id]),true)
	store.end_batch()
func reason() -> String:
	if game.region_id!=market.region_id or game.player.global_position.distance_to(market.position)>market.service_range: return "请靠近镇中整修铺。"
	if game.has_hostiles_near(game.player.global_position) or game.player.actor_context.actions.busy(): return "先结束战斗与动作。"
	return ""
func price(uid: String,buying: bool) -> int:
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item: return 0
	var definition:=store.definitions[item.definition_id] as ItemData
	var base:=maxi(definition.sell_price,8 if definition is EquipmentData else 1)
	base+=clampi(int(item.properties.get("upgrade_level",0)),0,3)*2
	return base*2 if buying else base
func transact(uid: String,selling: bool,quantity := 1) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item or item.definition_id=="coin": return OperationResult.reject("不可交易")
	return store.trade_instance(market.actor_id if selling else "player","player" if selling else market.actor_id,uid,quantity,price(uid,not selling)*quantity)
func preview_trade(uid: String,selling: bool,quantity: int) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	var store:=game.session.inventory
	return store.preview_trade_instance(market.actor_id if selling else "player","player" if selling else market.actor_id,uid,quantity,price(uid,not selling)*quantity)
func salvage(uid: String,upgrade: bool) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	return game.session.inventory.upgrade_instance("player",uid) if upgrade else game.session.inventory.dismantle_instance("player",uid)
func show(selling := true) -> void:
	if not reason().is_empty(): game.ui.notify(reason()); return
	_selling=selling
	_selected_uid=""; _quantity_value=1
	ensure_stock()
	_screen=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	_screen.get_node("Navigation/Caption").text="整修铺"
	_screen.tabs.add_child(W.button("出售 / 拆解 / 强化",show.bind(true)))
	_screen.tabs.add_child(W.button("购买实物",show.bind(false)))
	_screen.tabs.add_child(W.button("店内排产",show_production))
	_screen.search.text_changed.connect(func(query: String): _rows(query))
	var hint:=W.label("交易库存有限；装备先卸下再整修。整修保留同一件实物，涂层不会重置。",12,true)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_screen.footer.add_child(hint)
	game.ui.show_view("灰河谷 · 整修铺",_screen)
	_rows("")
func _rows(query: String) -> void:
	W.clear(_screen.rows); W.clear(_screen.detail)
	var store:=game.session.inventory
	_screen.status.text="随身河谷币 %d · 店家河谷币 %d · 金属碎料 %d"%[store.count("player","coin"),store.count(market.actor_id,"coin"),store.count("player","metal_scrap")]
	var shown: Array[String]=[]
	for container in store.actor_containers("player" if _selling else market.actor_id):
		for row in store.entries(container):
			var definition:=store.definitions[row.definition] as ItemData
			if row.definition=="coin" or not query.is_empty() and not definition.display_name.contains(query): continue
			var data:=store.equipment_definition(row.uid) if definition is EquipmentData else definition
			shown.append(row.uid)
			_screen.rows.add_child(W.button("%s ×%d · %d币"%[data.display_name,row.quantity,price(row.uid,not _selling)],_detail.bind(row.uid)))
	if _selected_uid in shown: _detail(_selected_uid)
	else: _selected_uid=""
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
	if data is EquipmentData:
		W.disclosure(_screen.detail,"当前装备属性",W.comparison(null,data))
		if data.moveset: W.disclosure(_screen.detail,"武器动作",data.moveset.describe())
	_screen.detail.add_child(W.button(("出售一件" if _selling else "购买一件")+" · %d币"%price(uid,not _selling),_request.bind("trade",uid)))
	if item.quantity>1:
		_trade_quantity=SpinBox.new(); _trade_quantity.min_value=1; _trade_quantity.max_value=item.quantity; _trade_quantity.step=1; _trade_quantity.value=mini(_quantity_value,item.quantity)
		_screen.detail.add_child(_trade_quantity)
		var totals:=W.label("",14,true); _screen.detail.add_child(totals)
		var selected_button:=W.button("出售所选数量" if _selling else "购买所选数量",_request.bind("trade_quantity",uid)); _screen.detail.add_child(selected_button)
		var stack_button:=W.button("出售整叠" if _selling else "购买整叠",_request.bind("trade_stack",uid)); _screen.detail.add_child(stack_button)
		var refresh_totals:=func(value: float):
			_quantity_value=int(value)
			var unit_price:=price(uid,not _selling)
			var payer:=market.actor_id if _selling else "player"
			var funds:=store.count(payer,"coin")
			var total:=unit_price*_quantity_value
			var preview:=preview_trade(uid,_selling,_quantity_value)
			totals.text="总价%d币 · %s持有%d币 · 资金最多%d件"%[total,"店家" if _selling else "你",funds,mini(item.quantity,funds/maxi(1,unit_price))]
			if funds<total: totals.text+=" · 缺少%d币"%(total-funds)
			elif not preview.accepted: totals.text+=" · "+str(ERRORS.get(preview.reason,preview.reason))
			else: totals.text+=" · 付款后余%d币"%(funds-total)
			selected_button.disabled=not preview.accepted
			stack_button.disabled=not preview_trade(uid,_selling,item.quantity).accepted
		_trade_quantity.value_changed.connect(refresh_totals)
		refresh_totals.call(_trade_quantity.value)
	if _selling and definition is EquipmentData:
		var level:=clampi(int(item.properties.get("upgrade_level",0)),0,3)
		_screen.detail.add_child(W.label("强化每级：主手攻击+1；其余装备生命上限+4。最高+3。",14,true))
		_screen.detail.add_child(W.button("拆解 · 获得%d金属碎料（销毁这件装备）"%(2+level),_request.bind("dismantle",uid)))
		_screen.detail.add_child(W.button("强化 · %d币 + %d金属碎料"%[5*(level+1),2*(level+1)],_request.bind("upgrade",uid),level>=3))
func _request(method: String,uid: String) -> void:
	var focused:=_screen.get_viewport().gui_get_focus_owner()
	var focus_text: String=focused.text if focused is Button else ""
	var item:=game.session.inventory.item(uid)
	var quantity:=item.quantity if method=="trade_stack" and item else _quantity_value if method=="trade_quantity" else 1
	var trade:=method.begins_with("trade")
	var result:=transact(uid,_selling,quantity) if trade else salvage(uid,method=="upgrade")
	game.ui.notify("完成："+("交易 ×%d"%result.moved if trade else {"dismantle":"拆解","upgrade":"强化"}[method]) if result.accepted else "未完成："+str(ERRORS.get(result.reason,result.reason)))
	if result.accepted: game._save_progress()
	_rows(_screen.search.text)
	for button in _screen.detail.find_children("*","Button",true,false):
		if not focus_text.is_empty() and button.text==focus_text: button.grab_focus(); break

func show_training() -> void:
	var npc:=game.session.actor_for_id(training.actor_id)
	if not is_instance_valid(npc) or npc.health_component.is_dead or game.session.relations.attitude(npc.actor_context.id,"player")=="hostile" or npc.global_position.distance_to(game.player.global_position)>150 or not npc.working: game.ui.notify("请靠近当值的训练师。"); return
	var options: Array[Dictionary]=[]
	for offer in training.offers:
		var data:=offer.technique
		var known: bool=game.player.actor_context.martial.learned.has(data.id)
		var refused:=TechniqueLearning.reason(offer,game.player.actor_context)
		var price_text:=game.player.skill_manager.combinations.supplies.describe_cost(offer.costs)
		if offer.costs.size()==1 and offer.costs.has("coin"): price_text="%d币"%offer.costs.coin
		options.append({"title":data.title+(" · 已学会" if known else " · "+price_text)+(_requirements_hint(offer) if not known else ""),"disabled":not refused.is_empty(),"callback":_teach.bind(offer.id)})
	options.append({"title":"打开武技快捷编组","callback":_open_techniques})
	options.append({"title":"分配已有属性点","callback":game.presenter._show_training})
	game.ui.show_panel("武技训练师","武技消耗体力与对应武器资源，不消耗MP。购买只解锁知识；到K的武技页亲手绑定快捷键。刀破势、矛控距、杖压制、弓蓄射各有起手与恢复风险。",options)
func _teach(id: String) -> void:
	var npc:=game.session.actor_for_id(training.actor_id)
	var context:=game.player.actor_context
	var offer:=training.offer(id)
	if not is_instance_valid(npc) or npc.health_component.is_dead or game.session.relations.attitude(npc.actor_context.id,"player")=="hostile" or not npc.working or npc.global_position.distance_to(game.player.global_position)>150 or game.has_hostiles_near(game.player.global_position) or context.actions.busy() or not offer: return
	var result:=TechniqueLearning.purchase(offer,context,training.actor_id)
	game.ui.notify("已学会"+offer.technique.title+" · 点打开武技快捷编组，再选择槽位。" if result.accepted else str(ERRORS.get(result.reason,result.reason)))
	game._save_progress(); show_training()
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
	game.ui.show_view("整修铺 · 店内排产",screen)
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
	if not str(state.reason).is_empty(): detail+=" · "+str({"materials":"缺少配方原料","capacity":"成品库容不足"}.get(state.reason,state.reason))
	row.label.text="店存%d · "%state.stock+detail
	row.button.text="停止排产" if state.scheduled else "安排一批 · "+str(row.title)
	row.button.set_meta("cancel_order",state.scheduled)
func _production_request(id: String,cancel_order: bool) -> void:
	if not reason().is_empty(): game.ui.notify(reason()); return
	if cancel_order: game.session.production.cancel(id)
	else:
		var result:=game.session.production.start(id)
		game.ui.notify("已安排一批，完成后返回整修铺购买。" if result.accepted else "未排产："+result.reason)
	if cancel_order: game.ui.notify("已停止排产。")
	game._save_progress(); show_production()
