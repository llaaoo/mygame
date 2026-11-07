class_name Portal
extends Area2D

@export var target_path: String = ""
@export var target_label: String = "Enter"
@export var is_region: bool = true
@export var target_marker_id: String = ""
@export var locked: bool = false
@export var locked_label: String = "Locked"


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_update_visual()
	if target_path.is_empty():
		push_warning("Portal: target_path is empty")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if locked:
		print("Portal locked: %s" % locked_label)
		return
	if target_path.is_empty():
		return

	print("Portal: %s -> %s" % [target_label, target_path])

	if is_region:
		_do_region_transition()
		return

	_change_scene.call_deferred()


func _change_scene() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or locked:
		return
	var packed := load(target_path) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)


func lock(message: String = "") -> void:
	locked = true
	if not message.is_empty():
		locked_label = message
	_update_visual()


func unlock() -> void:
	locked = false
	_update_visual()


func is_locked() -> bool:
	return locked


func _do_region_transition() -> void:
	var runtime := GameRuntime.instance
	var regions := runtime.get_region_runtime() if runtime else null
	if not regions:
		return
	var current := regions.get_current_region()
	if current and current.is_ancestor_of(self):
		regions.ensure_region(target_path, target_marker_id)


func _update_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color(0.35, 0.35, 0.38, 1.0) if locked else Color(0.2, 0.95, 0.55, 1.0)

	var label := get_node_or_null("Label") as Label
	if label:
		label.text = locked_label if locked else target_label
