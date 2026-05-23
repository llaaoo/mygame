class_name LootTable
extends Resource
## 掉落表 — 所有权重之和 > 0 时随机掉落
##
## 用法:
##   var items: Array = loot_table.roll()
##   for entry in items:
##       spawn(entry.item_path, entry.count)


@export var entries: Array[LootEntry] = []


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
	for entry in entries:
		if entry.weight <= 0:
			continue
		if randf() < float(entry.weight) / float(total_weight):
			var count := randi_range(entry.min_count, entry.max_count)
			if count > 0:
				result.append({"item_path": entry.item_path, "count": count})

	return result
