class_name FoundationWidgets
extends RefCounted
static func label(text: String, size := 14, muted := false) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_label(node,size,GameUIStyle.TEXT_MUTED if muted else GameUIStyle.TEXT_MAIN)
	return node
static func button(text: String, action: Callable, disabled := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 38
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.disabled = disabled
	node.tooltip_text = text
	GameUIStyle.apply_button(node)
	if action.is_valid(): node.pressed.connect(action)
	return node
static func card(host: Node, title: String, subtitle := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.36))
	host.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	# Long service/waypoint captions must not widen the entire reading column.
	# The complete target remains available in the button tooltip and card text.
	box.child_entered_tree.connect(func(child: Node):
		if child is Button: child.clip_text=true)
	box.add_child(label(title,20))
	if not subtitle.is_empty(): box.add_child(label(subtitle,13,true))
	return box
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
static func comparison(current: EquipmentData, candidate: EquipmentData) -> String:
	var text: String="对比 "+(current.display_name if current else "空槽")+"\n"
	for row in EquipmentStatView.rows(current,candidate):
		text+="%s   %s → %s"%[row.title,EquipmentStatView.number(row.key,row.before),EquipmentStatView.number(row.key,row.after)]
		if not is_zero_approx(row.delta): text+="（%s · %s）"%[EquipmentStatView.number(row.key,row.delta,true),"收益" if row.benefit else "代价"]
		text+="\n"
	return text

static func disclosure(host: Node,title: String,text: String) -> void:
	var button_node:=Button.new(); button_node.text="＋ "+title
	button_node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	GameUIStyle.apply_button(button_node)
	host.add_child(button_node)
	var body:=label(text,14,true); body.visible=false; host.add_child(body)
	button_node.pressed.connect(func(): body.visible=not body.visible; button_node.text=("− " if body.visible else "＋ ")+title)
