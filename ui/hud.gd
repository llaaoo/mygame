extends CanvasLayer

var death_screen: Control = null

var player: Player = null
var health_bar: ProgressBar = null
var health_label: Label = null
var mana_bar: ProgressBar = null
var mana_label: Label = null
var xp_bar: ProgressBar = null
var stats_label: Label = null
var skill_bar: SkillBar = null
var buff_ui: BuffStatusUI = null
var summon_ui: SummonStatusUI = null
var skill_tree_ui: SkillTreeUI = null
var level_up_ui: LevelUpUI = null

var _death_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	await get_tree().process_frame
	_connect_player()


func _build_ui() -> void:
	var margin := $MarginContainer as MarginContainer
	for child in margin.get_children():
		child.queue_free()

	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root)

	_build_status_panel(root)
	_build_right_stack(root)
	_build_skill_bar(root)


func _build_status_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 285
	panel.offset_bottom = 102
	panel.custom_minimum_size = Vector2(285, 102)
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.76, 5))
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Player"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(title, 13, GameUIStyle.GOLD)
	title_row.add_child(title)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUIStyle.apply_label(stats_label, 10, GameUIStyle.TEXT_MUTED)
	title_row.add_child(stats_label)

	health_bar = _make_bar(GameUIStyle.HEALTH)
	health_label = _add_resource_row(vbox, "HP", health_bar, GameUIStyle.HEALTH)

	mana_bar = _make_bar(GameUIStyle.MANA)
	mana_label = _add_resource_row(vbox, "MP", mana_bar, GameUIStyle.MANA)

	xp_bar = _make_bar(GameUIStyle.XP)
	_add_resource_row(vbox, "XP", xp_bar, GameUIStyle.XP)


func _build_right_stack(root: Control) -> void:
	var stack := VBoxContainer.new()
	stack.name = "RightStatusStack"
	stack.anchor_left = 1.0
	stack.anchor_right = 1.0
	stack.anchor_top = 0.0
	stack.offset_left = -225
	stack.offset_right = 0
	stack.offset_top = 0
	stack.offset_bottom = 220
	stack.add_theme_constant_override("separation", 6)
	root.add_child(stack)

	buff_ui = BuffStatusUI.new()
	buff_ui.name = "BuffStatusUI"
	stack.add_child(buff_ui)

	summon_ui = SummonStatusUI.new()
	summon_ui.name = "SummonStatusUI"
	stack.add_child(summon_ui)


func _build_skill_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "SkillBarPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -176
	panel.offset_right = 176
	panel.offset_top = -62
	panel.offset_bottom = -14
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.76, 6))
	root.add_child(panel)

	skill_bar = SkillBar.new()
	skill_bar.name = "SkillBar"
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_bar.add_theme_constant_override("separation", 6)
	panel.add_child(skill_bar)


func _add_resource_row(parent: VBoxContainer, label_text: String, bar: ProgressBar, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(24, 0)
	label.text = label_text
	GameUIStyle.apply_label(label, 10, color)
	row.add_child(label)

	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var value := Label.new()
	value.custom_minimum_size = Vector2(58, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUIStyle.apply_label(value, 10, GameUIStyle.TEXT_MAIN)
	row.add_child(value)
	return value


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 100
	bar.add_theme_stylebox_override("background", GameUIStyle.bar_bg())
	bar.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(color))
	return bar


func _connect_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		var root := get_tree().current_scene
		player = root.get_node_or_null("Player") as Player if root else null

	if not player:
		await get_tree().create_timer(1.0).timeout
		_connect_player()
		return

	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	if not player.mp_changed.is_connected(_on_mp_changed):
		player.mp_changed.connect(_on_mp_changed)
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	_on_health_changed(player.health_component.hp, player.health_component.max_hp)
	_on_mp_changed(player.mana_component.mp, player.mana_component.max_mp)
	skill_bar.setup(player.skill_manager)

	if player.stats_component:
		if not player.stats_component.stat_changed.is_connected(_on_stat_changed):
			player.stats_component.stat_changed.connect(_on_stat_changed)
		if not player.stats_component.leveled_up.is_connected(_on_level_up):
			player.stats_component.leveled_up.connect(_on_level_up)

	buff_ui.setup(player)
	summon_ui.setup(player)
	_setup_skill_tree_ui()
	_setup_level_up_ui()
	_update_stats_display()


func _setup_skill_tree_ui() -> void:
	if skill_tree_ui:
		return
	skill_tree_ui = SkillTreeUI.new()
	skill_tree_ui.name = "SkillTreeUI"
	get_tree().current_scene.add_child.call_deferred(skill_tree_ui)
	skill_tree_ui.call_deferred("setup", player)


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_label.text = "%d / %d" % [current_hp, max_hp]


func _on_mp_changed(current_mp: int, max_mp: int) -> void:
	mana_bar.max_value = max_mp
	mana_bar.value = current_mp
	mana_label.text = "%d / %d" % [current_mp, max_mp]


func _on_player_died() -> void:
	_death_active = true
	for child in get_tree().current_scene.get_children():
		if child is CanvasLayer and child != self:
			child.hide()

	if death_screen:
		death_screen.queue_free()

	var btn := Button.new()
	btn.name = "DeathScreen"
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	death_screen = btn
	add_child(death_screen)
	move_child(death_screen, get_child_count() - 1)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

	var label := Label.new()
	label.text = "You died\n\nClick or press any key to reload"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(label, 30, Color.WHITE)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)

	btn.pressed.connect(_on_retry_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if _death_active and event.is_pressed():
		_on_retry_pressed()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main.tscn")


func _on_stat_changed(_stat_name: String, _new_value: int) -> void:
	_update_stats_display()


func _on_level_up(new_level: int) -> void:
	_update_stats_display()
	if level_up_ui:
		level_up_ui._on_level_up(new_level)


func _setup_level_up_ui() -> void:
	if level_up_ui:
		return
	var lui_scene := load("res://ui/level_up_ui.tscn") as PackedScene
	if not lui_scene:
		return
	level_up_ui = lui_scene.instantiate() as LevelUpUI
	level_up_ui.name = "LevelUpUI"
	get_tree().current_scene.add_child.call_deferred(level_up_ui)
	level_up_ui.call_deferred("setup", player.stats_component)
	if not level_up_ui.allocation_confirmed.is_connected(_update_stats_display):
		level_up_ui.allocation_confirmed.connect(_update_stats_display)


func _update_stats_display() -> void:
	if not player or not stats_label:
		return
	var s := player.stats_component
	stats_label.text = "Lv.%d STR %d INT %d AGI %d END %d" % [
		s.level, s.strength, s.intelligence, s.agility, s.endurance,
	]
	if xp_bar:
		xp_bar.max_value = max(1, s.exp_to_next)
		xp_bar.value = s.experience
