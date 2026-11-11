class_name NpcConversationScreen
extends VBoxContainer
## Input/presentation only. The domain rechecks each response and service request.
const W=preload("res://gameplay/foundation/ui/widgets.gd")
var conversation: NpcConversationService
var token: int
var npc_id: String
var service_request: Callable
var close_request: Callable
var notify: Callable
var _screen: ExpeditionScreen
var _selected := ""
var _response := ""
var _elapsed := 0.0
var _closed := false
var _favor_status: Label
var _stock_label: Label
var _reason_label: Label
var _favor_button: Button
func setup(domain: NpcConversationService,handle: Dictionary,services: Callable,close: Callable,notice: Callable) -> void:
	conversation=domain; token=handle.token; npc_id=handle.id; service_request=services; close_request=close; notify=notice
	size_flags_horizontal=Control.SIZE_EXPAND_FILL; size_flags_vertical=Control.SIZE_EXPAND_FILL
	var profile:=conversation.catalog.profile(npc_id)
	_response=profile.familiar_greeting if conversation.session.relations.disposition(npc_id,"player")>=10 else profile.greeting
	_screen=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	_screen.get_node("Navigation").hide()
	_screen.search.placeholder_text="搜索话题、服务或委托…"
	_screen.search.text_changed.connect(func(_query: String): _rows())
	add_child(_screen)
	_screen.footer.add_child(W.label("世界与日程继续推进 · 对话不额外跳时 · 交易、训练和交付需当值 · Esc离开",12,true))
	_screen.footer.add_child(W.button("结束交谈",_close))
	tree_exiting.connect(func(): conversation.end(token))
	_refresh()
func _process(delta: float) -> void:
	if _closed: return
	_elapsed+=delta
	if _elapsed<.3: return
	_elapsed=0
	var refused:=conversation.handle_reason(token)
	if not refused.is_empty():
		_closed=true
		if notify.is_valid(): notify.call(refused)
		if close_request.is_valid(): close_request.call()
		return
	# Live changes update existing controls; never destroy a hovered/focused target.
	_status()
	for button in _screen.rows.get_children():
		var entry:=conversation.catalog.profile(npc_id).topic(str(button.get_meta("topic","")))
		if entry: button.text=_topic_text(entry)
	_update_favor()
func _refresh() -> void:
	_status(); _rows(); _detail()
func _status() -> void:
	var profile:=conversation.catalog.profile(npc_id)
	var relations:=conversation.session.relations
	var npc:=conversation.session.actor_for_id(npc_id) as ServiceNPC
	_screen.status.text=profile.character.title+" · "+profile.role+"\n"+relations.disposition_title(npc_id,"player")+"（信任%d） · "%relations.disposition(npc_id,"player")+("当值" if npc and npc.on_duty() else "休息中，可闲谈；服务暂停")
func _topic_text(entry: NpcTopic) -> String:
	var refused:=conversation.topic_reason(npc_id,entry)
	if refused.is_empty() and entry.kind==NpcTopic.Kind.SERVICE: refused=conversation.handle_reason(token,true)
	var subtitle:=entry.category
	if conversation.seen(npc_id,entry.id): subtitle+=" · 已谈过"
	if not refused.is_empty(): subtitle+=" · 条件未满足"
	return entry.title+"\n"+subtitle
func _rows() -> void:
	W.clear(_screen.rows)
	for entry: NpcTopic in conversation.catalog.profile(npc_id).topics:
		if not _screen.search.text.is_empty() and not (entry.title+entry.category).contains(_screen.search.text): continue
		var button:=W.button(_topic_text(entry),_select.bind(entry.id))
		button.set_meta("topic",entry.id)
		button.set_meta("ui_action","npc_topic")
		button.set_meta("actor_id",npc_id)
		button.clip_text=true; button.custom_minimum_size.y=54
		GameUIStyle.apply_button(button,GameUIStyle.ACCENT,entry.id==_selected)
		_screen.rows.add_child(button)
func _select(id: String) -> void:
	_selected=id
	var entry:=conversation.catalog.profile(npc_id).topic(id)
	var result:=conversation.choose(token,id)
	_response=str(result.get("response",result.get("reason","")))
	if result.accepted and entry.kind==NpcTopic.Kind.SERVICE:
		_closed=true
		if service_request.is_valid(): service_request.call(result.service)
		return
	_refresh()
func _detail() -> void:
	W.clear(_screen.detail)
	_favor_status=null; _stock_label=null; _reason_label=null; _favor_button=null
	var profile:=conversation.catalog.profile(npc_id)
	_screen.detail.add_child(W.label(profile.character.title,22))
	_screen.detail.add_child(W.label(_response,16))
	var entry:=profile.topic(_selected)
	if not entry: return
	var refused:=conversation.topic_reason(npc_id,entry)
	if not refused.is_empty(): return
	if entry.kind!=NpcTopic.Kind.FAVOR: return
	_screen.detail.add_child(HSeparator.new())
	_favor_status=W.label("",17); _screen.detail.add_child(_favor_status)
	_stock_label=W.label("",14,true); _screen.detail.add_child(_stock_label)
	_reason_label=W.label("",14,true); _screen.detail.add_child(_reason_label)
	_favor_button=W.button("",_favor); _screen.detail.add_child(_favor_button)
	_update_favor()
func _update_favor() -> void:
	if not is_instance_valid(_favor_button): return
	var entry:=conversation.catalog.profile(npc_id).topic(_selected)
	var state:=conversation.favor_state(npc_id,entry.id)
	_favor_status.text="已交付" if state=="completed" else "已交一批 · 等待下批" if state=="waiting" else "已接受 · 需当面交付" if state=="accepted" else "尚未接受"
	_stock_label.text="交付："+_items(entry.requested_items,"player")+"\n报酬："+_items(entry.payment,npc_id)+"\n信任 +%d；每批仅结算一次。"%entry.trust_reward
	var refused:=conversation.handle_reason(token,true)
	if refused.is_empty(): refused=conversation.topic_reason(npc_id,entry)
	if refused.is_empty() and state in ["accepted","waiting"]: refused=conversation.favor_reason(npc_id,entry)
	if entry.repeat_hours>0:_stock_label.text+="\n最多%d批，每批间隔%.1f游戏小时；报酬取自对方实有钱袋。"%[entry.maximum_deliveries,entry.repeat_hours]
	_reason_label.text=refused; _reason_label.visible=not refused.is_empty()
	_favor_button.text="接受委托" if state.is_empty() else "交付物资并领取报酬"
	_favor_button.visible=state!="completed"
	_favor_button.disabled=not refused.is_empty()
func _items(amounts: Dictionary,owner: String) -> String:
	var parts: PackedStringArray=[]
	for id in amounts:
		var store:=conversation.session.inventory
		parts.append("%s ×%d（%s持有%d）"%[store.definitions[id].display_name,amounts[id],"你" if owner=="player" else "对方",store.count(owner,id)])
	return " · ".join(parts)
func _favor() -> void:
	var operation: String="accept" if conversation.favor_state(npc_id,_selected).is_empty() else "deliver"
	var result:=conversation.choose(token,_selected,operation)
	_response=str(result.get("response",result.get("reason","")))
	_refresh()
func _close() -> void:
	_closed=true; conversation.end(token)
	if close_request.is_valid(): close_request.call()
