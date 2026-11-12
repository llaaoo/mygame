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
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(status,12,GameUIStyle.TEXT_MUTED)
	rows.child_entered_tree.connect(_style_entry)
	tabs.child_entered_tree.connect(_style_entry)
	for node in rows.get_children()+tabs.get_children(): _style_entry(node)
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
