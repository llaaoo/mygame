class_name Inventory
extends Resource
## 背包系统 — 可存储任意 ItemData + 数量的网格

## 背包容量
@export var capacity: int = 20

## 物品槽位数组（索引 → {item: ItemData, quantity: int}）
var _slots: Array[Dictionary] = []


func _init() -> void:
	_slots.resize(capacity)
	for i in range(capacity):
		_slots[i] = {"item": null, "quantity": 0}


## 添加物品（返回成功数量，0=背包满）
func add_item(item: ItemData, quantity: int = 1) -> int:
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
	if index >= 0 and index < capacity:
		return _slots[index]
	return {"item": null, "quantity": 0}


## 获取物品总数量
func get_item_count(item: ItemData) -> int:
	var count = 0
	for slot in _slots:
		if slot.item == item:
			count += slot.quantity
	return count


## 是否有足够空间
func has_space(item: ItemData, quantity: int = 1) -> bool:
	var space = 0
	if item.stackable:
		for slot in _slots:
			if slot.item == item:
				space += item.max_stack - slot.quantity
	for slot in _slots:
		if slot.item == null:
			space += item.max_stack if item.stackable else 1
	return space >= quantity
