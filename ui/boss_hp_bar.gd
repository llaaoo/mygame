class_name BossHPBar
extends CanvasLayer

var _panel: PanelContainer = null
var _hp_bar: ProgressBar = null
var _name_label: Label = null
var _hp_label: Label = null
var _boss: Boss = null


func _ready() -> void:
	layer = 90
	add_to_group("boss_bar")
	_build_ui()
	hide()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "BossPanel"
	_panel.anchor_left = 0.34
	_panel.anchor_right = 0.66
	_panel.anchor_top = 0.025
	_panel.anchor_bottom = 0.025
	_panel.offset_bottom = 46
	_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.72, 4))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(_name_label, 14, GameUIStyle.GOLD)
	top.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.custom_minimum_size = Vector2(74, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUIStyle.apply_label(_hp_label, 10, GameUIStyle.TEXT_MAIN)
	top.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 9)
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.add_theme_stylebox_override("background", GameUIStyle.bar_bg())
	_hp_bar.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(Color(0.82, 0.18, 0.14, 1.0)))
	vbox.add_child(_hp_bar)


func show_bar(boss: Boss) -> void:
	_boss = boss
	_name_label.text = boss.boss_name
	update_hp(boss.health_component.hp, boss.health_component.max_hp)
	show()


func hide_bar() -> void:
	_boss = null
	hide()


func update_hp(current: int, max_hp: int) -> void:
	if not _boss:
		return
	var ratio := clampf(float(current) / float(max_hp), 0.0, 1.0)
	_hp_bar.max_value = max(1, max_hp)
	_hp_bar.value = current
	var fill := Color(0.82, 0.58, 0.16, 1.0) if ratio < 0.25 else Color(0.82, 0.18, 0.14, 1.0)
	_hp_bar.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(fill))
	_hp_label.text = "%d / %d" % [current, max_hp]
