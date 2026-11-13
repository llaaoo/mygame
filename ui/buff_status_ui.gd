class_name BuffStatusUI
extends PanelContainer
var _buff_manager: BuffManager
var _list: GridContainer
var _rows: Dictionary={}
var _refresh_accum:=0.0
var _overflow: Label
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	visible=false
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_list=GridContainer.new(); _list.columns=3
	_list.add_theme_constant_override("h_separation",6)
	_list.add_theme_constant_override("v_separation",4)
	add_child(_list)
func setup(player: Player) -> void:
	if not player: return
	_buff_manager=player.get_node_or_null("BuffManager") as BuffManager
	if not _buff_manager: return
	if not _buff_manager.buffs_changed.is_connected(_refresh): _buff_manager.buffs_changed.connect(_refresh)
	_refresh()
func _process(delta: float) -> void:
	_refresh_accum+=delta
	if _refresh_accum>=.2: _refresh_accum=0; _refresh()
func _refresh() -> void:
	if not _list or not _buff_manager: return
	var entries:=_buff_manager.get_active_buff_entries().filter(func(entry): return entry.id!="equipment_loadout")
	visible=not entries.is_empty()
	entries.sort_custom(func(a,b):return a.category in StatusPresentation.HARMFUL if (a.category in StatusPresentation.HARMFUL)!=(b.category in StatusPresentation.HARMFUL) else a.remaining<b.remaining)
	tooltip_text="已生效\n"+"\n".join(entries.map(func(entry):return str(entry.name)+" · "+str(entry.description)))
	if not _overflow:
		_overflow=FoundationWidgets.label("",12,true); _list.add_child(_overflow)
	_overflow.text="+%d"%(entries.size()-6); _overflow.visible=entries.size()>6
	entries=entries.slice(0,6)
	var seen: Dictionary={}
	var index:=0
	for entry in entries:
		var id: int=entry.instance_id; seen[id]=true
		if not _rows.has(id):
			_rows[id]=_make_buff_row(entry); _list.add_child(_rows[id])
		var row: Control=_rows[id]
		_list.move_child(row,index); index+=1
		(row.get_meta("name_label") as Label).text=_format_name(entry)
		(row.get_meta("timer_bar") as ProgressBar).value=entry.progress
		(row.get_meta("time") as Label).text=("%ds"%ceili(float(entry.remaining))) if entry.remaining>0 else "∞"
		var stacks:=int(entry.get("stacks",1))
		(row.get_meta("stack") as Label).text=str(stacks) if int(entry.get("capacity",1))>1 else ""
		row.tooltip_text="已生效 · "+_format_name(entry)+"\n"+str(entry.description)
	for id in _rows.keys():
		if not seen.has(id): _rows[id].queue_free(); _rows.erase(id)
	_list.move_child(_overflow,_list.get_child_count()-1)
func _make_buff_row(entry: Dictionary) -> Control:
	var row:=VBoxContainer.new(); row.custom_minimum_size=Vector2(64,54)
	row.add_theme_constant_override("separation",1)
	var box:=Control.new(); box.custom_minimum_size=Vector2(34,26); row.add_child(box)
	var icon:=TextureRect.new(); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture=GameUIStyle.icon({"burning":"flame","poison":"flask-conical","frozen":"snowflake","wet":"droplet","electrified":"zap"}.get(str(entry.get("status_id","")),"shield"))
	icon.modulate=ElementVisuals.status_color(str(entry.get("status_id",""))); icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var stack:=Label.new(); stack.position=Vector2(22,-3); GameUIStyle.apply_label(stack,12,GameUIStyle.GOLD); box.add_child(stack)
	var time:=Label.new(); time.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(time,12,GameUIStyle.TEXT_MUTED); row.add_child(time)
	var bar:=ProgressBar.new(); bar.max_value=1; bar.show_percentage=false
	GameUIStyle.apply_progress(bar,icon.modulate,2); row.add_child(bar)
	var name:=Label.new(); name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; GameUIStyle.apply_label(name,12); row.add_child(name)
	row.set_meta("name_label",name); row.set_meta("timer_bar",bar); row.set_meta("time",time); row.set_meta("stack",stack)
	for child in row.find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return row
func _format_name(entry: Dictionary) -> String:
	var title:=StatusPresentation.title(str(entry.get("status_id","")),str(entry.get("name","状态")))
	if int(entry.get("capacity",1))>1: title+=" %d/%d"%[entry.get("stacks",1),entry.capacity]
	return title
