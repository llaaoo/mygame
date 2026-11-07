class_name InventoryService
extends RefCounted
## Authoritative instance/container store. Legacy inventories are views over this store.
signal changed
var definitions: Dictionary = {}
var next_uid := 1
var clock_seconds := 0.0
var _containers: Dictionary = {}
var _instances: Dictionary={}
var _locations: Dictionary={}
var _pending_facts: Array[Dictionary]=[]
var facts: GameplayFacts
var rules: RulesetDefinition
var _batch_depth := 0
var _dirty := false
func register_definition(item: ItemData) -> void:
	if item and not item.id.is_empty(): definitions[item.id]=item
func ensure_container(id: String,owner: String,kind: String,capacity: int) -> void:
	if _containers.has(id): return
	_containers[id]={"owner":owner,"kind":kind,"capacity":capacity,"revision":0,"items":[],"equipped":{},"region":"","position":[],"attached":true}
func ensure_actor(id: String) -> void:
	ensure_container(id+".pocket",id,"pocket",rules.pocket_capacity if rules else 12)
	ensure_container(id+".pack",id,"pack",rules.pack_capacity if rules else 30)
	ensure_container(id+".gear",id,"gear",9)
func actor_containers(actor: String,pocket_only := false) -> Array[String]:
	var ids: Array[String]=[actor+".pocket"]
	if not pocket_only and _containers.has(actor+".pack") and _containers[actor+".pack"].attached: ids.append(actor+".pack")
	return ids


func has_container(id: String) -> bool:
	return _containers.has(id)


func is_attached(id: String) -> bool:
	return _containers.get(id, {}).get("attached", false)


func container_revision(id: String) -> int:
	return _containers.get(id, {}).get("revision", -1)


