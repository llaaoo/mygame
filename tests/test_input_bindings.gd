extends SceneTree
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	# Preferences must load even before any Player has registered its extra slots.
	var config:=ConfigFile.new()
	config.set_value("bindings","skill_5",{"key":KEY_H})
	config.set_value("bindings","skill_6",{"key":KEY_Y})
	check(config.save(InputBindings.PATH)==OK,"Could not stage isolated binding preferences")
	InputBindings.install()
	for action in InputBindings.KEYS:
		check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),"Missing default input: "+action)
	for pair in [["skill_5",KEY_H],["skill_6",KEY_Y]]:
		var event:=InputEventKey.new(); event.keycode=pair[1]; event.physical_keycode=pair[1]; event.pressed=true
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
		check(Input.is_action_pressed(pair[0]),"First boot skipped saved input for "+pair[0])
		event=event.duplicate(); event.pressed=false; Input.parse_input_event(event)
		await process_frame
	var before:=InputMap.action_get_events("skill_5").size()
	InputBindings.install()
	check(InputMap.action_get_events("skill_5").size()==before,"Multiple scene entries duplicated input events")
	if failures.is_empty(): print("PASS input bindings: defaults precede preference restoration and extra slots work on first boot")
	quit(0 if failures.is_empty() else 1)
