class_name MapObjectData
extends Resource
## 地图物体配置数据 — 纯数据，无逻辑

## 基础属性
@export var display_name: String = ""
@export var max_hp: int = 10
@export var respawn_time: float = -1.0  ## -1=永久消失, 0=切场景重生, >0=N秒后重生

## 交互属性
@export var tags: Array[String] = []         ## ["wooden","flammable","obstacle"]
@export var reactions: Array[String] = []    ## 响应的技能标签 ["fire","ice","lightning"]
@export var is_interactable: bool = false    ## 是否可按E键交互（宝箱、门）
@export var is_persistent: bool = true       ## 是否持久化状态

## 破坏后果
@export var destruction_loot_scene: PackedScene  ## 破坏后掉落的拾取物
@export var destruction_effect_scene: PackedScene ## 破坏特效
@export var destruction_radius: float = 0.0       ## >0 时破坏产生 AOE 伤害（油桶引爆）
@export var destruction_aoe_damage: int = 0
@export var destruction_aoe_tags: Array[String] = []  ## AOE 的标签（用于连锁反应）

## 屏障属性（阻挡物专用）
@export var blocks_path: bool = false  ## 破坏前阻挡通行
