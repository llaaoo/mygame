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

const PANEL_BG := Color(0.075, 0.105, 0.115, 0.97)
const PANEL_BG_SOLID := Color(0.065, 0.095, 0.105, 0.99)
const SURFACE := Color(0.11, 0.15, 0.16, 0.94)
const SURFACE_RAISED := Color(0.16, 0.205, 0.21, 0.98)
const PANEL_BORDER := Color(0.31, 0.36, 0.35, 0.52)
const BORDER_STRONG := Color(0.58, 0.55, 0.43, 0.75)
const SLOT_BG := Color(0.025, 0.042, 0.046, 0.80)
const TEXT_MAIN := Color(0.93, 0.92, 0.86, 1.0)
const TEXT_MUTED := Color(0.65, 0.69, 0.66, 1.0)
const TEXT_DISABLED := Color(0.45, 0.49, 0.48, 1.0)
const GOLD := Color(0.82, 0.70, 0.47, 1.0)
const ACCENT := Color(0.51, 0.71, 0.68, 1.0)
const SUCCESS := Color(0.32, 0.74, 0.45, 1.0)
const DANGER := Color(0.84, 0.27, 0.20, 1.0)
const HEALTH := Color(0.71, 0.29, 0.25, 1.0)
const MANA := Color(0.30, 0.53, 0.69, 1.0)
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
	sb.set_corner_radius_all(mini(radius,4))
	sb.shadow_color = Color(0, 0, 0, .32)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func surface_style(highlight: bool = false, radius: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE_RAISED if highlight else SURFACE
	sb.set_border_width_all(1)
	sb.border_color = Color(GOLD,.8) if highlight else Color(PANEL_BORDER,.35)
	sb.set_corner_radius_all(mini(radius,4))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


static func slot_style(highlight: bool = false) -> StyleBoxFlat:
	var sb := surface_style(highlight, 4)
	sb.bg_color = Color(0.10, 0.14, 0.13, 0.94) if highlight else SLOT_BG
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
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
	sb.border_color = Color(accent,.85) if selected or state == "hover" else Color(PANEL_BORDER,.25)
	sb.border_width_left=2 if selected else 0
	sb.border_width_top=1 if selected else 0
	sb.border_width_bottom=1
	sb.border_width_right=1 if selected else 0
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func apply_button(button: Button, accent: Color = ACCENT, selected: bool = false) -> void:
	ButtonMotion.install(button)
	button.add_theme_stylebox_override("normal", button_style("normal", accent, selected))
	button.add_theme_stylebox_override("hover", button_style("hover", accent, selected))
	button.add_theme_stylebox_override("pressed", button_style("pressed", accent, selected))
	button.add_theme_stylebox_override("focus", button_style("hover", accent, selected))
	button.add_theme_stylebox_override("disabled", button_style("disabled", accent, selected))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	button.add_theme_font_size_override("font_size", 14)
	if button.text=="关闭":
		button.icon=icon("x"); button.expand_icon=true; button.add_theme_constant_override("icon_max_width",14)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 38.0)


static func apply_tab(button: Button, selected := false) -> void:
	apply_button(button,GOLD,selected)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style:=button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.bg_color=Color(GOLD,.09) if selected else Color(SURFACE,.35) if state in ["hover","focus"] else Color.TRANSPARENT
		style.set_border_width_all(0)
		style.border_width_bottom=2 if selected else 1
		style.border_color=GOLD if selected else Color(PANEL_BORDER,.25)
		style.content_margin_left=10; style.content_margin_right=10
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",GOLD if selected else TEXT_MUTED)

static func primary(button: Button) -> void:
	apply_button(button,GOLD,true)
	button.add_theme_font_size_override("font_size",15)

static func decorate(panel: Control) -> void:
	var background:=ExpeditionBackdrop.new()
	panel.add_child(background); panel.move_child(background,0)

static func navigation(host: Node, page: String, request: Callable) -> ExpeditionNavigation:
	var bar:=ExpeditionNavigation.new(); bar.current_page=page; bar.navigate=request
	host.add_child(bar)
	bar.visible=request.is_valid()
	return bar

static func folio_title(host: Node, title: String) -> Label:
	var box:=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",2); host.add_child(box)
	var kicker:=Label.new(); kicker.text="灰 河 谷    /    行 路 者 手 册"
	apply_label(kicker,12,GOLD); box.add_child(kicker)
	var heading:=Label.new(); heading.text=title
	heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	apply_label(heading,26,TEXT_MAIN); box.add_child(heading)
	return heading

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
	label.add_theme_font_size_override("font_size", maxi(size,12))
	label.add_theme_color_override("font_color", color)


static func apply_title(label: Label, size: int = 22) -> void:
	apply_label(label, size, GOLD)


static func apply_section_label(label: Label) -> void:
	apply_label(label, 11, TEXT_MUTED)
	label.uppercase = true


static func modal_backdrop(alpha: float = 0.72) -> Color:
	return Color(0.008, 0.018, 0.022, alpha)


static func begin_modal(owner: CanvasLayer) -> void:
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_to_group("modal_ui")
	var panels:=owner.find_children("*","PanelContainer",true,false)
	if not panels.is_empty(): UIMotion.enter(panels[0] as Control)
	var presentation:=PresentationDirector.for_node(owner)
	if presentation: presentation.emit_cue(&"ui_open",Vector2.ZERO)
	for other in owner.get_tree().get_nodes_in_group("modal_ui"):
		if other != owner and other is CanvasLayer and other.visible:
			if other.has_method("close"): other.close()
			elif other.has_meta("close_request"): other.get_meta("close_request").call()
	var player := owner.get_tree().get_first_node_in_group("player")
	if player:
		if is_instance_valid(player.get("material_wheel")): player.material_wheel.close()
		player.set("ui_blocked", true)
		if player.get("input_controller"): player.input_controller.suppress_held_shortcuts()


static func end_modal(owner: CanvasLayer) -> void:
	for other in owner.get_tree().get_nodes_in_group("modal_ui"):
		if other != owner and other is CanvasLayer and other.visible:
			return
	var player := owner.get_tree().get_first_node_in_group("player")
	if player:
		player.set("ui_blocked", false)
		if player.get("input_controller"):
			player.input_controller.pointer_consumed()
			player.input_controller.suppress_held_shortcuts()

static func icon(id: String) -> Texture2D:
	var path:="res://content/art/third_party/lucide/"+id+".svg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func font() -> Font:
	return load("res://ui/themes/body_font.tres") as Font

static func quiet_panel(alpha := .48) -> StyleBoxFlat:
	var style:=panel_style(alpha,2,Color.TRANSPARENT,0)
	style.shadow_size=0
	return style

static func keycap(text: String) -> Label:
	var label:=Label.new(); label.text=text
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size=Vector2(24,22)
	apply_label(label,12,TEXT_MAIN)
	return label

static func install_theme(window: Window) -> void:
	window.gui_embed_subwindows=true
	# Project custom themes load before first-import fonts exist. Install only
	# when a real game UI enters the tree, after imported resources are available.
	if window.theme==null: window.theme=load("res://ui/themes/grayriver.tres") as Theme

static func close_gameplay_views(actor: Node) -> void:
	for view in actor.get_tree().get_nodes_in_group("modal_ui"):
		if view is CanvasLayer and view.visible:
			if view.has_method("close"): view.close()
			elif view.has_meta("close_request"): view.get_meta("close_request").call()

static func can_open(view: Node) -> bool:
	for other in view.get_tree().get_nodes_in_group("modal_ui"):
		if other!=view and other is CanvasLayer and other.visible and other.get_meta("locked",false): return false
	return true
