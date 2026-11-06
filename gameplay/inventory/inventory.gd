class_name Inventory
extends Resource
## 背包系统 — 可存储任意 ItemData + 数量的网格

## 背包容量
@export var capacity: int = 20:
	set(value):
		capacity = maxi(1, value)
		_resize_slots()

## 物品槽位数组（索引 → {item: ItemData, quantity: int}）
var _slots: Array[Dictionary] = []
var store: InventoryService
var container_id := ""


func _init() -> void:
	_resize_slots()


func _resize_slots() -> void:
	var old_size := _slots.size()
	_slots.resize(capacity)
	for i in range(old_size, capacity):
		_slots[i] = {"item": null, "quantity": 0}


## 添加物品（返回成功数量，0=背包满）
func add_item(item: ItemData, quantity: int = 1) -> int:
	if store:
		store.register_definition(item)
		return store.receive_into(container_id,item.id,quantity)
	if quantity <= 0: return 0
	var added = 0
	var remaining = quantity

	# 先尝试堆叠到已有槽位
	if item.stackable:
		for i in range(capacity):
			var slot = _slots[i]
			if slot.item == item and slot.quantity < item.max_stack:
				var space = item.max_stack - slot.quantity
				var to_add = min(space, remaining)
				slot.quantity += to_add
				remaining -= to_add
				added += to_add
				if remaining <= 0:
					return added

	# 填到空槽位
	for i in range(capacity):
		var slot = _slots[i]
		if slot.item == null:
			var to_add = min(item.max_stack if item.stackable else 1, remaining)
			slot.item = item
			slot.quantity = to_add
			remaining -= to_add
			added += to_add
			if remaining <= 0:
				return added

	return added


## 移除物品
func remove_item(item: ItemData, quantity: int = 1) -> int:
	if store: return store.remove_from(container_id,item.id,quantity)
	var removed = 0
	for i in range(capacity - 1, -1, -1):
		var slot = _slots[i]
		if slot.item == item:
			var to_remove = min(quantity - removed, slot.quantity)
			slot.quantity -= to_remove
			removed += to_remove
			if slot.quantity <= 0:
				slot.item = null
				slot.quantity = 0
			if removed >= quantity:
				return removed
	return removed


## 获取指定槽位
func get_slot(index: int) -> Dictionary:
	if store:
		var rows:=store.entries(container_id)
		if index>=0 and index<rows.size(): return {"item":store.definitions.get(rows[index].definition),"quantity":rows[index].quantity,"uid":rows[index].uid}
		return {"item":null,"quantity":0}
	if index >= 0 and index < capacity:
		return _slots[index]
	return {"item": null, "quantity": 0}


## 获取物品总数量
func get_item_count(item: ItemData) -> int:
	if store: return store.count_in(container_id,item.id)
	var count = 0
	for slot in _slots:
		if slot.item == item:
			count += slot.quantity
	return count


## 设置指定槽位（用于拖拽交换）
func set_slot(index: int, item: ItemData, quantity: int) -> void:
	if store:
		var existing:=get_slot(index)
		if existing.item: store.remove_from(container_id,existing.item.id,existing.quantity)
		if item: add_item(item,quantity)
		return
	if index >= 0 and index < capacity:
		_slots[index] = {"item": item, "quantity": quantity}


## 是否有足够空间
func has_space(item: ItemData, quantity: int = 1) -> bool:
	if store: return store.space(container_id,item.id)>=quantity
	var space = 0
	if item.stackable:
		for slot in _slots:
			if slot.item == item:
				space += item.max_stack - slot.quantity
	for slot in _slots:
		if slot.item == null:
			space += item.max_stack if item.stackable else 1
	return space >= quantity

func empty_slot_count() -> int:
	if store: return maxi(0,capacity-store.entries(container_id).size())
	var count := 0
	for slot in _slots:
		if not slot.item: count += 1
	return count

func bind_container(service: InventoryService, id: String) -> void:
	store=service
	container_id=id
	_slots.clear()

func swap_slots(a: int,b: int) -> void:
	if store:
		var items: Array=store.containers[container_id].items
		if a>=0 and b>=0 and a<items.size() and b<items.size():
			var old=items[a]; items[a]=items[b]; items[b]=old
		return
	if a>=0 and b>=0 and a<_slots.size() and b<_slots.size():
		var old=_slots[a]; _slots[a]=_slots[b]; _slots[b]=old
