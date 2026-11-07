class_name BindingEditor
extends VBoxContainer
var waiting := ""
var prompt: Label
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	prompt=FoundationWidgets.label("左键攻击、右键格挡固定保留。点击动作后按新键；Q/R与1—6施法，F交互；Esc取消，重复绑定会被拒绝。",12,true)
	add_child(prompt)
	for action in ["move_up","move_down","move_left","move_right","cast_left","skill","sprint","heavy_attack","drop_pack","dodge","interact","field_method","loot_all","skill_1","skill_2","skill_3","skill_4","skill_5","skill_6"]:
		var title: String={"move_up":"向上移动","move_down":"向下移动","move_left":"向左移动","move_right":"向右移动","cast_left":"独立施法 Q 槽","skill":"独立施法 R 槽","sprint":"冲刺","heavy_attack":"重击","drop_pack":"放下背包","dodge":"闪避","interact":"交互","field_method":"作业方法","loot_all":"遗骸全部取走"}.get(action,action.replace("skill_","基础动作 "))
		var events:=InputMap.action_get_events(action)
		var text:=InputBindings.label(action) if not events.is_empty() else "未绑定"
		add_child(FoundationWidgets.button(title+"："+text,func(): waiting=action; prompt.text="请为「"+title+"」按下新键…"))
func _input(event: InputEvent) -> void:
	if waiting.is_empty() or not event.is_pressed() or not event is InputEventKey and not event is InputEventMouseButton: return
	if event is InputEventKey and event.keycode==KEY_ESCAPE: waiting=""; prompt.text="已取消改键。"
	else:
		var result:=InputBindings.assign(waiting,event)
		prompt.text="绑定已保存，重新打开设置查看。" if result.accepted else {"reserved_mouse_action":"左右键保留给攻击与格挡，请选择其他按键。","binding_in_use":"此键已被其他动作使用。","save_failed":"本次绑定已生效，但未能保存。"}.get(result.reason,"无法使用此按键。")
		waiting=""
	get_viewport().set_input_as_handled()
