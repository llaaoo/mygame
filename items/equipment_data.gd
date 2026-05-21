class_name EquipmentData
extends ItemData
## 装备数据 — 继承 ItemData，添加装备专属属性
##
## 每个装备实例是一个 .tres 文件

## 装备槽位类型
enum SlotType {
	HEAD,         ## 头部
	CHEST,        ## 胸部
	LEGS,         ## 腿部
	FEET,         ## 足部
	HANDS,        ## 手部
	LEFT_HAND,    ## 左手（副手）
	RIGHT_HAND,   ## 右手（主手）
}

## 所属槽位
@export var slot_type: SlotType = SlotType.HEAD

## 属性加成（在 BuffManager 中应用）
## 格式: { "max_hp": 20, "atk": 5, "move_speed": 10 }
@export var stat_modifiers: Dictionary = {}

## 百分比属性加成（如 {"atk": 0.1} = +10% 攻击力）
@export var stat_multipliers: Dictionary = {}

## 装备时激活的特殊 Buff（可选，PackedScene of Buff）
@export var on_equip_buff: PackedScene
