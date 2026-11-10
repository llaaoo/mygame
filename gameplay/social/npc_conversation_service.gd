class_name NpcConversationService
extends RefCounted
## Persistent topic/favor memory; transient handles never survive region exit or load.
var session: CampaignSession
var catalog: NpcCatalog
var record: Callable
var _known: Dictionary={}
var _favors: Dictionary={}
var _handles: Dictionary={}
var _serial := 0
func configure(owner_session: CampaignSession,definitions: NpcCatalog) -> void:
	session=owner_session; catalog=definitions
func invalidate() -> void:
	for handle in _handles.values():
		var npc:=session.actor_for_id(handle.id) as ServiceNPC if session else null
		if is_instance_valid(npc): npc.stop_attending()
	_handles.clear()
func end(token: int) -> void:
	if not _handles.has(token): return
	var npc:=session.actor_for_id(_handles[token].id) as ServiceNPC
	if is_instance_valid(npc): npc.stop_attending()
	_handles.erase(token)
func reason(id: String,services := false,range_limit := 80.0) -> String:
	var profile:=catalog.profile(id) if catalog else null
	var npc:=session.actor_for_id(id) as ServiceNPC if session else null
	var visitor:=session.actor_for_id("player") as Player if session else null
	if not profile or not is_instance_valid(npc) or npc.health_component.is_dead: return "此人已不在这里，无法交谈。"
	if not visitor or visitor.health_component.is_dead or session.region.id!=profile.region_id or npc.get_parent()!=session.region.root: return "交谈已经结束。"
	if npc.global_position.distance_to(visitor.global_position)>=range_limit: return "距离太远，交谈已中断。"
	var sight:=PhysicsRayQueryParameters2D.create(visitor.global_position,npc.global_position,1)
	if not visitor.get_world_2d().direct_space_state.intersect_ray(sight).is_empty(): return "视线被遮挡，无法隔墙交谈。"
	if session.relations.attitude(id,"player")=="hostile": return "对方与你敌对，拒绝交谈。"
	if session.has_hostiles_near("player",visitor.position) or visitor.actor_context.actions.busy() or npc.actor_context.actions.busy(): return "附近有危险或动作尚未结束，先确保安全。"
	if services and not npc.on_duty(): return npc.off_duty_reason()
	return ""
func begin(id: String) -> Dictionary:
	var refused:=reason(id)
	if not refused.is_empty(): return {"accepted":false,"reason":refused}
	invalidate(); _serial+=1
	_handles[_serial]={"id":id,"generation":session.region.generation}
	(session.actor_for_id(id) as ServiceNPC).attend(session.actor_for_id("player"))
	return {"accepted":true,"token":_serial,"id":id}
func handle_reason(token: int,services := false) -> String:
	if not _handles.has(token) or not session.region.available(_handles[token].generation): return "这段交谈已经结束，请重新交谈。"
	return reason(_handles[token].id,services)
func topic_reason(id: String,entry: NpcTopic) -> String:
	if not entry: return "未知话题。"
	if not session.condition_query or not session.condition_query.claims_satisfied(entry.required_claims): return "还没有亲自取得这件事的线索或成果。"
	var visitor:=session.actor_for_id("player") as Player
	if not visitor or not visitor.stats_component.meets_requirements(entry.required_attributes): return "尚需"+visitor.stats_component.describe_requirements(entry.required_attributes) if visitor else "交谈者已离开。"
	if session.relations.disposition(id,"player")<entry.minimum_disposition: return "需要信任%d（当前%d）。"%[entry.minimum_disposition,session.relations.disposition(id,"player")]
	return ""
func seen(id: String,topic_id: String) -> bool:
	return topic_id in _known.get(id,[])
func favor_state(id: String,topic_id: String) -> String:
	return str(_favors.get(id+"/"+topic_id,""))
