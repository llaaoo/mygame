class_name ExpeditionScreen
extends HBoxContainer
## The shell owns layout; presenters still own queries and domain requests.
var tabs: VBoxContainer:
	get: return $Navigation/Tabs
var tools: HBoxContainer:
	get: return $Content/Tools
var search: LineEdit:
	get: return $Content/Tools/Search
var status: Label:
	get: return $Content/Status
var rows: VBoxContainer:
	get: return $Content/Columns/List/Rows
var detail: VBoxContainer:
	get: return $Content/Columns/Details/Detail
var footer: VBoxContainer:
	get: return $Content/Footer

func _ready() -> void:
	resized.connect(_layout_columns)
	_layout_columns()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(status,12,GameUIStyle.TEXT_MUTED)
	rows.child_entered_tree.connect(_style_entry)
	tabs.child_entered_tree.connect(_style_entry)
	detail.child_entered_tree.connect(_style_detail_entry)
	footer.child_entered_tree.connect(func(_child: Node): _layout_footer.call_deferred())
	for node in rows.get_children()+tabs.get_children(): _style_entry(node)
	for node in detail.get_children(): _style_detail_entry(node)
func _layout_columns() -> void:
	$Navigation.custom_minimum_size.x=176 if size.x<1100 else 208
	$Content/Columns/List.size_flags_stretch_ratio=.36
	$Content/Columns/Details.size_flags_stretch_ratio=.64
	_layout_footer()
func _layout_footer() -> void:
	var actions_only:=not footer.get_children().is_empty() and footer.get_children().all(func(node): return node is Button)
	footer.size_flags_horizontal=Control.SIZE_SHRINK_END if actions_only else Control.SIZE_FILL
	footer.custom_minimum_size.x=minf(360,maxf(260,size.x*.3)) if actions_only else 0
func _style_detail_entry(node: Node) -> void:
	if node is SpinBox:
		node.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		node.custom_minimum_size.x=160
	elif node is Button:
		node.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		node.custom_minimum_size.x=280
		node.clip_text=true
func _style_entry(node: Node) -> void:
	if not node is Button: return
	node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	node.custom_minimum_size.y=maxf(node.custom_minimum_size.y,62 if "\n" in node.text else 44)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style:=node.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if not style: continue
		style.border_width_top=0; style.border_width_right=0
		style.content_margin_left=10; style.content_margin_right=10
		node.add_theme_stylebox_override(state,style)
