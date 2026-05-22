extends CanvasLayer
## HUD — 血条 / MP条 / 技能条 / 属性概要 / 死亡画面

@onready var death_screen: ColorRect = $DeathScreen

var player: Player = null
var health_bar: ProgressBar = null
var health_label: Label = null
var mana_bar: ProgressBar = null
var mana_label: Label = null
var skill_bar: SkillBar = null
var stats_label: Label = null
var level_up_ui: LevelUpUI = null


func _ready() -> void:
	_build_ui()
	var retry_btn = $DeathScreen/VBoxContainer/RetryButton
	if retry_btn and not retry_btn.pressed.is_connected(_on_retry_pressed):
		retry_btn.pressed.connect(_on_retry_pressed)
	await get_tree().process_frame
	_connect_player()


func _build_ui() -> void:
	var margin = $MarginContainer

	# 回收旧节点
	var old_hbox = margin.get_node_or_null("HBoxContainer")
	var old_hp_label: Label = null
	var old_hp_bar: ProgressBar = null
	if old_hbox:
		old_hp_label = old_hbox.get_node_or_null("HealthLabel") as Label
		old_hp_bar = old_hbox.get_node_or_null("HealthBar") as ProgressBar
		if old_hp_label:
			old_hbox.remove_child(old_hp_label)
		if old_hp_bar:
			old_hbox.remove_child(old_hp_bar)
		old_hbox.queue_free()

	# 新布局
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	margin.add_child(main_vbox)

	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(top_row)

	# HP
	health_bar = old_hp_bar if old_hp_bar else ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_bar.value = 100.0
	top_row.add_child(health_bar)

	health_label = old_hp_label if old_hp_label else Label.new()
	health_label.name = "HealthLabel"
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.text = "100 / 100"
	top_row.add_child(health_label)

	# MP
	mana_bar = ProgressBar.new()
	mana_bar.name = "ManaBar"
	mana_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mana_bar.max_value = 100
	mana_bar.value = 100
	mana_bar.add_theme_color_override("fill_color", Color(0.2, 0.4, 0.9, 1))
	top_row.add_child(mana_bar)

	mana_label = Label.new()
	mana_label.name = "ManaLabel"
	mana_label.add_theme_font_size_override("font_size", 14)
	mana_label.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(mana_label)

	# 技能条
	skill_bar = SkillBar.new()
	skill_bar.name = "SkillBar"
	skill_bar.add_theme_constant_override("separation", 4)
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(skill_bar)

	# 属性
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	main_vbox.add_child(stats_label)


func _connect_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		var root = get_tree().current_scene
		player = root.get_node_or_null("Player") as Player if root else null

	if player:
		player.health_changed.connect(_on_health_changed)
		player.mp_changed.connect(_on_mp_changed)
		player.died.connect(_on_player_died)

		health_bar.max_value = player.health_component.max_hp
		health_bar.value = player.health_component.hp
		health_label.text = "%d / %d" % [player.health_component.hp, player.health_component.max_hp]

		mana_bar.max_value = player.mana_component.max_mp
		mana_bar.value = player.mana_component.mp
		mana_label.text = "%d / %d" % [player.mana_component.mp, player.mana_component.max_mp]

		skill_bar.setup(player.skill_manager)

		player.stats_component.stat_changed.connect(_on_stat_changed)
		player.stats_component.leveled_up.connect(_on_level_up)
		_setup_level_up_ui()
		_update_stats_display()
		print("✅ HUD: 已连接到 Player")
	else:
		print("⚠️ HUD: 未找到 Player，1秒后重试...")
		await get_tree().create_timer(1.0).timeout
		_connect_player()


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_label.text = "%d / %d" % [current_hp, max_hp]


func _on_mp_changed(current_mp: int, max_mp: int) -> void:
	mana_bar.max_value = max_mp
	mana_bar.value = current_mp
	mana_label.text = "%d / %d" % [current_mp, max_mp]


func _on_player_died() -> void:
	if death_screen:
		death_screen.visible = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_stat_changed(_stat_name: String, _new_value: int) -> void:
	_update_stats_display()


func _on_level_up(new_level: int) -> void:
	_update_stats_display()
	if level_up_ui:
		level_up_ui._on_level_up(new_level)


func _setup_level_up_ui() -> void:
	var lui_scene := load("res://ui/level_up_ui.tscn") as PackedScene
	if not lui_scene:
		return
	level_up_ui = lui_scene.instantiate() as LevelUpUI
	level_up_ui.name = "LevelUpUI"
	get_tree().current_scene.add_child(level_up_ui)
	level_up_ui.setup(player.stats_component)
	level_up_ui.allocation_confirmed.connect(_update_stats_display)


func _update_stats_display() -> void:
	if not player or not stats_label:
		return
	var s = player.stats_component
	stats_label.text = "Lv.%d  💪%d 🧠%d 🏃%d 🛡️%d  XP:%d/%d" % [
		s.level, s.strength, s.intelligence, s.agility, s.endurance,
		s.experience, s.exp_to_next
	]
