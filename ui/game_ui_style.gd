class_name GameUIStyle
extends RefCounted

const PANEL_BG := Color(0.035, 0.04, 0.055, 0.86)
const PANEL_BG_SOLID := Color(0.045, 0.05, 0.065, 0.96)
const PANEL_BORDER := Color(0.42, 0.36, 0.25, 0.9)
const SLOT_BG := Color(0.075, 0.08, 0.10, 0.92)
const TEXT_MAIN := Color(0.92, 0.88, 0.78, 1.0)
const TEXT_MUTED := Color(0.64, 0.67, 0.70, 1.0)
const GOLD := Color(0.95, 0.72, 0.32, 1.0)
const HEALTH := Color(0.72, 0.16, 0.12, 1.0)
const MANA := Color(0.18, 0.36, 0.78, 1.0)
const XP := Color(0.48, 0.66, 0.36, 1.0)


static func panel_style(alpha: float = 0.86, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = PANEL_BORDER
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func slot_style(highlight: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.095, 0.07, 0.96) if highlight else SLOT_BG
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = GOLD if highlight else Color(0.26, 0.28, 0.32, 1.0)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


static func bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.012, 0.016, 0.88)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.12, 0.13, 0.15, 1.0)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


static func apply_label(label: Label, size: int = 12, color: Color = TEXT_MAIN) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
