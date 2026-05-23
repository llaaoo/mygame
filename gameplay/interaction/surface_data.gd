class_name SurfaceData
extends Resource
## SurfaceData — 表面状态配置（纯数据）
##
## 只有 5 种表面状态 (CONTRACT 9):
##   dry / wet / burning / frozen / oiled

@export var state: String = "dry"            ## dry / wet / burning / frozen / oiled
@export var duration: float = 5.0            ## 自然持续时间（秒）
@export var tick_damage: int = 0             ## 每 tick 伤害（0 = 无伤害）
@export var tick_interval: float = 1.0       ## 伤害 tick 间隔
@export var slow_multiplier: float = 1.0     ## 减速倍率（1.0=正常, 0.5=半速）
@export var color: Color = Color.WHITE       ## 调试/可视化颜色
@export var visual_scene: PackedScene        ## 可选可视化场景


func is_damaging() -> bool:
	return tick_damage > 0


func get_tick_damage() -> int:
	return tick_damage


func _to_string() -> String:
	return "SurfaceData(%s, dur=%.1f, dmg=%d)" % [state, duration, tick_damage]
