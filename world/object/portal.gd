extends Area2D
class_name Portal
## 场景传送门 — 玩家进入时切换到目标场景


@export var target_path: String = ""              ## 目标场景路径
@export var target_label: String = "进入"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if target_path.is_empty():
		push_warning("Portal: 未设置 target_path")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if target_path.is_empty():
		return

	print("🚪 Portal: %s → %s" % [target_label, target_path])
	call_deferred("_do_transition")


func _do_transition() -> void:
	var packed := load(target_path) as PackedScene
	if not packed:
		push_error("Portal: 无法加载场景: %s" % target_path)
		return

	get_tree().change_scene_to_packed(packed)