func dropped_pack_ids(region: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in _containers:
		var record: Dictionary = _containers[id]
		if record.kind == "pack" and not record.attached and record.region == region:
			result.append(id)
	return result


func dropped_pack_position(id: String) -> Vector2:
	var position: Array = _containers.get(id, {}).get("position", [])
	return Vector2(position[0], position[1]) if position.size() == 2 else Vector2.ZERO


func drop_pack(actor: String, region: String, position: Vector2) -> bool:
	var id := actor + ".pack"
	if not is_attached(id) or region.is_empty() or not position.is_finite():
		return false
	var record: Dictionary = _containers[id]
	if record.owner != actor or record.kind != "pack":
		return false
	record.attached = false
	record.region = region
	record.position = [position.x, position.y]
	_touch(id)
	return true


func recover_pack(actor: String, id: String) -> bool:
	if id != actor + ".pack" or not has_container(id) or is_attached(id):
		return false
	var record: Dictionary = _containers[id]
	if record.owner != actor or record.kind != "pack":
		return false
	record.attached = true
	record.region = ""
	record.position = []
	_touch(id)
	return true


func discard_actor_containers(actor: String) -> void:
	for id: String in _containers.keys():
		if _containers[id].owner != actor:
			continue
		for entry: ItemInstance in _containers[id].items:
			_unindex(entry)
		_containers.erase(id)


func swap_slots(id: String, from_index: int, to_index: int) -> void:
	var items: Array = _containers.get(id, {}).get("items", [])
	if from_index == to_index or from_index < 0 or to_index < 0:
		return
	if from_index >= items.size() or to_index >= items.size():
		return
	var original: ItemInstance = items[from_index]
	items[from_index] = items[to_index]
	items[to_index] = original
	_touch(id)


func entries(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for item: ItemInstance in _containers.get(id,{}).get("items",[]): result.append(item.snapshot())
	return result
func item(uid: String) -> ItemInstance:
	var value:=_instance(uid)
	return ItemInstance.from_snapshot(value.snapshot()) if value else null
func _instance(uid: String) -> ItemInstance: return _instances.get(uid) as ItemInstance
func locate(uid: String) -> String: return str(_locations.get(uid,""))
func _index(id: String,entry: ItemInstance) -> void:
	_instances[entry.uid]=entry
	_locations[entry.uid]=id
func _unindex(entry: ItemInstance) -> void:
	_instances.erase(entry.uid)
	_locations.erase(entry.uid)
func count_in(id: String,key: String) -> int:
	var count:=0
	for entry: ItemInstance in _containers.get(id,{}).get("items",[]):
		if entry.definition_id==key: count+=entry.quantity
	return count
func count(actor: String,key: String,include_equipped := false,pocket_only := false) -> int:
	var total:=0
	var ids:=actor_containers(actor,pocket_only)
	if include_equipped: ids.append(actor+".gear")
	for id in ids: total+=count_in(id,key)
	return total
func material_amounts(actor: String) -> Dictionary:
	var result: Dictionary={}
	for id in actor_containers(actor):
		for entry: ItemInstance in _containers.get(id,{}).get("items",[]):
			if CastingSupplies.known_item(entry.definition_id): result[entry.definition_id]=int(result.get(entry.definition_id,0))+entry.quantity
	return result
func set_materials(actor: String,amounts: Dictionary) -> void:
	ensure_actor(actor)
	begin_batch()
	for id in [actor+".pocket",actor+".pack"]:
		var remove: Array=[]
		for entry: ItemInstance in _containers[id].items:
			if CastingSupplies.known_item(entry.definition_id): remove.append(entry)
		for entry in remove:
			_containers[id].items.erase(entry)
			_unindex(entry)
		_touch(id)
	for key in amounts:
		if CastingSupplies.known_item(key) and int(amounts[key])>0: receive(actor,key,int(amounts[key]),true)
	end_batch()
func _stack_limit(key: String) -> int:
	var data:=definitions.get(key) as ItemData
	if data and data.use_profile and data.use_profile.kind==ItemUseDefinition.Kind.SPRAY: return 1
	return 1 if data is EquipmentData else maxi(1,data.max_stack) if data and data.stackable else 99 if CastingSupplies.known_item(key) else 1
func space(id: String,key: String,properties: Dictionary = {}) -> int:
	if not _containers.has(id): return 0
	var limit:=_stack_limit(key)
	var total:=maxi(0,int(_containers[id].capacity)-_containers[id].items.size())*limit
	for entry: ItemInstance in _containers[id].items:
		if entry.definition_id==key and entry.properties==properties: total+=maxi(0,limit-entry.quantity)
	return total
func receive(actor: String,key: String,amount: int,migration := false) -> int:
	if amount<=0 or not definitions.has(key): return 0
	ensure_actor(actor)
	var data:=definitions[key] as ItemData
	var ids: Array[String]=[]
	if data is EquipmentData or not CastingSupplies.known_item(key): ids.append(actor+".pack")
	else: ids=actor_containers(actor)
	if ids==[actor+".pack"] and not _containers[actor+".pack"].attached and not migration: return 0
	if key in ["clean_water","dirty_water"]:
		amount=mini(amount,maxi(0,(rules.maximum_water if rules else 4)-count(actor,"clean_water")-count(actor,"dirty_water")))
	var added:=0
	begin_batch()
	for id in ids:
		var accept:=amount-added if migration else mini(amount-added,space(id,key))
		if accept>0:
			_insert(id,key,accept)
			added+=accept
		if added==amount: break
	end_batch()
	return added
func _insert(id: String,key: String,amount: int,uid := "",properties: Dictionary = {}) -> Array[String]:
	var data:=definitions.get(key) as ItemData
	if properties.is_empty() and data and data.use_profile and data.use_profile.kind==ItemUseDefinition.Kind.SPRAY:
		properties={"doses":data.use_profile.capacity}
	var uids: Array[String]=[]
	var limit:=_stack_limit(key)
	if limit>1:
		for entry: ItemInstance in _containers[id].items:
			if entry.definition_id!=key or entry.properties!=properties: continue
			var add:=mini(amount,maxi(0,limit-entry.quantity))
			entry.quantity+=add
			amount-=add
			if add>0: uids.append(entry.uid)
			if amount<=0: break
	while amount>0:
		var entry:=ItemInstance.new()
		entry.uid=uid if not uid.is_empty() else "item.%d"%next_uid
		if uid.is_empty(): next_uid+=1
		entry.definition_id=key
		entry.quantity=mini(amount,limit)
		entry.properties=properties.duplicate(true)
		_containers[id].items.append(entry)
		_index(id,entry)
		uids.append(entry.uid)
		amount-=entry.quantity
		uid=""
	_touch(id)
	return uids
func can_pay(actor: String,costs: Dictionary,pocket_only := false) -> bool:
	for key in costs:
		if int(costs[key])<0 or count(actor,key,false,pocket_only)<int(costs[key]): return false
	return true
func pay(actor: String,costs: Dictionary,pocket_only := false) -> bool:
	if not can_pay(actor,costs,pocket_only): return false
	begin_batch()
	for key in costs:
		var remaining:=int(costs[key])
		for id in actor_containers(actor,pocket_only):
			for entry: ItemInstance in _containers[id].items.duplicate():
				if entry.definition_id!=key: continue
				var amount:=mini(remaining,entry.quantity)
				entry.quantity-=amount
				remaining-=amount
				if entry.quantity==0:
					_containers[id].items.erase(entry)
					_unindex(entry)
				_touch(id)
				if remaining==0: break
			if remaining==0: break
	end_batch()
	return true
func preview(source: String,destination: String,uid: String,quantity: int,partial := false) -> TransferPlan:
	var plan:=TransferPlan.new()
	plan.source=source; plan.destination=destination; plan.item_uid=uid; plan.quantity=quantity; plan.partial=partial
	plan.source_revision=int(_containers.get(source,{}).get("revision",-1))
	plan.destination_revision=int(_containers.get(destination,{}).get("revision",-1))
	return plan
func commit(plan: TransferPlan) -> OperationResult:
	if not plan or plan.source==plan.destination or not _containers.has(plan.source) or not _containers.has(plan.destination): return OperationResult.reject("invalid_container")
	if _containers[plan.source].revision!=plan.source_revision or _containers[plan.destination].revision!=plan.destination_revision: return OperationResult.reject("stale_plan")
	var entry:=_instance(plan.item_uid)
	if not entry or locate(entry.uid)!=plan.source or plan.quantity<=0 or plan.quantity>entry.quantity: return OperationResult.reject("invalid_quantity")
	var accepted:=mini(plan.quantity,space(plan.destination,entry.definition_id,entry.properties))
	if entry.definition_id in ["clean_water","dirty_water"] and _containers[plan.source].owner!=_containers[plan.destination].owner:
		var owner: String=_containers[plan.destination].owner
		accepted=mini(accepted,maxi(0,(rules.maximum_water if rules else 4)-count(owner,"clean_water")-count(owner,"dirty_water")))
	if accepted<=0 or not plan.partial and accepted!=plan.quantity: return OperationResult.reject("capacity")
	var key:=entry.definition_id
	var properties:=entry.properties.duplicate(true)
	var uid:=entry.uid if accepted==entry.quantity else ""
	begin_batch()
	entry.quantity-=accepted
	if entry.quantity==0:
		_containers[plan.source].items.erase(entry)
		_unindex(entry)
		for slot in _containers[plan.source].equipped.keys():
			if _containers[plan.source].equipped[slot]==entry.uid: _containers[plan.source].equipped.erase(slot)
	_touch(plan.source)
	var result:=OperationResult.success(accepted)
	result.item_uids=_insert(plan.destination,key,accepted,uid,properties)
	end_batch()
	_publish("item_transferred",_containers[plan.source].owner,{"from":plan.source,"to":plan.destination,"definition":key,"quantity":accepted,"uids":result.item_uids})
	return result
func exchange(a: String,b: String,costs: Dictionary,returns: Dictionary) -> OperationResult:
	if a==b or not can_pay(a,costs) or not can_pay(b,returns): return OperationResult.reject("insufficient_items")
	# Simulate both outgoing sides before receiving either side: full containers can swap.
	var scratch:=InventoryService.new()
	scratch.rules=rules; scratch.definitions=definitions
	scratch.restore(snapshot_owners([a,b]))
	var outgoing: Array[Dictionary]=[]
	for pair in [[a,b,costs],[b,a,returns]]:
		for key in pair[2]:
			var remaining:=int(pair[2][key])
			for source in scratch.actor_containers(pair[0]):
				for row in scratch.entries(source):
					if row.definition!=key: continue
					var take:=mini(remaining,int(row.quantity))
					if take<=0: continue
					var entry:=scratch._instance(row.uid)
					var uid: String=entry.uid
					if take==entry.quantity:
						scratch._containers[source].items.erase(entry)
						scratch._unindex(entry)
					else:
						entry.quantity-=take
						uid="item.%d"%scratch.next_uid
						scratch.next_uid+=1
					scratch._touch(source)
					outgoing.append({"source":source,"actor":pair[1],"uid":uid,"quantity":take,"key":key,"properties":row.properties})
					remaining-=take
					if remaining==0: break
				if remaining==0: break
	for row in outgoing:
		var destinations: Array[String]=[]
		if definitions[row.key] is EquipmentData: destinations.append(str(row.actor)+".pack")
		else: destinations=scratch.actor_containers(row.actor)
		var remaining:=int(row.quantity)
		var uid: String=row.uid
		for destination in destinations:
			var accepted:=mini(remaining,scratch.space(destination,row.key,row.properties))
			if row.key in ["clean_water","dirty_water"]: accepted=mini(accepted,maxi(0,(rules.maximum_water if rules else 4)-scratch.count(row.actor,"clean_water")-scratch.count(row.actor,"dirty_water")))
			if accepted>0:
				scratch._insert(destination,row.key,accepted,uid,row.properties)
				uid=""
				remaining-=accepted
			if remaining==0: break
		if remaining>0: return OperationResult.reject("capacity")
	var committed:=scratch.snapshot()
	begin_batch()
	restore_actor(a,committed); restore_actor(b,committed)
	for id in committed.containers: _touch(id)
	for row in outgoing: _publish("item_transferred",_containers[row.source].owner,{"from":row.source,"to_actor":row.actor,"definition":row.key,"quantity":row.quantity,"uid":row.uid})
	_publish("trade_committed",a,{"partner":b,"costs":costs,"returns":returns})
	end_batch()
	return OperationResult.success()
func equipped(actor: String) -> Dictionary:
	return _containers.get(actor+".gear",{}).get("equipped",{}).duplicate()
func equip(actor: String,uid: String) -> OperationResult:
	var entry:=_instance(uid)
	var data:=definitions.get(entry.definition_id) as EquipmentData if entry else null
	var source:=locate(uid)
	if not data or source not in actor_containers(actor): return OperationResult.reject("not_owned")
	var gear:=actor+".gear"
	var old_uid: String=_containers[gear].equipped.get(str(data.slot_type),"")
	begin_batch()
	if not old_uid.is_empty():
		var old:=_instance(old_uid)
		if space(source,old.definition_id)==0 and _containers[source].items.size()>=int(_containers[source].capacity):
			# Incoming item frees its own slot before the displaced one is returned.
			_containers[source].items.erase(entry)
			_containers[gear].items.erase(old)
			_containers[gear].items.append(entry)
			_containers[source].items.append(old)
		else:
			_containers[gear].items.erase(old)
			_containers[source].items.append(old)
			_containers[source].items.erase(entry)
			_containers[gear].items.append(entry)
	else:
		_containers[source].items.erase(entry)
		_containers[gear].items.append(entry)
	_index(gear,entry)
	if not old_uid.is_empty(): _locations[old_uid]=source
	_containers[gear].equipped[str(data.slot_type)]=uid
	_touch(source); _touch(gear)
	end_batch()
	_publish("equipment_changed",actor,{"uid":uid,"slot":data.slot_type})
	return OperationResult.success(1)
func unequip(actor: String,slot: int) -> OperationResult:
	var gear:=actor+".gear"
	var uid: String=_containers.get(gear,{}).get("equipped",{}).get(str(slot),"")
	if uid.is_empty(): return OperationResult.reject("empty_slot")
	return commit(preview(gear,actor+".pack",uid,1))
func find_owned(actor: String,key: String) -> String:
	for id in actor_containers(actor):
		for entry: ItemInstance in _containers.get(id,{}).get("items",[]):
			if entry.definition_id==key: return entry.uid
	return ""
func weight(actor: String) -> float:
	var total:=0.0
	var ids:=actor_containers(actor)
	ids.append(actor+".gear")
	for id in ids:
		for entry: ItemInstance in _containers.get(id,{}).get("items",[]):
			var data:=definitions.get(entry.definition_id) as ItemData
			if data: total+=data.weight*entry.quantity
	return total
func snapshot() -> Dictionary:
	var saved: Dictionary={}
	for id in _containers:
		var record: Dictionary=_containers[id].duplicate(true)
		record.items=entries(id)
		saved[id]=record
	return {"next_uid":next_uid,"containers":saved}
func restore(data: Dictionary) -> void:
	_containers.clear()
	_instances.clear(); _locations.clear()
	next_uid=int(data.get("next_uid",1))
	for id in data.get("containers",{}):
		var record: Dictionary=data.containers[id].duplicate(true)
		var instances: Array=[]
		for raw in record.items:
			var entry:=ItemInstance.from_snapshot(raw)
			instances.append(entry)
			_index(id,entry)
		record.items=instances
		_containers[id]=record
func restore_actor(actor: String,data: Dictionary) -> void:
	for id in _containers.keys():
		if _containers[id].owner==actor:
			for entry: ItemInstance in _containers[id].items: _unindex(entry)
			_containers.erase(id)
	for id in data.containers:
		if data.containers[id].owner!=actor: continue
		var record: Dictionary=data.containers[id].duplicate(true)
		var instances: Array=[]
		for raw in record.items:
			var entry:=ItemInstance.from_snapshot(raw)
			instances.append(entry)
			_index(id,entry)
		record.items=instances
		_containers[id]=record
	# Never rewind the allocator: an interrupted operation may have issued IDs.
	next_uid=maxi(next_uid,int(data.next_uid))
func begin_batch() -> void: _batch_depth+=1
func end_batch(publish := true) -> void:
	_batch_depth=maxi(0,_batch_depth-1)
	if _batch_depth==0:
		var notify:=_dirty and publish
		_dirty=false
		if notify:
			var pending:=_pending_facts.duplicate(true)
			_pending_facts.clear()
			for fact in pending:
				if facts: facts.publish(fact.kind,fact.source,fact.data)
			changed.emit()
		elif not publish: _pending_facts.clear()
func _touch(id: String) -> void:
	_containers[id].revision+=1
	_dirty=true
	if _batch_depth==0: end_batch()
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not data.get("next_uid") is int or data.next_uid<1 or data.next_uid>1000000000 or not data.get("containers") is Dictionary or data.containers.size()>4096: return false
	var seen: Dictionary={}
	var highest:=0
	for id in data.containers:
		var c=data.containers[id]
		if not id is String or id.is_empty() or not c is Dictionary or not c.get("owner") is String or c.get("kind","") not in ["pocket","pack","gear","cache"] or not c.get("capacity") is int or c.capacity<1 or c.capacity>100000 or not c.get("items") is Array or c.items.size()>100000 or not c.get("equipped") is Dictionary: return false
		if not c.get("revision") is int or c.revision<0 or not c.get("attached") is bool or not c.get("region") is String or not c.get("position") is Array: return false
		if not c.attached and (c.kind != "pack" or c.region.is_empty() or c.position.size() != 2):
			return false
		if not c.position.is_empty():
			if c.position.size()!=2: return false
			for n in c.position:
				if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n))>100000: return false
		for raw in c.items:
			if not raw is Dictionary or not raw.get("uid") is String or not raw.uid.begins_with("item.") or not raw.uid.trim_prefix("item.").is_valid_int() or seen.has(raw.uid) or not raw.get("definition") is String or raw.definition.is_empty() or not raw.get("quantity") is int or raw.quantity<1 or raw.quantity>1000000 or not raw.get("properties",{}) is Dictionary: return false
			var number:=int(raw.uid.trim_prefix("item."))
			if number<1: return false
			highest=maxi(highest,number)
			seen[raw.uid]=id
		var used: Dictionary={}
		for slot in c.equipped:
			var uid=c.equipped[slot]
			if c.kind!="gear" or not slot is String or not slot.is_valid_int() or int(slot)<0 or int(slot)>8 or not uid is String or seen.get(uid,"")!=id or used.has(uid): return false
			used[uid]=true
	return data.next_uid>highest
