class_name SkillData
extends Resource
## 技能数据 — 纯数据层，描述"是什么"
## 每个技能实例是一个 .tres 文件
## 禁止在 SkillData 中掺杂逻辑字段

## ── 技能类型 ──
enum SkillType {
	PROJECTILE,   ## 投射物（火球、暗影弹）
	BUFF,         ## 自身增益（护盾、加速）
	AOE,          ## 范围效果（火雨、冰环）
	DASH,         ## 位移（闪现、冲锋）
	SUMMON,       ## 召唤（骷髅、元素、图腾）
}

## ── 核心标识（纯数据） ──
@export var id: String = ""                       ## 唯一标识符（推荐使用）
@export var skill_id: String = ""                 ## @deprecated 用 id 代替，保留兼容
@export var display_name: String = "未命名技能"
@export var icon: Texture2D
@export_multiline var description: String = ""

## ── 类型 & 标签 ──
@export var skill_type: SkillType = SkillType.PROJECTILE
@export var cast_type: String = ""               ## "instant" / "channel" / "charge" 等
@export var tags: Array[String] = []             ## ["fire", "shadow", "melee"] 用于 modifier 匹配

## ── 消耗 & 冷却（纯数据） ──
@export var mp_cost: int = 10
@export var cooldown: float = 2.0

## ── 伤害 & 缩放（纯数据，计算交给 SkillExecutor） ──
@export var damage: int = 25                     ## 基础伤害
@export var damage_scaling: float = 1.0          ## 魔法伤害系数（1.0 = 100% intelligence→magic_damage）
@export var range: float = 0.0                   ## 施法距离（0 = 使用 cast_distance 或默认）

## ── Archetype（运行时行为模板） ──
@export var archetype: String = ""               ## "linear_projectile" / "persistent_aoe" / "beam" 等

## ── 表现层（推荐） ──
@export var visual: ProjectileVisualData         ## 投射物视觉配置（贴图/颜色/缩放/音效）
@export var aoe_visual: AOEVisualData            ## AoE 视觉配置（颜色/缩放/半径/持续时间）

## ── 视觉（@deprecated 用 visual 替代） ──
@export var projectile_texture: Texture2D
@export var projectile_color: Color = Color.WHITE
@export var projectile_scale: float = 0.1

## ── 投射物专用 ──
@export var projectile_scene: PackedScene        ## @deprecated 用 archetype + SkillExecutor 统一加载
@export var projectile_speed: float = 500.0
@export var cast_distance: float = 30.0          ## 生成偏移

## ── Buff 专用 ──
@export var buff_resource: Buff                  ## Buff 资源（.tres）
@export var buff_duration: float = 5.0           ## 覆盖 Buff 的 duration（0=使用 Buff 自身值）

## ── AoE 专用 ──
@export var aoe_scene: PackedScene               ## @deprecated 用 archetype + SkillExecutor 统一加载
@export var aoe_radius: float = 100.0            ## AoE 半径
@export var aoe_color: Color = Color.WHITE       ## AoE 视觉颜色
@export var aoe_scale: float = 1.0               ## AoE 视觉缩放
@export var aoe_lifetime: float = 0.6            ## AoE 持续时间

## ── 位移专用 ──
@export var dash_distance: float = 200.0
@export var dash_speed: float = 800.0

## ── 召唤专用 ──
@export var summon_data: SummonData

## ── 效果列表（未来扩展） ──
## @export var effects: Array[Effect] = []

## ── 场景引用（唯一允许引用"逻辑资源"的字段） ──
@export var scene_path: String = ""              ## res://... 场景路径（字符串，比 PackedScene 更纯）

## ── 兼容旧字段（逐步淘汰） ──
@export var scene: PackedScene                   ## @deprecated 用 projectile_scene 代替


## 获取有效 id（兼容 skill_id 旧代码）
func get_id() -> String:
	return id if not id.is_empty() else skill_id
