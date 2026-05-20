extends CanvasLayer
## HUD - 玩家血条 UI

@onready var health_bar: ProgressBar = $MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/HBoxContainer/HealthLabel

var player: Player = null

func _ready() -> void:
	# 延迟查找 Player（等场景完全加载后）
	await get_tree().process_frame
	_connect_player()

func _connect_player() -> void:
	# 通过 group 或场景树查找 Player
	player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		var root = get_tree().current_scene
		player = root.get_node_or_null("Player") as Player if root else null
	
	if player:
		player.health_changed.connect(_on_health_changed)
		player.died.connect(_on_player_died)
		health_bar.max_value = player.max_hp
		health_bar.value = player.hp
		health_label.text = "%d / %d" % [player.hp, player.max_hp]
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
	# TODO: 显示死亡画面 / 重新开始按钮