func receive_into(id: String,key: String,amount: int,migration := false) -> int:
	if not _containers.has(id) or not definitions.has(key) or amount<=0: return 0
	var accepted:=amount if migration else mini(amount,space(id,key))
	if accepted>0: _insert(id,key,accepted)
	return accepted
func remove_from(id: String,key: String,amount: int) -> int:
	if amount<=0 or not _containers.has(id): return 0
	var removed:=0
	begin_batch()
	for entry: ItemInstance in _containers[id].items.duplicate():
		if entry.definition_id!=key: continue
		var taken:=mini(amount-removed,entry.quantity)
		entry.quantity-=taken; removed+=taken
		if entry.quantity==0:
			_containers[id].items.erase(entry)
			_unindex(entry)
		_touch(id)
		if removed==amount: break
	end_batch()
	return removed

func snapshot_owners(owners: Array) -> Dictionary:
	var saved: Dictionary={}
	for id in _containers:
		if _containers[id].owner not in owners: continue
		var record: Dictionary=_containers[id].duplicate(true)
		record.items=entries(id)
		saved[id]=record
	return {"next_uid":next_uid,"containers":saved}
func _publish(kind: String,source: String,data: Dictionary) -> void:
	if _batch_depth>0: _pending_facts.append({"kind":kind,"source":source,"data":data.duplicate(true)})
	elif facts: facts.publish(kind,source,data)

