class_name SummonStatusUI
extends PanelContainer

var _manager: SummonManager = null
var _list: VBoxContainer = null
var _count_label: Label = null
var _refresh_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	custom_minimum_size = Vector2(210, 0)
	add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.78, 5))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_count_label = Label.new()
	GameUIStyle.apply_label(_count_label, 11, GameUIStyle.GOLD)
	vbox.add_child(_count_label)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	vbox.add_child(_list)


func setup(player: Player) -> void:
	if not player:
		return
	_manager = player.summon_manager
	if not _manager:
		return
	if not _manager.summons_changed.is_connected(_refresh):
		_manager.summons_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if not _manager:
		return
	_refresh_accum += delta
	if _refresh_accum >= 0.25:
		_refresh_accum = 0.0
		_refresh()


func _refresh() -> void:
	if not _manager or not _list:
		return
	for child in _list.get_children():
		child.queue_free()

	var summons := _manager.active_summons
	visible = not summons.is_empty()
	_count_label.text = "Summons %d/%d" % [summons.size(), SummonManager.MAX_SUMMONS]

	for summon in summons:
		if is_instance_valid(summon):
			_list.add_child(_make_row(summon))


func _make_row(summon: SummonEntity) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	row.add_child(top)

	var name := Label.new()
	name.text = summon.summon_name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(name, 10, GameUIStyle.TEXT_MAIN)
	top.add_child(name)

	var time := Label.new()
	time.text = "%.0fs" % maxf(float(summon.get("_lifetime")), 0.0)
	GameUIStyle.apply_label(time, 10, GameUIStyle.TEXT_MUTED)
	top.add_child(time)

	var health_component := summon.get_node_or_null("HealthComponent") as HealthComponent
	var hp_value := health_component.hp if health_component else 0
	var max_hp_value := health_component.max_hp if health_component else 1

	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 6)
	hp.show_percentage = false
	hp.max_value = max(1, max_hp_value)
	hp.value = hp_value
	hp.add_theme_stylebox_override("background", GameUIStyle.bar_bg())
	hp.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(Color(0.56, 0.68, 0.42, 1.0)))
	row.add_child(hp)

	return row
