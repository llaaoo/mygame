class_name LawService
extends SaveRecord
## Property incidents, not a second inventory. Tagged instances remain owned by InventoryService.
@export_storage var cases: Dictionary={}
@export_storage var next_case := 1
var store: InventoryService
var relations: RelationService
var facts: GameplayFacts
var witness_query: Callable
var _sources: Dictionary={}
func configure(items: InventoryService,standing: RelationService,events: GameplayFacts) -> void:
	store=items;relations=standing;facts=events
func register_source(id: String,owner: String) -> void:_sources[id]=owner
func leave_region() -> void:_sources.clear()
func has_reported_debt(actor_id: String) -> bool:
	return cases.values().any(func(entry: Dictionary):return entry.actor==actor_id and entry.reported and not entry.settled)
func service_reason(owner: String,actor_id := "player") -> String:
	for entry in cases.values():
		if entry.owner==owner and entry.actor==actor_id and entry.reported and not entry.settled:return "先处理私产纠纷：归还物品或赔偿后恢复服务"
	return ""
func take(actor_id: String,source: String,destination: String,uid: String,quantity: int,point: Vector2) -> OperationResult:
	var owner:=str(_sources.get(source,""))
	if owner.is_empty() or owner==actor_id or destination not in store.actor_containers(actor_id) or store.locate(uid)!=source:return OperationResult.reject("私产来源已变化")
	var item:=store.item(uid)
	if not item:return OperationResult.reject("物品已不在这里")
	if cases.size()>=4096:return OperationResult.reject("私产记录已满，请勿继续擅自取用")
	var witnesses: Array=witness_query.call(actor_id,point) if witness_query.is_valid() else []
	# A second witnessed attempt gives the owner a chance to reclaim accessible goods.
	if not witnesses.is_empty() and not service_reason(owner,actor_id).is_empty():
		for id in cases.keys():
			if cases[id].owner==owner and cases[id].actor==actor_id and not cases[id].settled:return_goods(id)
		return OperationResult.reject("目击者阻止再次取用；可追回的赃物已归还，请与物主处理余下纠纷")
	var id:="property.%d"%next_case;next_case+=1
	store.begin_batch()
	var result:=store.commit(store.preview(source,destination,uid,quantity),{"stolen_from":owner,"property_case":id})
	if not result.accepted:store.end_batch(false);return result
	cases[id]={"actor":actor_id,"owner":owner,"definition":item.definition_id,"quantity":result.moved,"reported":not witnesses.is_empty(),"settled":false,"fine":clampi((store.definitions[item.definition_id] as ItemData).sell_price*result.moved*2,2,100000),"witnesses":witnesses.duplicate()}
	if cases[id].reported:relations.adjust_disposition(owner,actor_id,-10)
	store.end_batch()
	facts.publish("property_taken",actor_id,{"case":id,"owner":owner,"reported":cases[id].reported})
	return result
func pending(owner: String,actor_id := "player") -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for id in cases:
		if cases[id].owner==owner and cases[id].actor==actor_id and not cases[id].settled:
			var entry: Dictionary=cases[id].duplicate(true);entry.id=id;result.append(entry)
	return result
func return_goods(id: String) -> OperationResult:
	var entry: Dictionary=cases.get(id,{})
	if entry.is_empty() or entry.settled:return OperationResult.reject("纠纷已结清")
	var items:=store.with_property("property_case",id)
	if items.is_empty():return OperationResult.reject("物资已消耗或不在可归还状态，可选择赔偿")
	var own:=store.actor_containers(entry.actor)
	var total:=0
	for item in items:
		if store.locate(item.uid) not in own:return OperationResult.reject("先亲自取回相关物品，再当面归还")
		total+=int(item.quantity)
	if total!=int(entry.get("quantity",total)):return OperationResult.reject("相关物资已不完整，可选择赔偿")
	var snapshot:=store.snapshot_owners([entry.actor,entry.owner])
	store.begin_batch()
	for item in items:
		_clear_tag(item.uid)
		var result:=store.commit(store.preview(store.locate(item.uid),entry.owner+".pack",item.uid,item.quantity))
		if not result.accepted:
			store.restore_actor(entry.actor,snapshot);store.restore_actor(entry.owner,snapshot);store.end_batch(false);return OperationResult.reject("物主容器没有空间，未转移物品")
	for item in store.with_property("property_case",id):_clear_tag(item.uid)
	entry.settled=true
	store.end_batch()
	facts.publish("property_settled",entry.actor,{"case":id,"method":"return"})
	return OperationResult.success(items.size())
func compensate(id: String) -> OperationResult:
	var entry: Dictionary=cases.get(id,{})
	if entry.is_empty() or entry.settled:return OperationResult.reject("纠纷已结清")
	store.begin_batch()
	var payment:=store.exchange(entry.actor,entry.owner,{"coin":int(entry.fine)},{})
	if not payment.accepted:store.end_batch(false);return payment
	for item in store.with_property("property_case",id):_clear_tag(item.uid)
	entry.settled=true
	store.end_batch()
	facts.publish("property_settled",entry.actor,{"case":id,"method":"compensation"})
	return payment
func _clear_tag(uid: String) -> void:
	var item:=store.item(uid)
	if not item:return
	var properties:=item.properties.duplicate(true);properties.erase("stolen_from");properties.erase("property_case");store.set_properties(uid,properties)
static func valid_inventory_links(inventory: Dictionary,records: Dictionary) -> bool:
	var quantities: Dictionary={}
	for container in inventory.get("containers",{}).values():
		for row in container.get("items",[]):
			var properties: Dictionary=row.get("properties",{})
			if not properties.has("stolen_from") and not properties.has("property_case"):continue
			if not properties.get("stolen_from") is String or not properties.get("property_case") is String:return false
			var entry: Variant=records.get(properties.property_case)
			if not entry is Dictionary or entry.get("settled",true) or entry.get("owner")!=properties.stolen_from:return false
			if entry.has("definition") and entry.definition!=row.get("definition"):return false
			quantities[properties.property_case]=int(quantities.get(properties.property_case,0))+int(row.get("quantity",0))
	for id in quantities:
		if quantities[id]>int(records[id].get("quantity",quantities[id])):return false
	return true
func validate_save_data(value: Variant) -> bool:
	if not super.validate_save_data(value):return false
	return valid_state(value)
static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or not value.get("cases",{}) is Dictionary or not value.get("next_case",1) is int:return false
	var records: Dictionary=value.get("cases",{})
	if records.size()>4096 or int(value.get("next_case",1))<1:return false
	for id in records:
		var entry: Variant=records[id]
		if not id is String or not id.begins_with("property.") or not entry is Dictionary:return false
		var serial:=id.trim_prefix("property.") as String
		if not serial.is_valid_int() or int(serial)<1 or int(serial)>=int(value.get("next_case",1)) or id!="property.%d"%int(serial):return false
		if not entry.get("actor") is String or entry.actor.is_empty() or not entry.get("owner") is String or not NpcCatalog.default_catalog().profile(entry.owner):return false
		if not entry.get("reported") is bool or not entry.get("settled") is bool or not entry.get("fine") is int or entry.fine<1 or entry.fine>100000:return false
		if entry.has("quantity") and (not entry.quantity is int or entry.quantity<1 or entry.quantity>9999):return false
		if entry.has("definition") and (not entry.definition is String or not ItemCatalog.default_catalog().definition(entry.definition)):return false
		if not entry.get("witnesses") is Array or entry.witnesses.size()>64:return false
		for witness in entry.witnesses:
			if not witness is String or not NpcCatalog.default_catalog().profile(witness):return false
	return true
