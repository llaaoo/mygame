class_name SkillData
extends Resource
## 技能数据 — 定义一个技能的冷却、伤害、投射物等属性
## 每个技能实例是一个 .tres 文件

## 标识符
@export var skill_id: String = ""
## 显示名称
@export var display_name: String = "未命名技能"
## 图标
@export var icon: Texture2D
## 冷却时间（秒）
@export var cooldown: float = 2.0
## 伤害
@export var damage: int = 25
## 投射物场景（Area2D，需有 set_direction/set_caster 方法）
@export var scene: PackedScene
## 生成距离（距施法者的偏移）
@export var cast_distance: float = 30.0
## 投射物速度
@export var projectile_speed: float = 500.0
