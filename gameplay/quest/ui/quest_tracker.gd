class_name QuestTracker
extends CanvasLayer

var _panel: PanelContainer
var _title_label: Label
var _progress_label: Label
var _quest_manager: QuestManager = null


func _ready() -> void:
	layer = 110


func setup(mgr: QuestManager) -> void:
	_quest_manager = mgr
	_quest_manager.quest_started.connect(_on_quest_started)
	_quest_manager.quest_completed.connect(_on_quest_completed)
	_quest_manager.quest_progress.connect(_on_progress)
	_build_ui()
	hide()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_top = 120
	root.add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Quest"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_progress_label)


func _on_quest_started(quest_id: String) -> void:
	for q in _quest_manager.get_active_quests():
		if q.data.quest_id == quest_id:
			_title_label.text = q.data.title
			_update_progress(q)
			show()
			return


func _on_quest_completed(_quest_id: String) -> void:
	if _quest_manager.get_active_quests().is_empty():
		_title_label.text = "Quest completed"
		_progress_label.text = ""
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(hide)


func _on_progress(quest_id: String, _stage: int, _progress: Array) -> void:
	for q in _quest_manager.get_active_quests():
		if q.data.quest_id == quest_id:
			_update_progress(q)
			return


func _update_progress(q: QuestRuntime) -> void:
	if q.data.stages.is_empty():
		_progress_label.text = ""
		return
	var stage := q.data.stages[q.current_stage]
	var total := q.data.stages.size()
	var stage_name: String = stage.title if not stage.title.is_empty() else "Stage %d/%d" % [q.current_stage + 1, total]
	var stage_label := "%s  " % stage_name

	if stage.objectives.is_empty():
		_progress_label.text = stage_label
		return

	var parts: Array[String] = []
	var progress := q.get_progress()
	for i in range(stage.objectives.size()):
		var obj := stage.objectives[i]
		var cur := progress[i] if i < progress.size() else 0
		var label: String = obj.description if not obj.description.is_empty() else "Objective"
		parts.append("%s %d/%d" % [label, cur, obj.required_count])
	_progress_label.text = stage_label + ", ".join(parts)
