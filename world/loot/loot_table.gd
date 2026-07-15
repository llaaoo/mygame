class_name LootTable
extends Resource
## 掉落表 — 所有权重之和 > 0 时随机掉落
##
## 用法:
##   var items: Array = loot_table.roll()
##   for entry in items:
##       spawn(entry.item_path, entry.count)


@export var entries: Array[LootEntry] = []
@export_range(1, 10, 1) var min_rolls: int = 1
@export_range(1, 10, 1) var max_rolls: int = 1


## 执行一次随机掉落，返回 [{item_path, count}, ...]
func roll() -> Array[Dictionary]:
	if entries.is_empty():
		return []

	var total_weight := 0
	for entry in entries:
		total_weight += entry.weight

	if total_weight <= 0:
		return []

	var result: Array[Dictionary] = []
	var roll_count := randi_range(mini(min_rolls, max_rolls), maxi(min_rolls, max_rolls))
	for _roll in range(roll_count):
		var ticket := randi_range(1, total_weight)
		var selected: LootEntry
		for entry in entries:
			if entry.weight <= 0:
				continue
			ticket -= entry.weight
			if ticket <= 0:
				selected = entry
				break
		if selected:
			var count := randi_range(selected.min_count, selected.max_count)
			if count > 0:
				result.append({"item_path": selected.item_path, "count": count})

	return result
