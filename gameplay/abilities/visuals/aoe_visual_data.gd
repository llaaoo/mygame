class_name AOEVisualData
extends Resource
## AoE 表现层数据 — 纯素材配置
## 与 Runtime 行为完全解耦，只描述"长什么样 + 多大范围"

@export var color: Color = Color.WHITE        ## 调制颜色
@export var scale: float = 1.0                ## 视觉缩放
@export var radius: float = 80.0              ## 碰撞半径
@export var lifetime: float = 0.6             ## 持续时间
@export var hit_effect: PackedScene            ## 命中特效（可选）
@export var sound_cast: AudioStream            ## 施放音效（可选）