func choose(token: int,topic_id: String,operation := "read") -> Dictionary:
	if operation not in ["read","accept","deliver"]: return {"accepted":false,"reason":"不支持的交谈操作。"}
	var refused:=handle_reason(token)
	if not refused.is_empty(): return {"accepted":false,"reason":refused}
	var id: String=_handles[token].id
	var entry:=catalog.profile(id).topic(topic_id)
	refused=topic_reason(id,entry)
	if not refused.is_empty(): return {"accepted":false,"reason":refused}
	if entry.kind==NpcTopic.Kind.SERVICE:
		if operation!="read": return {"accepted":false,"reason":"服务不是交付操作。"}
		refused=handle_reason(token,true)
		if not refused.is_empty(): return {"accepted":false,"reason":refused}
		invalidate()
		return {"accepted":true,"service":entry.service}
	if entry.kind==NpcTopic.Kind.FAVOR and operation!="read": return _favor(token,id,entry,operation)
	if operation!="read": return {"accepted":false,"reason":"不支持的交谈操作。"}
	var fresh:=not seen(id,entry.id)
	if fresh:
		if not _known.has(id): _known[id]=[]
		_known[id].append(entry.id)
		if entry.kind==NpcTopic.Kind.INFORMATION:
			if entry.recognition>0: session.relations.adjust_disposition(id,"player",entry.recognition)
			_write("npc.topic."+id+"."+entry.id,catalog.profile(id).character.title+"："+entry.title,response_for(id,entry)+"\n交谈线索；地图仍只记录亲自踏足的地点。")
		session.facts.publish("npc_topic_read","player",{"npc":id,"topic":entry.id})
	return {"accepted":true,"response":response_for(id,entry)}
func response_for(id: String,entry: NpcTopic) -> String:
	var profile:=catalog.profile(id)
	var world:=session.condition_query.catalog if session.condition_query else null
	return entry.response+world.navigation_text(entry.navigation_hints,profile.region_id,profile.work_location(),profile.character.title+"的工作点",session.condition_query.progress) if world else entry.response
func record_text(record: Dictionary) -> String:
	if not str(record.get("id","")).begins_with("npc.topic."): return ""
	for profile in catalog.profiles:
		for entry in profile.topics:
			if str(record.id)=="npc.topic."+profile.actor_id+"."+entry.id and seen(profile.actor_id,entry.id): return response_for(profile.actor_id,entry)+"\n交谈线索；地图仍只记录亲自踏足的地点。"
	return ""
func favor_reason(id: String,entry: NpcTopic) -> String:
	if favor_state(id,entry.id)=="completed": return "已经交付，不会重复领取报酬。"
	if favor_state(id,entry.id)!="accepted": return "先明确接受委托。"
	if session.actor_records.get(id,{}).get("dead",false): return "委托人已死亡，无法继续交付。"
	var refused:=topic_reason(id,entry)
	if not refused.is_empty(): return refused
	if session.relations.attitude(id,"player")=="hostile": return "委托人与你敌对，暂时无法交付。"
	var npc:=session.actor_for_id(id) as ServiceNPC
	var profile:=catalog.profile(id)
	var routine:=profile.daily_schedule().get_entry_for_hour(float(session.hour_query.call())) if session.hour_query.is_valid() else null
	if npc and not npc.on_duty() or not npc and routine and routine.target_marker!="work": return "委托人未当值，准备好物资后在当值时返回。"
	if not session.inventory.can_pay("player",entry.requested_items): return "随身交付物不足，放下的背包不算在内。"
	if not session.inventory.can_pay(id,entry.payment): return "对方实有报酬不足，不能凭空付款。"
	return ""
func favor_details(tracked_id: String) -> Dictionary:
	if not tracked_id.begins_with("npc.favor."): return {}
	var key:=tracked_id.trim_prefix("npc.favor.")
	if not _favors.has(key): return {}
	var parts:=key.split("/"); var profile:=catalog.profile(parts[0]); var entry:=profile.topic(parts[1])
	return {"profile":profile,"topic":entry,"state":_favors[key],"dead":bool(session.actor_records.get(profile.actor_id,{}).get("dead",false)),"reason":favor_reason(profile.actor_id,entry)}
