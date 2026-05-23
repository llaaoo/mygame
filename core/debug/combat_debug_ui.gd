class_name CombatDebugUI
extends Control
## 战斗调试UI — 显示最近一次战斗追踪
## 
## 添加到场景中，按 ~ 键切换显示

@export var toggle_key: Key = KEY_QUOTELEFT          ## ~ 键

var _panel: PanelContainer
var _label: RichTextLabel
var _visible := false


func _ready() -> void:
	_setup_ui()
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == toggle_key:
		_visible = not _visible
		visible = _visible
		if _visible:
			_refresh()


func _setup_ui() -> void:
	anchor_right = 0.35
	anchor_bottom = 0.7
	offset_left = 10
	offset_top = 10

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "⚔️ Combat Debugger"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	vbox.add_child(title)

	# 内容
	_label = RichTextLabel.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_following = true
	vbox.add_child(_label)

	# 按钮栏
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var refresh_btn := Button.new()
	refresh_btn.text = "🔄 Refresh"
	refresh_btn.pressed.connect(_refresh)
	hbox.add_child(refresh_btn)

	var clear_btn := Button.new()
	clear_btn.text = "🗑️ Clear"
	clear_btn.pressed.connect(_on_clear)
	hbox.add_child(clear_btn)

	var toggle_trace_btn := Button.new()
	toggle_trace_btn.text = "⏯️ Toggle Trace"
	toggle_trace_btn.pressed.connect(_on_toggle_trace)
	hbox.add_child(toggle_trace_btn)


func _refresh() -> void:
	var trace := CombatDebugger.get_last()
	if not trace:
		_label.text = "[color=gray](no traces recorded)[/color]"
		return

	var bbcode := ""
	bbcode += "[b]%s[/b] | Events: %d | Damage: [color=yellow]%d[/color]\n\n" % [
		trace.skill_name, trace.events.size(), trace.final_damage
	]

	var i := 1
	for ev in trace.events:
		var color := _color_for_category(ev.category)
		var prefix := "[color=%s]%2d.[/color]" % [color, i]

		match ev.category:
			CombatTraceEvent.Category.FIREWALL_BLOCK:
				bbcode += "%s [color=red]🚫 BLOCKED[/color] %s\n" % [prefix, ev.event_name]
			CombatTraceEvent.Category.MODIFIER_APPLY:
				var delta: int = ev.metadata.get("delta", 0)
				var sign := "+" if delta >= 0 else ""
				bbcode += "%s [color=cyan]📊 %s[/color]: %d → %d ([color=%s]%s%d[/color])\n" % [
					prefix, ev.event_name,
					ev.input_data.get("damage", 0),
					ev.output_data.get("damage", 0),
					"lime" if delta >= 0 else "red", sign, delta
				]
			CombatTraceEvent.Category.CONDITION_CHECK:
				var r: bool = ev.output_data.get("result", false)
				bbcode += "%s [color=orange]🔍 %s[/color]: [color=%s]%s[/color]\n" % [
					prefix, ev.event_name,
					"lime" if r else "gray", "PASS" if r else "FAIL"
				]
			CombatTraceEvent.Category.EVENT_EMIT:
				bbcode += "%s [color=magenta]📡 %s[/color] → %s\n" % [prefix, ev.event_name, ev.target]
			CombatTraceEvent.Category.DAMAGE_RESOLVE:
				bbcode += "%s [color=yellow]💥 %s[/color] base=%d\n" % [
					prefix, ev.event_name, ev.input_data.get("base_damage", 0)
				]
			_:
				bbcode += "%s %s\n" % [prefix, ev.event_name]
		i += 1

	# 伤害链总结
	bbcode += "\n[color=gray]Chain: %s[/color]" % trace.get_damage_chain()

	_label.text = bbcode


func _color_for_category(cat: CombatTraceEvent.Category) -> String:
	match cat:
		CombatTraceEvent.Category.FIREWALL_BLOCK: return "red"
		CombatTraceEvent.Category.MODIFIER_APPLY: return "cyan"
		CombatTraceEvent.Category.CONDITION_CHECK: return "orange"
		CombatTraceEvent.Category.EVENT_EMIT: return "magenta"
		CombatTraceEvent.Category.DAMAGE_RESOLVE: return "yellow"
		_: return "white"


func _on_clear() -> void:
	CombatDebugger.clear()
	_label.text = "[color=gray](cleared)[/color]"


func _on_toggle_trace() -> void:
	CombatDebugger.enabled = not CombatDebugger.enabled
	print("📊 CombatDebugger enabled: ", CombatDebugger.enabled)
	_label.text = "[color=gray]Tracing: %s[/color]" % ("ON" if CombatDebugger.enabled else "OFF")
