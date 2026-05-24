class_name WorldMarker
extends Node2D
## 世界锚点 — NPC Schedule 通过 marker_id 引用此节点
##
## 不要硬编码坐标。地图改了只改 marker 位置即可。
## 注意: 不能用 Marker2D（编辑器专用，运行时 global_position 归零）


@export var marker_id: String = ""
@export var tags: Array[String] = []


func _ready() -> void:
	MarkerRegistry.register(self)
