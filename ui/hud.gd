extends CanvasLayer

@export var player: Player
@export var run_manager: RunManager

var death_screen: Control = null
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
var _actor_status: ActorStatusView


func _ready() -> void:
	GameUIStyle.install_theme(get_window())
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = GameUIStyle.LAYER_HUD
	add_to_group("hud_ui")
	_build_ui()
	_connect_player.call_deferred()


func _build_ui() -> void:
	var margin := $MarginContainer as MarginContainer
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in margin.get_children():
		child.queue_free()

	var root := Control.new()
	root.name = "HUDRoot"
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root)

	_build_status_panel(root)
	_build_right_stack(root)
	_build_skill_bar(root)


func _build_status_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_top = -178
	panel.offset_right = 220
	panel.offset_bottom = -22
	panel.custom_minimum_size = Vector2(200, 150)
	panel.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.56))
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "行者"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(title, 15, GameUIStyle.GOLD)
	title_row.add_child(title)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUIStyle.apply_label(stats_label, 10, GameUIStyle.TEXT_MUTED)
	title_row.add_child(stats_label)

	health_bar = _make_bar(GameUIStyle.HEALTH)
	health_label = _add_resource_row(vbox, "生命", health_bar, GameUIStyle.HEALTH)

	mana_bar = _make_bar(GameUIStyle.MANA)
	mana_label = _add_resource_row(vbox, "法力", mana_bar, GameUIStyle.MANA)

	_actor_status=ActorStatusView.new()
	_actor_status.compact=true
	vbox.add_child(_actor_status)
	xp_bar=_make_bar(GameUIStyle.XP)
	GameUIStyle.apply_progress(xp_bar,GameUIStyle.XP,2)
	xp_bar.modulate.a=.45
	vbox.add_child(xp_bar)


func _build_right_stack(root: Control) -> void:
	var stack := VBoxContainer.new()
	stack.name = "RightStatusStack"
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_left = 24
	stack.offset_right = 298
	stack.offset_top = -288
	stack.offset_bottom = -218
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
	panel.offset_left = -256
	panel.offset_right = 256
	panel.offset_top = -78
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.48))
	root.add_child(panel)

	skill_bar = SkillBar.new()
	skill_bar.name = "SkillBar"
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_bar.add_theme_constant_override("separation", 5)
	panel.add_child(skill_bar)


func _add_resource_row(parent: VBoxContainer, label_text: String, bar: ProgressBar, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var glyph:=TextureRect.new()
	glyph.texture=GameUIStyle.icon("heart" if label_text=="生命" else "droplet")
	glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size=Vector2(18,18)
	glyph.modulate=color.lightened(.25)
	glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE
	glyph.tooltip_text=label_text
	row.add_child(glyph)

	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var value := Label.new()
	value.custom_minimum_size = Vector2(54, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameUIStyle.apply_label(value, 12, GameUIStyle.TEXT_MAIN)
	row.add_child(value)
	return value


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 11)
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 100
	GameUIStyle.apply_progress(bar, color, 11)
	return bar


func _connect_player() -> void:
	if not is_instance_valid(player) or not player.is_node_ready():
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
	var buffs := player.get_node_or_null("BuffManager") as BuffManager
	if buffs and not buffs.buffs_changed.is_connected(_update_stats_display):
		buffs.buffs_changed.connect(_update_stats_display)

	if _actor_status: _actor_status.context=player.actor_context
	buff_ui.setup(player)
	summon_ui.setup(player)
	_setup_skill_tree_ui()
	_setup_level_up_ui()
	_update_stats_display()


func _setup_skill_tree_ui() -> void:
	if player and player.exploration_mode:
		return
	if skill_tree_ui:
		return
	skill_tree_ui = SkillTreeUI.new()
	skill_tree_ui.name = "SkillTreeUI"
	add_child(skill_tree_ui)
	skill_tree_ui.setup(player)


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_label.text = "%d / %d" % [current_hp, max_hp]


func _on_mp_changed(current_mp: int, max_mp: int) -> void:
	mana_bar.max_value = max_mp
	mana_bar.value = current_mp
	mana_label.text = "%d / %d" % [current_mp, max_mp]


func _on_player_died() -> void:
	if player.exploration_mode:
		return # The campaign owns recovery and its modal UI.
	if run_manager and run_manager.owns_active_room() and run_manager.state.status in [RunState.Status.RUNNING, RunState.Status.BOSS, RunState.Status.REWARD]:
		return
	_death_active = true
	for child in get_parent().get_children():
		if child is CanvasLayer and child != self:
			child.hide()
	if skill_tree_ui:
		skill_tree_ui.hide()
	if level_up_ui:
		level_up_ui.hide()

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
	label.text = "战斗结束\n\n按任意键重新开始"
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
	get_tree().reload_current_scene()


func _on_stat_changed(_stat_name: String, _new_value: int) -> void:
	_update_stats_display()


func _on_level_up(new_level: int) -> void:
	_update_stats_display()
	# Level-up never takes combat input. Allocation is an explicit menu request.


func _setup_level_up_ui() -> void:
	if player and player.exploration_mode:
		return
	if level_up_ui:
		return
	var lui_scene := load("res://ui/level_up_ui.tscn") as PackedScene
	if not lui_scene:
		return
	level_up_ui = lui_scene.instantiate() as LevelUpUI
	level_up_ui.name = "LevelUpUI"
	add_child(level_up_ui)
	level_up_ui.setup(player.stats_component)
	if not level_up_ui.allocation_confirmed.is_connected(_update_stats_display):
		level_up_ui.allocation_confirmed.connect(_update_stats_display)


func _update_stats_display() -> void:
	if not player or not stats_label:
		return
	var s := player.stats_component
	stats_label.text = "等级 %d"%s.level
	stats_label.tooltip_text="力量 %d · 智力 %d · 敏捷 %d · 耐力 %d"%[s.effective_stat("strength"),s.effective_stat("intelligence"),s.effective_stat("agility"),s.effective_stat("endurance")]
	if xp_bar:
		xp_bar.max_value = max(1, s.exp_to_next)
		xp_bar.value = s.experience

func _process(_delta: float) -> void:
	# Campaign actor binding completes after the base HUD enters the tree.
	if _actor_status and is_instance_valid(player) and _actor_status.context!=player.actor_context:
		_actor_status.context=player.actor_context
