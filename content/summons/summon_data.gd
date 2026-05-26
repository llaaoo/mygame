class_name SummonData
extends Resource
## 召唤物数据 — 纯数据层，描述召唤物"是什么"
## 每个召唤物类型是一个 .tres 文件

## ── 核心标识 ──
@export var summon_name: String = "召唤物"
@export_multiline var description: String = ""

## ── 战斗属性 ──
@export var max_hp: int = 30
@export var damage: int = 8
@export var speed: float = 120.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.5

## ── 生命周期 ──
@export var lifetime: float = 30.0        ## 0 = 永久（直到 HP 归零）

## ── 表现层 ──
@export var texture: Texture2D
@export var color: Color = Color.WHITE
@export var scale: float = 0.3

## ── AI 参数 ──
@export var follow_distance: float = 80.0    ## 跟随距离（超过此距离向玩家移动）
@export var leash_distance: float = 500.0    ## 脱战距离（超过此距离放弃目标回到跟随）
