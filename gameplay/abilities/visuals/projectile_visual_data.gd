class_name ProjectileVisualData
extends Resource
## 投射物表现层数据 — 纯素材配置
## 与 Runtime 行为完全解耦，只描述"长什么样"

@export var texture: Texture2D                ## 贴图
@export var color: Color = Color.WHITE        ## 调制颜色
@export var scale: float = 0.1                ## 缩放
@export var trail_scene: PackedScene           ## 拖尾场景（可选）
@export var hit_effect: PackedScene            ## 命中特效场景（可选）
@export var sound_cast: AudioStream            ## 施放音效（可选）
@export var sound_hit: AudioStream             ## 命中音效（可选）
