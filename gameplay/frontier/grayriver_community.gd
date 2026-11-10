class_name GrayriverCommunity
extends RefCounted
## Chapter presentation/spatial adapter. Domain owners keep knowledge, affiliation, law and stock.
var game: GrayriverGame
func _init(owner_game: GrayriverGame) -> void:game=owner_game
func reason(npc: String) -> String:return game.session.conversations.reason(npc,true,150)
func show_charters(npc: String) -> void:
	var refused:=reason(npc)
	if not refused.is_empty():game.ui.notify(refused);return
	var options: Array[Dictionary]=[]
	for entry in CharterCatalog.default_catalog().entries:
		var requirement:=entry.reason(game.player.actor_context)
		options.append({"title":entry.title+("\n"+requirement if not requirement.is_empty() else " · 查看誓约"),"disabled":not requirement.is_empty(),"callback":_confirm_charter.bind(npc,entry.id)})
	options.append({"title":"返回交谈","callback":game.residents.open.bind(npc)})
	game.ui.show_panel("河谷身份与专长","本旅程可选择一种身份。猎队重视狩猎实践，守路队重视武技与处理纠纷的成果。入队解锁独有位移武技及对应实物箱权限，不自动领取或补满物品；对应箱内首次补给有限，既有知识仍归本人。",options)
func _confirm_charter(npc: String,id: String) -> void:
	if not reason(npc).is_empty():return
	var entry:=CharterCatalog.default_catalog().definition(id)
	game.ui.show_panel("立誓："+entry.title,entry.description+"\n\n本旅程只选择一次。武技进入已有连招系统，仍需实际武器与弹药；每个组合最多两招，轻点Ctrl切换。",[{"title":"确认加入"+entry.title,"callback":_join.bind(npc,id)},{"title":"重新考虑","callback":show_charters.bind(npc)}])
func _join(npc: String,id: String) -> void:
	if not reason(npc).is_empty():return
	var entry:=CharterCatalog.default_catalog().definition(id)
	if not entry or game.session.law.has_reported_debt("player"):game.ui.notify("先结清已通报的私产纠纷");return
	if not entry.enroll(game.player.actor_context):game.ui.notify(entry.reason(game.player.actor_context));return
	game.progress_service.record_service_result("charter."+id,"立誓："+entry.title,entry.description)
	game._save_progress();show_charters(npc)
func show_mediation(npc := "") -> void:
	if not _mediation_available(npc):return
	var options: Array[Dictionary]=[]
	var text:="归还材料遵守原堆叠规则；整件装备和喷剂保留UID。物资已经消耗或不在随身容器时，可支付真实赔款。重复取用且被目击时，物主会追回可归还物品。未结纠纷限制物主服务，结清后恢复；信任损失不自动抹去。\n"
	for id in game.session.law.cases:
		var entry: Dictionary=game.session.law.cases[id]
		if entry.actor!="player" or entry.settled:continue
		var name:=game.session.conversations.catalog.profile(entry.owner).character.title
		text+="\n%s · %s · 赔款%d币"%[name,"已通报" if entry.reported else "未通报的归属争议",entry.fine]
		options.append({"title":"归还："+name+" · "+id,"callback":_settle.bind(npc,id,false)})
		options.append({"title":"赔偿%d币："%entry.fine+name,"callback":_settle.bind(npc,id,true)})
	for entry in game.session.conversations.favor_entries():
		if entry.done:continue
		var details:=game.session.conversations.favor_details(entry.id)
		if not details.dead or details.topic.successor_actor_id.is_empty():continue
		var delegate:=str(details.topic.successor_actor_id)
		if not npc.is_empty() and npc!=delegate:continue
		var refused:=game.session.conversations.estate_reason(details.profile.actor_id,details.topic.id,delegate)
		options.append({"title":"代办遗产委托："+details.topic.title+("\n"+refused if not refused.is_empty() else ""),"disabled":not refused.is_empty(),"callback":_estate.bind(delegate,details.profile.actor_id,details.topic.id)})
	options.append({"title":"结束调解","callback":game.ui.close_modal})
	game.ui.show_panel("公署与物主调解",text,options)
func _mediation_available(npc: String) -> bool:
	if not npc.is_empty():return reason(npc).is_empty()
	if game._switching or game.player.health_component.is_dead or game.player.actor_context.actions.busy() or game.has_hostiles_near(game.player.position):return false
	for amenity in game.current_data.amenities:
		if amenity.service!="mediation" or game.player.position.distance_to(amenity.pos)>80:continue
		var ray:=PhysicsRayQueryParameters2D.create(game.player.global_position,game.region_root.to_global(amenity.pos),1)
		if game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():return true
	game.ui.notify("靠近公署调解台");return false
func _settle(npc: String,id: String,pay: bool) -> void:
	if not _mediation_available(npc):return
	var result:=game.session.law.compensate(id) if pay else game.session.law.return_goods(id)
	game.ui.notify("归属纠纷已结清。" if result.accepted else result.reason)
	if result.accepted:
		var owner: String=game.session.law.cases[id].owner
		game.loot.refresh_remainder(owner);game._save_progress()
	show_mediation(npc)
func _estate(delegate: String,id: String,topic: String) -> void:
	var result:=game.session.conversations.deliver_estate(id,topic,delegate)
	game.ui.notify(str(result.get("response",result.get("reason",""))))
	if result.accepted:game.loot.refresh_remainder(id);game._save_progress()
	show_mediation(delegate)
