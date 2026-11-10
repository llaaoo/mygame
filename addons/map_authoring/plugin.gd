@tool
extends EditorPlugin
## Keep gameplay validators in a runtime subprocess, not editor placeholder instances.
var _dock: VBoxContainer
var _status: Label
var _arrivals: OptionButton
var _results: ItemList
var _buttons: Array[Button]=[]
var _pid := -1
var _deadline := 0
var _output := ""
var _log_path := ""
var _pending_scene := ""
var _pending_arrival := ""
var _pending_preview := false
var _scene_modified := 0
func _enter_tree() -> void:
	_dock=VBoxContainer.new();_dock.name="地图制作"
	var description:=Label.new();description.text="场景节点摆放 · 命名落点 · 原生碰撞与导航\n点击检查结果可定位到对应场景节点。";description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_dock.add_child(description)
	_arrivals=OptionButton.new();_dock.add_child(_arrivals)
	_button("保存并检查当前地图",func():_check(true,false))
	_button("检查灰河谷地图目录",func():_check(false,false))
	_button("保存并试玩当前地图",func():_check(true,true))
	_status=Label.new();_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_dock.add_child(_status)
	_results=ItemList.new();_results.custom_minimum_size=Vector2(260,260);_results.size_flags_vertical=Control.SIZE_EXPAND_FILL;_results.item_selected.connect(_select_error);_dock.add_child(_results)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL,_dock)
	scene_changed.connect(_scene_changed)
	_scene_changed(EditorInterface.get_edited_scene_root())
func _button(title: String,callback: Callable) -> void:
	var button:=Button.new();button.text=title;button.pressed.connect(callback);_dock.add_child(button);_buttons.append(button)
func _scene_changed(root: Node) -> void:
	_arrivals.clear();_arrivals.add_item("默认入口");_arrivals.set_item_metadata(0,"")
	if root is AuthoredMapCell:
		for child in root.find_children("*","",true,false):
			if child is MapArrival:
				_arrivals.add_item(child.id);_arrivals.set_item_metadata(_arrivals.item_count-1,child.id)
	_status.text="当前地图："+root.scene_file_path if root is AuthoredMapCell else "打开AuthoredMapCell场景开始制作。"
func _check(current: bool,preview: bool) -> void:
	if _pid>=0: return
	_pending_scene="";_pending_preview=preview
	if current:
		var root:=EditorInterface.get_edited_scene_root()
		if not root is AuthoredMapCell or root.scene_file_path.is_empty(): _status.text="先将AuthoredMapCell保存为场景并登记目录。";return
		if EditorInterface.save_scene()!=OK: _status.text="场景保存失败。";return
		_pending_scene=root.scene_file_path
		_scene_modified=FileAccess.get_modified_time(_pending_scene)
	_pending_arrival=str(_arrivals.get_selected_metadata())
	_output="res://.godot/map_authoring_report_%d.json"%Time.get_ticks_usec()
	_log_path=_output.get_basename()+".log"
	var args:=PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path(_log_path),"--script","res://tools/validate_maps.gd","--","--report="+_output])
	if current: args.append("--scene="+_pending_scene)
	_pid=OS.create_process(OS.get_executable_path(),args,false)
	if _pid<0: _status.text="无法启动地图检查进程。";return
	_deadline=Time.get_ticks_msec()+60000
	_results.clear();_status.text="正在检查地图、连接、实物ID与可达性……"
	for button in _buttons: button.disabled=true
func _process(_delta: float) -> void:
	if _pid<0: return
	if Time.get_ticks_msec()>_deadline:
		if OS.is_process_running(_pid): OS.kill(_pid)
		_finish({"errors":["地图检查超时；查看编辑器输出中的脚本诊断。"]})
	elif not OS.is_process_running(_pid) and FileAccess.file_exists(_output):
		var code:=OS.get_process_exit_code(_pid)
		var report: Variant=JSON.parse_string(FileAccess.get_file_as_string(_output))
		DirAccess.remove_absolute(_output)
		if report is Dictionary:
			if code not in [0,1] or code==1 and report.errors.is_empty(): report.errors.append("地图检查进程异常退出（%d），请查看输出。"%code)
			if report.errors.is_empty() and FileAccess.file_exists(_log_path):
				for line in FileAccess.get_file_as_string(_log_path).split("\n"):
					if line.begins_with("SCRIPT ERROR:") or line.begins_with("ERROR:") or line.begins_with("WARNING:"): report.errors.append(line)
			_finish(report)
		else: _finish({"errors":["地图检查返回了无效结果。"]})
	elif not OS.is_process_running(_pid):
		_finish({"errors":["地图检查未完成；查看编辑器输出中的脚本诊断。"]})
func _finish(report: Dictionary) -> void:
	_pid=-1
	for button in _buttons: button.disabled=false
	for error in report.errors:
		_results.add_item(str(error));_results.set_item_tooltip(_results.item_count-1,str(error))
	if not report.errors.is_empty(): _status.text="发现%d项问题。"%report.errors.size();return
	_status.text="通过：%d张地图，%d条通路，%d个命名落点。"%[report.cells,report.passages,report.arrivals]
	if _pending_preview:
		if FileAccess.get_modified_time(_pending_scene)!=_scene_modified: _status.text="场景已变化，请重新检查后试玩。";return
		var request:=ConfigFile.new();request.set_value("preview","scene",_pending_scene);request.set_value("preview","arrival",_pending_arrival)
		if request.save("res://.godot/map_authoring_preview.cfg")!=OK: _status.text="无法写入本地试玩请求。";return
		EditorInterface.play_custom_scene("res://demos/map_preview.tscn")
func _select_error(index: int) -> void:
	var message:=_results.get_item_text(index)
	var split:=message.find("::");var begin:=message.rfind("res://",split)
	var finish:=message.find(": ",split+2)
	if split<0 or begin<0 or finish<0: return
	var path:=message.substr(begin,split-begin)
	var node_path:=NodePath(message.substr(split+2,finish-split-2))
	EditorInterface.open_scene_from_path(path)
	await get_tree().process_frame
	var root:=EditorInterface.get_edited_scene_root()
	if root and root.scene_file_path==path:
		var node:=root.get_node_or_null(node_path)
		if node:
			var selection:=EditorInterface.get_selection();selection.clear();selection.add_node(node)
func _exit_tree() -> void:
	if _pid>=0 and OS.is_process_running(_pid): OS.kill(_pid)
	if scene_changed.is_connected(_scene_changed): scene_changed.disconnect(_scene_changed)
	remove_control_from_docks(_dock);_dock.free()