func valid_definitions(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	for container in data.containers.values():
		var slots: Dictionary={}
		for row in container.items:
			var definition:=definitions.get(row.definition) as ItemData
			if not definition or row.quantity>_stack_limit(row.definition): return false
			var props: Dictionary=row.get("properties",{})
			if definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY:
				if not props.get("doses") is int or props.doses<1 or props.doses>definition.use_profile.capacity: return false
			if props.has("coating"):
				var state=props.coating
				if not definition is EquipmentData or not state is Dictionary: return false
				var material:=definitions.get(state.get("id","")) as ItemData
				if not material or not material.use_profile or material.use_profile.kind!=ItemUseDefinition.Kind.COATING: return false
				if typeof(state.get("expires_at")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(state.expires_at)) or state.expires_at<0: return false
			if container.kind=="gear":
				if not definition is EquipmentData or container.equipped.get(str(definition.slot_type),"")!=row.uid: return false
				slots[str(definition.slot_type)]=row.uid
		if container.kind == "gear" and slots != container.equipped:
			return false
	return true

func ready_uid(actor: String,key: String) -> String:
	for row in entries(actor+".pocket"):
		if row.definition==key and int(row.properties.get("doses",1))>0: return row.uid
	return ""
func spend_instance(actor: String,uid: String,property: String,amount: int,revision := -1) -> bool:
	var source:=locate(uid)
	var entry:=_instance(uid)
	if not entry or source!=actor+".pocket" or amount<=0 or revision>=0 and _containers[source].revision!=revision: return false
	var value:=entry.quantity if property=="quantity" else int(entry.properties.get(property,0))
	if value<amount: return false
	if property=="quantity": entry.quantity-=amount
	elif property=="doses": entry.properties.doses=value-amount
	else: return false
	if value==amount:
		_containers[source].items.erase(entry)
		_unindex(entry)
	_touch(source)
	_publish("item_used",actor,{"uid":uid,"property":property,"amount":amount})
	return true
func set_properties(uid: String,properties: Dictionary) -> bool:
	var entry:=_instance(uid)
	if not entry: return false
	entry.properties=properties.duplicate(true)
	_touch(locate(uid))
	return true
func coating(uid: String) -> ItemUseDefinition:
	var entry:=_instance(uid)
	if not entry: return null
	var state: Dictionary=entry.properties.get("coating",{})
	if float(state.get("expires_at",0))<=clock_seconds: return null
	var definition:=definitions.get(state.get("id","")) as ItemData
	return definition.use_profile if definition else null
func state_text(uid: String) -> String:
	var entry:=_instance(uid)
	if not entry: return ""
	if entry.properties.has("doses"): return "剩余%d剂"%int(entry.properties.doses)
	var active:=coating(uid)
	if active:
		var definition:=definitions.get(active.id) as ItemData
		return "%s · 剩余%.0f秒"%[definition.display_name if definition else "涂层",float(entry.properties.coating.expires_at)-clock_seconds]
	return ""
