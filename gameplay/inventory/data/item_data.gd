class_name ItemData
extends Resource
## 物品数据基类 — 所有物品（装备、消耗品、材料）继承此 Resource
##
## 每个物品实例是一个 .tres 文件，可在编辑器中可视化编辑

## 物品类型枚举
enum ItemType {
	GENERIC,      ## 通用/材料
	EQUIPMENT,    ## 装备（头盔、盔甲等）
	CONSUMABLE,   ## 消耗品（药水等）
	WEAPON,       ## 武器
}

## 唯一标识符（推荐格式："iron_helmet"）
@export var id: String = ""

## 显示名称
@export var display_name: String = "未命名物品"

## 图标
@export var icon: Texture2D

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
