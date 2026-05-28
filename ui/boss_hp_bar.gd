class_name BossHPBar
extends CanvasLayer
## Boss 血条 — 顶部居中，自动显示/隐藏

var _bg: ColorRect = null
var _hp_bar: ColorRect = null
var _name_label: Label = null
var _hp_label: Label = null
var _boss: Boss = null


func _ready() -> void:
	layer = 90  # 低于 HUD(100)
	add_to_group("boss_bar")
	_build_ui()
	hide()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.5)
	_bg.custom_minimum_size = Vector2(400, 40)
	_bg.anchor_left = 0.3; _bg.anchor_right = 0.7
	_bg.anchor_top = 0.02; _bg.anchor_bottom = 0.02
	_bg.offset_bottom = 40
	add_child(_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.8, 0.15, 0.15, 1)
	_hp_bar.anchor_left = 0; _hp_bar.anchor_right = 1
	_hp_bar.anchor_top = 0; _hp_bar.anchor_bottom = 1
	_hp_bar.offset_left = 2; _hp_bar.offset_right = 2
	_hp_bar.offset_top = 2; _hp_bar.offset_bottom = 2
	_bg.add_child(_hp_bar)

	_name_label = Label.new()
	_name_label.anchor_left = 0; _name_label.anchor_right = 1
	_name_label.anchor_top = 0; _name_label.anchor_bottom = 1
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_bg.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.anchor_left = 1; _hp_label.anchor_right = 1
	_hp_label.anchor_top = 1; _hp_label.anchor_bottom = 1
	_hp_label.offset_left = -60; _hp_label.offset_top = -16
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_bg.add_child(_hp_label)


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
	_hp_bar.anchor_right = ratio
	# 血量<25%变黄
	_hp_bar.color = Color(0.8, 0.6, 0.1, 1) if ratio < 0.25 else Color(0.8, 0.15, 0.15, 1)
	_hp_label.text = "%d / %d" % [current, max_hp]
