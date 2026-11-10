class_name ExpeditionRetreat
extends RefCounted
var game: CampaignGame
var distance_query: Callable
var _quote: Dictionary={}
var _quoted_region := ""
var _quoted_point:=Vector2.INF
var _rescue_death := -1
func _init(owner_game: CampaignGame) -> void: game = owner_game
func begin() -> void:
	game.ui.close_modal()
	if not reason().is_empty():
		game.ui.notify(reason())
		return
	if game.rules.expedition:
		_show_journey();return
	var option := FieldWorkMethod.new()
	option.id = "retreat"
	option.title = "撤回营地"
	option.duration = 3
	var methods: Array[FieldWorkMethod] = [option]
	game.player.field_work.inspect(game.player, "现场撤离", methods, func(_m): return reason(), _complete, "站定3秒，受伤、移动、施法或攻击会打断；交互键或Esc取消。不收材料，生命法力保持。")
	game.player.field_work.start_selected()
func reason() -> String:
	if game._switching or not game.ready_for_play or game.is_at_base() or game.player.health_component.is_dead: return "当前无需或无法撤离"
	return ""
func _complete(_method: FieldWorkMethod) -> bool:
	if not reason().is_empty(): return false
	game.request_travel("camp")
	return true

func _show_journey() -> void:
	var rules:=game.rules.expedition
	var distance:=float(distance_query.call()) if distance_query.is_valid() else game.player.position.distance_to(rules.base_point)
	_quote=rules.quote(distance,game.region_id!=game.rules.base_region);_quoted_region=game.region_id
	_quoted_point=game.player.position
	var portions:=int(_quote.portions);var hours:=float(_quote.hours)
	var prepared:=FieldWorkMethod.new();prepared.id="journey:prepared";prepared.title="备粮返程 · %.1f小时 · 烤饼%d / 清水%d"%[hours,portions,portions];prepared.duration=3;prepared.material_costs={"ration":portions,"clean_water":portions}
	var slow:=FieldWorkMethod.new();slow.id="journey:slow";slow.title="徒步求援 · %.1f小时 · 无额外物资 / 疲劳+25"%(hours*2);slow.duration=5
	game.player.field_work.inspect(game.player,"规划返程",[prepared,slow],_journey_reason,_journey_complete,"返程推进世界时间、需求、效果和店内工期；没有休息的固定治疗。徒步求援保留缺料时的退路，但更耗时、更疲劳。移动、受伤、离区均取消，确认完成才扣料。")
func _journey_reason(method: FieldWorkMethod) -> String:
	var refused:=reason()
	if not refused.is_empty():return refused
	if _quote.is_empty() or _quoted_region!=game.region_id or method.id not in ["journey:prepared","journey:slow"]:return "返程路线已变化，请重新规划"
	if game.player.position.distance_to(_quoted_point)>12:return "出发位置已变化，请关闭面板重新规划返程"
	if game.has_hostiles_near(game.player.position):return "附近仍有敌人，先脱离危险再安排返程"
	for status in game.player.get_node("BuffManager").get_active_buff_entries():
		if status.category in [Buff.Category.DEBUFF,Buff.Category.DOT,Buff.Category.CONTROL]:return "先处理有害状态再返程"
	var expected: Dictionary={"ration":int(_quote.portions),"clean_water":int(_quote.portions)} if method.id=="journey:prepared" else {}
	if method.material_costs!=expected:return "补给方案已变化"
	return "" if game.session.inventory.can_pay("player",expected) else "备粮不足，可选择较慢的徒步求援"
func _journey_complete(method: FieldWorkMethod) -> bool:
	if not _journey_reason(method).is_empty():return false
	var quote:=_quote.duplicate(true);_quote.clear()
	if not game.session.inventory.pay("player",method.material_costs):_quote=quote;return false
	var prepared:=method.id=="journey:prepared"
	var hours:=float(quote.hours)*(1 if prepared else 2)
	var portions:=int(quote.portions) if prepared else 0
	_quote.clear()
	game.survival.advance_journey(hours,portions,5 if prepared else 25)
	game.progress_service.record_service_result("journey.return.%d"%int(game.session.inventory.clock_seconds),"返抵河谷镇","%s，行程%.1f小时；补给与时间已实际结算。"%["备粮返程" if prepared else "徒步求援",hours])
	game.session.facts.publish("journey_completed","player",{"hours":hours,"mode":method.id})
	game.request_travel("camp")
	return true
func on_defeat() -> void:
	if not game.rules.expedition or game.is_at_base():return
	game.session.expedition.pending_rescue=true
	var store:=game.session.inventory
	if game.rules.expedition.lose_pack_on_defeat and store.is_attached("player.pack") and not store.entries("player.pack").is_empty():
		if game.session.drop_pack("player"):
			game.progress_service.record_service_result("journey.recover_pack","遗失的旅行背包","背包留在"+game.current_data.title+"的败退地点。口袋与穿戴保留；M显示回收位置，亲自靠近F拾回，物品UID与余量不变。")
func rescue() -> bool:
	if game._switching or not game.player.health_component.is_dead or _rescue_death==game.progress.deaths:return false
	_rescue_death=game.progress.deaths
	resume_pending_rescue()
	game.ui.close_modal();game.request_travel("camp")
	return true

func resume_pending_rescue() -> bool:
	if not game.rules.expedition or not game.session.expedition.pending_rescue:return false
	game.session.expedition.pending_rescue=false
	game.survival.advance_journey(game.rules.expedition.rescue_hours,0,10)
	return true
