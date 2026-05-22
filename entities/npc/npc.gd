extends CharacterBody2D
class_name NPC
## NPC 基类 — 挂载 StatsComponent 即可拥有属性
## 子类化用于商人/任务NPC/训练师等

@export var npc_name: String = "NPC"
@export var npc_color: Color = Color(0.3, 0.6, 1.0, 1)

@onready var stats_component: StatsComponent = $StatsComponent
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite:
		sprite.modulate = npc_color
		if sprite.texture:
			sprite.scale = Vector2(0.4, 0.4)
