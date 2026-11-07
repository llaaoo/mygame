class_name BindingEditor
extends VBoxContainer
var waiting := ""
var prompt: Label
var _buttons: Dictionary={}
var _titles: Dictionary={}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	prompt=FoundationWidgets.label("左键攻击、右键格挡固定保留。点击动作后按新键；Q/E/R与数字键绑定动作或物品，F交互；Esc取消，重复绑定会被拒绝。",12,true)
	add_child(prompt)
	for action in ["move_up","move_down","move_left","move_right","cast_left","cast_e","skill","sprint","heavy_attack","drop_pack","dodge","interact","field_method","loot_all","quick_item_1","quick_item_2","quick_item_3","quick_item_4","skill_1","skill_2","skill_3","skill_4","skill_5","skill_6"]:
		var title: String={"move_up":"向上移动","move_down":"向下移动","move_left":"向左移动","move_right":"向右移动","cast_left":"快捷槽 Q","cast_e":"快捷槽 E","skill":"快捷槽 R","sprint":"冲刺","heavy_attack":"重击","drop_pack":"放下背包","dodge":"闪避","interact":"交互","field_method":"作业方法","loot_all":"遗骸全部取走（仅面板）","quick_item_1":"快捷槽 7","quick_item_2":"快捷槽 8","quick_item_3":"快捷槽 9","quick_item_4":"快捷槽 0"}.get(action,action.replace("skill_","快捷槽 "))
		var events:=InputMap.action_get_events(action)
		var text:=InputBindings.labels(action) if not events.is_empty() else "未绑定"
		var button:=FoundationWidgets.button(title+"："+text,func(): waiting=action; prompt.text="请为「"+title+"」按下新键…")
		_buttons[action]=button; _titles[action]=title
		add_child(button)
	add_child(FoundationWidgets.button("恢复默认键位",_restore))
func _refresh() -> void:
	for action in _buttons: _buttons[action].text=_titles[action]+"："+InputBindings.labels(action)
func _restore() -> void:
	var result:=InputBindings.reset_defaults()
	_refresh()
	prompt.text="默认键位已恢复。" if result.accepted else "未能保存，键位保持不变。"
func _input(event: InputEvent) -> void:
	if waiting.is_empty() or not event.is_pressed() or not event is InputEventKey and not event is InputEventMouseButton: return
	if event is InputEventKey and event.keycode==KEY_ESCAPE: waiting=""; prompt.text="已取消改键。"
	else:
		var result:=InputBindings.assign(waiting,event)
		_refresh()
		prompt.text="绑定已保存。" if result.accepted else {"reserved_key":"左右键与菜单快捷键已保留，请选择其他按键。","binding_in_use":"此键已被其他动作使用。","save_failed":"未能保存，绑定保持不变。"}.get(result.reason,"无法使用此按键。")
		waiting=""
	get_viewport().set_input_as_handled()
