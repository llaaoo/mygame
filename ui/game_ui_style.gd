class_name GameUIStyle
extends RefCounted

const LAYER_WORLD := 80
const LAYER_BOSS := 90
const LAYER_HUD := 100
const LAYER_TRACKER := 110
const LAYER_RUN := 120
const LAYER_MODAL := 180
const LAYER_CRITICAL := 200
const LAYER_DEBUG := 240

const PANEL_BG := Color(0.027, 0.031, 0.039, 0.90)
const PANEL_BG_SOLID := Color(0.035, 0.041, 0.052, 0.98)
const SURFACE := Color(0.055, 0.063, 0.078, 0.96)
const SURFACE_RAISED := Color(0.075, 0.086, 0.105, 0.98)
const PANEL_BORDER := Color(0.29, 0.32, 0.36, 0.92)
const BORDER_STRONG := Color(0.52, 0.43, 0.27, 0.95)
const SLOT_BG := Color(0.047, 0.054, 0.067, 0.96)
const TEXT_MAIN := Color(0.91, 0.92, 0.90, 1.0)
const TEXT_MUTED := Color(0.58, 0.62, 0.66, 1.0)
const TEXT_DISABLED := Color(0.36, 0.39, 0.43, 1.0)
const GOLD := Color(0.94, 0.70, 0.27, 1.0)
const ACCENT := Color(0.32, 0.65, 0.78, 1.0)
const SUCCESS := Color(0.32, 0.74, 0.45, 1.0)
const DANGER := Color(0.84, 0.27, 0.20, 1.0)
const HEALTH := Color(0.76, 0.18, 0.14, 1.0)
const MANA := Color(0.18, 0.43, 0.78, 1.0)
const XP := Color(0.45, 0.70, 0.38, 1.0)


static func panel_style(
	alpha: float = 0.90,
	radius: int = 6,
	border_color: Color = PANEL_BORDER,
	border_width: int = 1
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	sb.set_border_width_all(border_width)
	sb.border_color = border_color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func surface_style(highlight: bool = false, radius: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_RAISED if highlight else SURFACE
	sb.set_border_width_all(1)
	sb.border_color = GOLD if highlight else PANEL_BORDER
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


static func slot_style(highlight: bool = false) -> StyleBoxFlat:
	var sb := surface_style(highlight, 4)
	sb.bg_color = Color(0.095, 0.078, 0.045, 0.98) if highlight else SLOT_BG
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


static func button_style(state: String = "normal", accent: Color = ACCENT, selected: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var bg := SURFACE_RAISED if selected else SURFACE
	match state:
		"hover": bg = bg.lightened(0.08)
		"pressed": bg = bg.darkened(0.08)
		"disabled": bg = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.55)
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = accent if selected or state == "hover" else PANEL_BORDER
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func apply_button(button: Button, accent: Color = ACCENT, selected: bool = false) -> void:
	button.add_theme_stylebox_override("normal", button_style("normal", accent, selected))
	button.add_theme_stylebox_override("hover", button_style("hover", accent, selected))
	button.add_theme_stylebox_override("pressed", button_style("pressed", accent, selected))
	button.add_theme_stylebox_override("focus", button_style("hover", accent, selected))
	button.add_theme_stylebox_override("disabled", button_style("disabled", accent, selected))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 38.0)


static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	return sb


static func bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.008, 0.01, 0.014, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.13, 0.15, 0.18, 1.0)
	sb.set_corner_radius_all(2)
	return sb


static func apply_progress(bar: ProgressBar, color: Color, height: float = 10.0) -> void:
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", bar_bg())
	bar.add_theme_stylebox_override("fill", bar_fill(color))


static func apply_label(label: Label, size: int = 12, color: Color = TEXT_MAIN) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func apply_title(label: Label, size: int = 22) -> void:
	apply_label(label, size, GOLD)


static func apply_section_label(label: Label) -> void:
	apply_label(label, 11, TEXT_MUTED)
	label.uppercase = true


static func modal_backdrop(alpha: float = 0.72) -> Color:
	return Color(0.006, 0.008, 0.012, alpha)


static func begin_modal(owner: CanvasLayer) -> void:
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_to_group("modal_ui")
	for other in owner.get_tree().get_nodes_in_group("modal_ui"):
		if other != owner and other is CanvasLayer and other.visible and other.has_method("close"):
			other.close()
	owner.get_tree().paused = true
	var player := owner.get_tree().get_first_node_in_group("player")
	if player:
		player.set("ui_blocked", true)


static func end_modal(owner: CanvasLayer) -> void:
	for other in owner.get_tree().get_nodes_in_group("modal_ui"):
		if other != owner and other is CanvasLayer and other.visible:
			return
	owner.get_tree().paused = false
	var player := owner.get_tree().get_first_node_in_group("player")
	if player:
		player.set("ui_blocked", false)
