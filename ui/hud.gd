extends CanvasLayer
## HUD - 玩家血条 UI

@onready var health_bar: ProgressBar = $MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/HBoxContainer/HealthLabel
@onready var death_screen: ColorRect = $DeathScreen

var player: Player = null
var cooldown_bar: ProgressBar = null
var stats_label: Label = null
var level_up_ui: LevelUpUI = null

func _ready() -> void:
	_setup_cooldown_bar()
	# 确保重试按钮连接（编辑器连接可能丢失）
	var retry_btn = $DeathScreen/VBoxContainer/RetryButton
	if retry_btn and not retry_btn.pressed.is_connected(_on_retry_pressed):
		retry_btn.pressed.connect(_on_retry_pressed)
	# 延迟查找 Player（等场景完全加载后）
	await get_tree().process_frame
	_connect_player()

func _setup_cooldown_bar() -> void:
	# 尝试在 HBoxContainer 中查找 SkillCooldownBar
	var hbox = $MarginContainer/HBoxContainer
	cooldown_bar = hbox.get_node_or_null("SkillCooldownBar") as ProgressBar
	if not cooldown_bar:
		# 动态创建冷却条
		cooldown_bar = ProgressBar.new()
		cooldown_bar.name = "SkillCooldownBar"
		cooldown_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cooldown_bar.value = 0.0
		cooldown_bar.add_theme_color_override("fill_color", Color(0.3, 0.5, 1, 1))
		hbox.add_child(cooldown_bar)
	# 创建属性标签
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	hbox.add_child(stats_label)

func _connect_player() -> void:
	# 通过 group 或场景树查找 Player
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		var root = get_tree().current_scene
		player = root.get_node_or_null("Player") as Player if root else null

	if player:
		player.health_changed.connect(_on_health_changed)
		player.died.connect(_on_player_died)
		player.skill_manager.cooldown_changed.connect(_on_skill_cooldown)
		cooldown_bar.max_value = player.skill_manager.get_cooldown_total(0)
		cooldown_bar.value = 0
		health_bar.max_value = player.health_component.max_hp
		health_bar.value = player.health_component.hp
		health_label.text = "%d / %d" % [player.health_component.hp, player.health_component.max_hp]
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

func _on_player_died() -> void:
	print("💀 HUD: 玩家死亡！")
	if death_screen:
		death_screen.visible = true

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_skill_cooldown(_skill_index: int, remaining: float, total: float) -> void:
	cooldown_bar.max_value = total
	cooldown_bar.value = remaining


func _on_stat_changed(_stat_name: String, _new_value: int) -> void:
	_update_stats_display()


func _on_level_up(new_level: int) -> void:
	print("🎉 升级！Lv.%d" % new_level)
	_update_stats_display()
	if level_up_ui:
		level_up_ui._on_level_up(new_level)


func _setup_level_up_ui() -> void:
	# 实例化升级面板
	var lui_scene := load("res://ui/level_up_ui.tscn") as PackedScene
	if not lui_scene:
		print("⚠️ HUD: 无法加载 level_up_ui.tscn")
		return
	level_up_ui = lui_scene.instantiate() as LevelUpUI
	level_up_ui.name = "LevelUpUI"
	get_tree().current_scene.add_child(level_up_ui)
	level_up_ui.setup(player.stats_component)
	# 分配确认后刷新 HUD
	level_up_ui.allocation_confirmed.connect(_update_stats_display)


func _update_stats_display() -> void:
	if not player or not stats_label:
		return
	var s = player.stats_component
	stats_label.text = "Lv.%d  💪%d 🧠%d 🏃%d 🛡️%d  XP:%d/%d" % [
		s.level, s.strength, s.intelligence, s.agility, s.endurance,
		s.experience, s.exp_to_next
	]