func _favor(token: int,id: String,entry: NpcTopic,operation: String) -> Dictionary:
	var refused:=handle_reason(token,true)
	if not refused.is_empty(): return {"accepted":false,"reason":refused}
	var key:=id+"/"+entry.id
	if operation=="accept":
		if not favor_state(id,entry.id).is_empty(): return {"accepted":false,"reason":"已接受或已经交付。"}
		if not _known.has(id): _known[id]=[]
		if not seen(id,entry.id): _known[id].append(entry.id)
		_favors[key]="accepted"
		_write("npc.favor."+key,entry.title,"委托人："+catalog.profile(id).character.title+"\n"+entry.response+"\n已接受；需当面交付真实物资。")
		session.facts.publish("npc_favor_accepted","player",{"npc":id,"favor":entry.id})
		return {"accepted":true,"response":"已接受委托。收集齐物资后，当值时当面交付。"}
	if operation!="deliver": return {"accepted":false,"reason":"未知委托操作。"}
	refused=favor_reason(id,entry)
	if not refused.is_empty(): return {"accepted":false,"reason":refused}
	session.inventory.begin_batch()
	var exchanged:=session.inventory.exchange("player",id,entry.requested_items,entry.payment)
	if not exchanged.accepted:
		session.inventory.end_batch(false)
		return {"accepted":false,"reason":"库存空间不足，双方物资和报酬均未转移。"}
	_favors[key]="completed"
	_write("npc.favor."+key,entry.title,"已当面交付给"+catalog.profile(id).character.title+"。报酬取自对方真实行囊，信任提高%d。"%entry.trust_reward)
	session.relations.adjust_disposition(id,"player",entry.trust_reward)
	session.inventory.end_batch()
	session.facts.publish("npc_favor_completed","player",{"npc":id,"favor":entry.id})
	return {"accepted":true,"response":"物资收到了，这是说好的报酬。我会记得你的帮忙。"}
func _write(id: String,title: String,text: String) -> void:
	if record.is_valid(): record.call(id,title,text)
func snapshot() -> Dictionary:
	return {"schema":1,"known":_known.duplicate(true),"favors":_favors.duplicate()}
func restore(data: Dictionary) -> bool:
	if not valid_state(data): return false
	invalidate(); _known=data.get("known",{}).duplicate(true); _favors=data.get("favors",{}).duplicate()
	return true
func favor_entries() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for key: String in _favors:
		var parts:=key.split("/"); var profile:=catalog.profile(parts[0]); var entry:=profile.topic(parts[1])
		var done: bool=_favors[key]=="completed"
		var dead: bool=session.actor_records.get(profile.actor_id,{}).get("dead",false)
		var ready:=not done and not dead and favor_reason(profile.actor_id,entry).is_empty()
		result.append({"id":"npc.favor."+key,"rank":1 if ready else 2,"title":entry.title,"text":"委托人："+profile.character.title+"\n"+entry.response+"\n"+("对方已经死亡；不会转移给另一人。" if dead and not done else "已当面交付，报酬和关系已结算。" if done else "物资齐备时，回到委托人身边，在当值时交付。"),"subtitle":"已完成" if done else "委托人已死亡" if dead else "可当面交付" if ready else "进行中","npc_favor":true,"done":done,"ready":ready})
	return result
static func valid_state(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if data.get("schema")!=1 or not data.get("schema") is int or not data.get("known") is Dictionary or not data.get("favors") is Dictionary: return false
	var definitions:=NpcCatalog.default_catalog()
	for id in data.known:
		var profile:=definitions.profile(id) if id is String else null
		if not profile or not data.known[id] is Array or data.known[id].size()>profile.topics.size(): return false
		var seen_ids: Dictionary={}
		for topic in data.known[id]:
			if not topic is String or not profile.topic(topic) or profile.topic(topic).kind==NpcTopic.Kind.SERVICE or seen_ids.has(topic): return false
			seen_ids[topic]=true
	for key in data.favors:
		if not key is String or key.count("/")!=1 or data.favors[key] not in ["accepted","completed"]: return false
		var parts: PackedStringArray=key.split("/"); var profile:=definitions.profile(parts[0]); var topic:=profile.topic(parts[1]) if profile else null
		if not topic or topic.kind!=NpcTopic.Kind.FAVOR: return false
	return true
