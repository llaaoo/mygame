class_name InputBindings
extends RefCounted
const PATH := "user://actor_bindings.cfg"
const KEYS := {"guard":KEY_V,"sprint":KEY_ALT,"drop_pack":KEY_B}
static var loaded := false
static func install() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event:=InputEventKey.new()
			event.physical_keycode=KEYS[action]
			InputMap.action_add_event(action,event)
	if not InputMap.has_action("heavy_attack"):
		InputMap.add_action("heavy_attack")
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.ctrl_pressed=true
		InputMap.action_add_event("heavy_attack",event)
	if loaded: return
	loaded=true
	var config:=ConfigFile.new()
	if config.load(PATH)!=OK: return
	for action in config.get_section_keys("bindings") if config.has_section("bindings") else PackedStringArray():
		if not InputMap.has_action(action): continue
		var raw: Variant=config.get_value("bindings",action)
		if not raw is Dictionary: continue
		var event:=decode(raw)
		if event: assign(action,event,false)
static func assign(action: String,event: InputEvent,save := true) -> OperationResult:
	if not InputMap.has_action(action) or not event is InputEventKey and not event is InputEventMouseButton: return OperationResult.reject("invalid_binding")
	for other in InputMap.get_actions():
		if other==action: continue
		for binding in InputMap.action_get_events(other):
			if event.is_match(binding,true): return OperationResult.reject("binding_in_use")
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action,event)
	if save:
		var config:=ConfigFile.new()
		config.load(PATH)
		config.set_value("bindings",action,encode(event))
		if config.save(PATH)!=OK: return OperationResult.reject("save_failed")
	return OperationResult.success()
static func encode(event: InputEvent) -> Dictionary:
	return {"key":(event.physical_keycode if event.physical_keycode else event.keycode) if event is InputEventKey else 0,"mouse":event.button_index if event is InputEventMouseButton else 0,"ctrl":event.ctrl_pressed,"alt":event.alt_pressed,"shift":event.shift_pressed}
static func decode(raw: Dictionary) -> InputEvent:
	var event: InputEventWithModifiers
	if int(raw.get("key",0))>0:
		var key:=InputEventKey.new(); key.physical_keycode=int(raw.key); event=key
	elif int(raw.get("mouse",0))>0:
		var mouse:=InputEventMouseButton.new(); mouse.button_index=int(raw.mouse); event=mouse
	else: return null
	event.ctrl_pressed=bool(raw.get("ctrl",false)); event.alt_pressed=bool(raw.get("alt",false)); event.shift_pressed=bool(raw.get("shift",false))
	return event
