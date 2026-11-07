class_name TownServices
extends RefCounted
## Chapter adapter: proximity and service presentation. Inventory owns all mutations.
const MERCHANT := "river.merchant"
const STOCK := {"coin":160,"metal_scrap":12,"charcoal":6,"sap":6,"crystal":4,"cloth":6,"ration":6,"clean_water":4,"river_sabre":1,"river_spear":1,"river_staff":1,"river_bow":1,"arrow":24,"guard_tonic":2,"clear_tonic":2,"book_spear_thrust":1}
const ERRORS := {"not_owned":"物品已离开原来的容器。","payment_or_capacity":"货币不足，或对方没有空间接收付款。","capacity":"容器空间不足，未扣除物品或货币。","materials":"货币或金属碎料不足。","maximum_level":"已达到最高强化等级。","unequip_first":"请先卸下这件装备，再带来整修。"}
const POINT := Vector2(-3210,2200)
const W := preload("res://gameplay/foundation/ui/widgets.gd")
var game: GrayriverGame
var _screen: ExpeditionScreen
var _selling := true
func _init(owner_game: GrayriverGame) -> void: game=owner_game
func ensure_stock() -> void:
	var store:=game.session.inventory
	if store.has_container(MERCHANT+".pack"): return
	store.ensure_actor(MERCHANT)
	store.begin_batch()
	for id in STOCK:
		store.receive(MERCHANT,id,int(STOCK[id]),true)
	store.end_batch()
func reason() -> String:
	if game.region_id!="camp" or game.player.global_position.distance_to(POINT)>150: return "请靠近镇中整修铺。"
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
func transact(uid: String,selling: bool) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item or item.definition_id=="coin": return OperationResult.reject("不可交易")
	return store.trade_instance(MERCHANT if selling else "player","player" if selling else MERCHANT,uid,1,price(uid,not selling))
func salvage(uid: String,upgrade: bool) -> OperationResult:
	if not reason().is_empty(): return OperationResult.reject(reason())
	return game.session.inventory.upgrade_instance("player",uid) if upgrade else game.session.inventory.dismantle_instance("player",uid)
func show(selling := true) -> void:
	if not reason().is_empty(): game.ui.notify(reason()); return
	_selling=selling
	ensure_stock()
	_screen=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	_screen.get_node("Navigation/Caption").text="整修铺"
	_screen.tabs.add_child(W.button("出售 / 拆解 / 强化",show.bind(true)))
	_screen.tabs.add_child(W.button("购买实物",show.bind(false)))
	_screen.search.text_changed.connect(func(query: String): _rows(query))
	var hint:=W.label("交易库存有限；装备先卸下再整修。整修保留同一件实物，涂层不会重置。",12,true)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_screen.footer.add_child(hint)
	game.ui.show_view("灰河谷 · 整修铺",_screen)
	_rows("")
func _rows(query: String) -> void:
	W.clear(_screen.rows); W.clear(_screen.detail)
	var store:=game.session.inventory
	_screen.status.text="随身河谷币 %d · 店家河谷币 %d · 金属碎料 %d"%[store.count("player","coin"),store.count(MERCHANT,"coin"),store.count("player","metal_scrap")]
	for container in store.actor_containers("player" if _selling else MERCHANT):
		for row in store.entries(container):
			var definition:=store.definitions[row.definition] as ItemData
			if row.definition=="coin" or not query.is_empty() and not definition.display_name.contains(query): continue
			var data:=store.equipment_definition(row.uid) if definition is EquipmentData else definition
			_screen.rows.add_child(W.button("%s ×%d · %d币"%[data.display_name,row.quantity,price(row.uid,not _selling)],_detail.bind(row.uid)))
func _detail(uid: String) -> void:
	W.clear(_screen.detail)
	var store:=game.session.inventory
	var item:=store.item(uid)
	if not item: return
	var definition:=store.definitions[item.definition_id] as ItemData
	var data:=store.equipment_definition(uid) if definition is EquipmentData else definition
	_screen.detail.add_child(W.label(data.display_name,22))
	_screen.detail.add_child(W.label(data.description+"\n"+store.state_text(uid),14,true))
	if data is EquipmentData:
		W.disclosure(_screen.detail,"当前装备属性",W.comparison(null,data))
		if data.moveset: W.disclosure(_screen.detail,"武器动作",data.moveset.describe())
	_screen.detail.add_child(W.button(("出售一件" if _selling else "购买一件")+" · %d币"%price(uid,not _selling),_request.bind("trade",uid)))
	if _selling and definition is EquipmentData:
		var level:=clampi(int(item.properties.get("upgrade_level",0)),0,3)
		_screen.detail.add_child(W.label("强化每级：主手攻击+1；其余装备生命上限+4。最高+3。",14,true))
		_screen.detail.add_child(W.button("拆解 · 获得%d金属碎料（销毁这件装备）"%(2+level),_request.bind("dismantle",uid)))
		_screen.detail.add_child(W.button("强化 · %d币 + %d金属碎料"%[5*(level+1),2*(level+1)],_request.bind("upgrade",uid),level>=3))
func _request(method: String,uid: String) -> void:
	var result:=transact(uid,_selling) if method=="trade" else salvage(uid,method=="upgrade")
	game.ui.notify("完成："+{"trade":"交易","dismantle":"拆解","upgrade":"强化"}[method] if result.accepted else "未完成："+str(ERRORS.get(result.reason,result.reason)))
	if result.accepted: game._save_progress()
	_rows(_screen.search.text)

func show_training() -> void:
	var npc:=game.session.actor_for_id("river.enemy.service.trainer")
	if not is_instance_valid(npc) or npc.global_position.distance_to(game.player.global_position)>150 or not npc.working: game.ui.notify("请靠近当值的训练师。"); return
	var options: Array[Dictionary]=[]
	for id in MartialArts.IDS:
		var data:=MartialArts.definition(id)
		var known: bool=game.player.actor_context.martial.learned.has(id)
		options.append({"title":data.title+(" · 已学会" if known else " · %d币"%data.price),"disabled":known,"callback":_teach.bind(id)})
	options.append({"title":"分配已有属性点","callback":game.presenter._show_training})
	game.ui.show_panel("武技训练师","武技消耗体力与对应武器资源，不消耗MP。购买只解锁知识；到K的武技页亲手绑定快捷键。刀破势、矛控距、杖压制、弓蓄射各有起手与恢复风险。",options)
func _teach(id: String) -> void:
	var npc:=game.session.actor_for_id("river.enemy.service.trainer")
	var context:=game.player.actor_context
	var data:=MartialArts.definition(id)
	if not is_instance_valid(npc) or not npc.working or npc.global_position.distance_to(game.player.global_position)>150 or game.has_hostiles_near(game.player.global_position) or context.actions.busy() or not data or context.martial.learned.has(id): return
	var store:=game.session.inventory
	store.begin_batch()
	if store.exchange("player","river.enemy.service.trainer",{"coin":data.price},{}).accepted:
		context.martial.learn(id)
		game.session.facts.publish("technique_learned","player",{"id":id,"source":"trainer"})
	else: game.ui.notify("河谷币或对方容器空间不足。")
	store.end_batch()
	game._save_progress()
	show_training()
