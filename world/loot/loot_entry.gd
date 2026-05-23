class_name LootEntry
extends Resource
## 掉落条目 — LootTable 中的单行配置


## 物品路径（res://content/items/...）
@export var item_path: String = ""

## 掉落权重（越高越常见）
@export var weight: int = 1

## 掉落数量范围
@export var min_count: int = 1
@export var max_count: int = 1
