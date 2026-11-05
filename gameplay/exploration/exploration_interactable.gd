class_name ExplorationInteractable
extends Node2D

var title := "交互"
var tint := Color(0.95, 0.7, 0.25)
var callback: Callable
var kind := "note"
var _label: Label
var _player: Node2D
var _label_time := 0.0
var _near := false

func _ready() -> void:
	match kind:
		"person": tint = Color(0.4, 0.95, 0.65)
		"passage": tint = Color(0.45, 0.75, 1.0)
		"mechanism": tint = Color(0.85, 0.6, 1.0)
	add_to_group("interactable")
	var interaction := Interactable.new()
	interaction.name = "Interactable"
	interaction.set_callback(func(_actor: Node2D):
		if callback.is_valid():
			callback.call())
	add_child(interaction)
	_label = Label.new()
	_label.position = Vector2(-100, -47)
	_label.size = Vector2(200, 32)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", tint)
	add_child(_label)
	set_title(title)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_update_proximity()
	queue_redraw()

func set_title(value: String) -> void:
	title = value
	if _label:
		_label.text = ("[E] " if _near else "") + title

func _process(delta: float) -> void:
	_label_time += delta
	if _label_time >= .15:
		_label_time = 0
		_update_proximity()

func _update_proximity() -> void:
	if not is_instance_valid(_player): return
	var distance := global_position.distance_squared_to(_player.global_position)
	var near := distance < PlayerInputController.INTERACT_RANGE * PlayerInputController.INTERACT_RANGE
	if _near != near:
		_near = near
		set_title(title)
		queue_redraw()
	_label.visible = distance < 280 * 280 or kind in ["passage", "person"]
	_label.modulate.a = 1.0 if near else .7

func _draw() -> void:
	if _near: draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color(tint, .35), 1, true)
	draw_circle(Vector2.ZERO, 19, Color(tint, 0.18))
	draw_arc(Vector2.ZERO, 20, 0, TAU, 32, tint, 2, true)
	match kind:
		"person":
			draw_circle(Vector2(0, -6), 5, tint)
			draw_line(Vector2(0, 0), Vector2(0, 10), tint, 3)
			draw_line(Vector2(-8, 4), Vector2(8, 4), tint, 2)
		"passage":
			draw_line(Vector2(-8, 0), Vector2(8, 0), tint, 3)
			draw_polyline(PackedVector2Array([Vector2(1, -8), Vector2(9, 0), Vector2(1, 8)]), tint, 2)
		"mechanism":
			draw_rect(Rect2(-8, -8, 16, 16), tint, false, 2)
			draw_line(Vector2(-10, 10), Vector2(10, -10), tint, 2)
		_:
			draw_rect(Rect2(-7, -10, 14, 20), tint, false, 2)
			draw_line(Vector2(-4, -3), Vector2(4, -3), tint, 1)
			draw_line(Vector2(-4, 3), Vector2(4, 3), tint, 1)
