class_name FieldWorkPanel
extends CanvasLayer
## Keyboard-only context display. It neither pauses nor captures pointer input.
var text: Label
var bar: ProgressBar
func _ready() -> void:
	layer = GameUIStyle.LAYER_RUN + 1
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -340
	panel.offset_right = -18
	panel.offset_top = -380
	panel.offset_bottom = -88
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.96, 6, GameUIStyle.BORDER_STRONG))
	add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_label(text, 13, GameUIStyle.TEXT_MAIN)
	box.add_child(text)
	bar = ProgressBar.new()
	bar.max_value = 1
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_progress(bar, GameUIStyle.GOLD, 8)
	box.add_child(bar)
	hide()

func display(message: String, progress: float = -1.0) -> void:
	text.text = message
	bar.visible = progress >= 0
	bar.value = maxf(0, progress)
	show()
