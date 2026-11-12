class_name ItemData
extends Resource
## 物品数据基类 — 所有物品（装备、消耗品、材料）继承此 Resource
##
## .tres files are immutable definitions; ItemInstance owns identity and quantities.

## 物品类型枚举
enum ItemType {
	GENERIC,      ## 通用/材料
	EQUIPMENT,    ## 装备（头盔、盔甲等）
	CONSUMABLE,   ## 消耗品（药水等）
	WEAPON,       ## 武器
}

## 唯一标识符（推荐格式："iron_helmet"）
@export var id: String = ""
@export var use_profile: ItemUseDefinition
@export_range(0,100,0.05) var weight := 0.2

## 显示名称
@export var display_name: String = "未命名物品"

## 图标
@export var icon: Texture2D

## Inspection art loads only when selected, so the catalog does not retain every large image.
## The compact icon remains independent; instance state stays on ItemInstance.
@export_file("*.png","*.webp","*.jpg","*.jpeg","*.svg") var illustration_path := ""

## 描述文本
@export_multiline var description: String = ""

## 物品分类
@export var item_type: ItemType = ItemType.GENERIC

## 是否可堆叠
@export var stackable: bool = false

## 最大堆叠数（仅 stackable=true 时有效）
@export var max_stack: int = 1

## 品质等级（0=普通, 1=稀有, 2=史诗, 3=传说）
@export var rarity: int = 0

## 出售价格
@export var sell_price: int = 0

func illustration_error() -> String:
	if illustration_path.is_empty(): return ""
	if not illustration_path.begins_with("res://") or illustration_path.get_extension().to_lower() not in ["png","webp","jpg","jpeg","svg"] or not ResourceLoader.exists(illustration_path,"Texture2D"):
		return "Invalid item artwork: %s [%s]"%[id,illustration_path]
	return ""
