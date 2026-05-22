class_name SkillData
extends Resource
## 技能数据 — 支持投射物 / Buff / AoE / 位移等多种类型
## 每个技能实例是一个 .tres 文件

## ── 技能类型 ──
enum SkillType {
	PROJECTILE,   ## 投射物（火球、暗影弹）
	BUFF,         ## 自身增益（护盾、加速）
	AOE,          ## 范围效果（火雨、冰环）
	DASH,         ## 位移（闪现、冲锋）
}

## ── 通用字段 ──
@export var skill_id: String = ""
@export var display_name: String = "未命名技能"
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var skill_type: SkillType = SkillType.PROJECTILE
@export var cooldown: float = 2.0
@export var mp_cost: int = 10

## ── 投射物专用 ──
@export var projectile_scene: PackedScene        ## 投射物场景
@export var projectile_speed: float = 500.0
@export var cast_distance: float = 30.0          ## 生成偏移
@export var damage: int = 25

## ── Buff 专用 ──
@export var buff_resource: Buff                  ## Buff 资源（.tres）
@export var buff_duration: float = 5.0           ## 覆盖 Buff 的 duration（0=使用 Buff 自身值）

## ── AoE 专用 ──
@export var aoe_scene: PackedScene               ## AoE 场景（Area2D，自毁型）
@export var aoe_radius: float = 100.0            ## AoE 半径（备用）

## ── 位移专用 ──
@export var dash_distance: float = 200.0
@export var dash_speed: float = 800.0

## ── 兼容旧字段（逐步淘汰） ──
@export var scene: PackedScene                   ## @deprecated 用 projectile_scene 代替
