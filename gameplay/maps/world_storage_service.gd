class_name WorldStorageService
extends RefCounted
## Spatial access adapter; InventoryService alone owns instances and transactions.
const W=preload("res://gameplay/foundation/ui/widgets.gd")
var game: CampaignGame
var _spec: WorldStorageData
var _generation := -1
var _screen: ExpeditionScreen
var _deposit := false
var _selected := ""
func _init(owner_game: CampaignGame) -> void: game=owner_game
func mount(spec: WorldStorageData) -> void:
	var store:=game.session.inventory
	if not store.has_container(spec.id):
		store.ensure_container(spec.id,"storage:"+spec.id,"cache",spec.capacity)
		store.begin_batch()
		for id in spec.initial_items: store.receive_into(spec.id,id,int(spec.initial_items[id]))
		store.end_batch()
	if spec.allow_theft:game.session.law.register_source(spec.id,spec.access_actor_id)
	var node:=game.builder._add_interaction(spec.title,spec.pos,show.bind(spec),"cache")
	node.set_meta("world_storage",spec.id)
func reason(spec: WorldStorageData,generation := -1) -> String:
	if not spec or not game.session.region.available(generation) or spec not in game.current_data.storage or game.player.health_component.is_dead: return "容器已不在这里。"
	if not spec.affiliation_id.is_empty() and game.session.relations.affiliation("player")!=spec.affiliation_id:return "此容器仅供对应身份成员使用"
	if not spec.access_actor_id.is_empty() and spec.access_actor_id!="player" and not spec.allow_theft: return "这是他人的私人物品，不能取用。"
	if game.player.position.distance_to(spec.pos)>=80: return "请靠近容器。"
	var ray:=PhysicsRayQueryParameters2D.create(game.player.global_position,game.region_root.to_global(spec.pos),1)
	if not game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return "容器被墙壁或家具遮挡。"
	if game.player.actor_context.actions.busy() or game.has_hostiles_near(game.player.position): return "先结束动作并确保附近安全。"
	return ""
func transfer(spec: WorldStorageData,uid: String,quantity: int,destination: String,generation := -1) -> OperationResult:
	var refused:=reason(spec,generation)
	if not refused.is_empty(): return OperationResult.reject(refused)
	var store:=game.session.inventory
	var source:=store.locate(uid)
	var carried:=store.actor_containers("player")
	if source==spec.id:
		if destination not in carried: return OperationResult.reject("目标不在随身容器中。")
	elif source not in carried or destination!=spec.id or not spec.allow_deposit: return OperationResult.reject("这件物品不能存入。请先卸下穿戴物，放下的背包须先拾回。")
	var result:=game.session.law.take("player",source,destination,uid,quantity,spec.pos) if source==spec.id and spec.allow_theft and spec.access_actor_id!="player" else store.commit(store.preview(source,destination,uid,quantity))
	if result.accepted: game._queue_save()
	return result
func show(spec: WorldStorageData) -> void:
	var refused:=reason(spec)
	if not refused.is_empty(): game.ui.notify(refused); return
	_spec=spec; _generation=game.session.region.generation; _selected=""; _deposit=false
	_screen=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	_screen.get_node("Navigation/Caption").text="他人私产 · 擅自取用可能被目击" if spec.allow_theft else "实物容器"
	_screen.tabs.add_child(W.button("取出物品",_mode.bind(false)))
	_screen.tabs.add_child(W.button("存入物品",_mode.bind(true),not spec.allow_deposit))
	_screen.search.text_changed.connect(_rows)
	_screen.footer.add_child(W.label("实物按原UID和余量转移；空间不足整次拒绝。空箱不会重置，离开房屋或重进不会补货。世界持续运行。",12,true))
	game.ui.show_view(spec.title,_screen)
	_rows("")
func _mode(deposit: bool) -> void:
	_deposit=deposit; _selected=""; _rows(_screen.search.text)
func _rows(query: String) -> void:
	if not is_instance_valid(_screen): return
	W.clear(_screen.rows); W.clear(_screen.detail)
	var store:=game.session.inventory
	_screen.status.text="%s · 箱内 %d/%d格 · %s"%[_spec.title,store.entries(_spec.id).size(),_spec.capacity,"选择要存入的随身实物" if _deposit else "选择要取出的实物"]
	var containers: Array[String]=[]
	if _deposit: containers.assign(store.actor_containers("player"))
	else: containers.append(_spec.id)
	var shown: Array[String]=[]
	for container in containers:
		for row in store.entries(container):
			var item:=store.definitions[row.definition] as ItemData
			if not query.is_empty() and not item.display_name.contains(query): continue
			shown.append(row.uid)
			var suffix:=" · 背包" if container=="player.pack" else ""
			_screen.rows.add_child(W.button("%s ×%d%s"%[item.display_name,row.quantity,suffix],_detail.bind(row.uid)))
	if _selected in shown: _detail(_selected)
	elif not shown.is_empty(): _detail(shown[0])
	else: _screen.detail.add_child(W.label("没有可存入的随身物品。" if _deposit else "箱子是空的。",16,true))
func _detail(uid: String) -> void:
	W.clear(_screen.detail); _selected=uid
	var store:=game.session.inventory; var item:=store.item(uid)
	if not item: return
	var definition:=store.definitions[item.definition_id] as ItemData
	_screen.detail.add_child(W.label(definition.display_name,22))
	_screen.detail.add_child(W.label(definition.description,14,true))
	_screen.detail.add_child(W.label("实物 %s · 数量%d\n%s"%[uid,item.quantity,store.state_text(uid)],13,true))
	if _deposit:
		_screen.detail.add_child(W.button("存入1件",_move.bind(uid,1,_spec.id)))
		_screen.detail.add_child(W.button("存入整组",_move.bind(uid,item.quantity,_spec.id)))
	else:
		for container in store.actor_containers("player"):
			var label:="口袋" if container=="player.pocket" else "背包"
			_screen.detail.add_child(W.button(("擅自取1件到" if _spec.allow_theft else "取1件到")+label,_move.bind(uid,1,container)))
			_screen.detail.add_child(W.button(("擅自取整组到" if _spec.allow_theft else "取整组到")+label,_move.bind(uid,item.quantity,container)))
func _move(uid: String,quantity: int,destination: String) -> void:
	var result:=transfer(_spec,uid,quantity,destination,_generation)
	game.ui.notify("物品已转移。" if result.accepted else result.reason)
	_rows(_screen.search.text)
