class_name InputBindings
extends RefCounted
## Gameplay defaults and user overrides have one owner. Menu-only bindings can
## overlap world bindings; UI ownership prevents them firing in both contexts.
const PATH := "user://actor_bindings.cfg"
const LAYOUT_VERSION := 6
const KEYS := {
	"move_left":KEY_A,"move_right":KEY_D,"move_up":KEY_W,"move_down":KEY_S,
	"dodge":KEY_SPACE,"interact":KEY_F,"loot_all":KEY_T,"field_method":KEY_C,
	"weapon_art":KEY_V,
	"skill_1":KEY_1,"skill_2":KEY_2,"skill_3":KEY_3,
	"skill_4":KEY_4,"skill_5":KEY_5,"skill_6":KEY_6,
	"cast_left":KEY_Q,"cast_e":KEY_E,"skill":KEY_R,"sprint":KEY_ALT,"drop_pack":KEY_B,
	"quick_item_1":KEY_7,"quick_item_2":KEY_8,"quick_item_3":KEY_9,"quick_item_4":KEY_0,
}
const MENU_KEYS := [KEY_TAB,KEY_ESCAPE,KEY_J,KEY_G,KEY_M,KEY_N,KEY_O,KEY_I,KEY_K,KEY_F5,KEY_F9]
static var loaded := false
static func _key(code: Key) -> InputEventKey:
	var event:=InputEventKey.new(); event.physical_keycode=code
	return event
static func defaults() -> Dictionary:
	var result: Dictionary={}
	for action in KEYS:
		result[action]=[_key(KEYS[action])]
	for action in ["attack","guard","heavy_attack","material_wheel"]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_MIDDLE if action=="material_wheel" else MOUSE_BUTTON_RIGHT if action=="guard" else MOUSE_BUTTON_LEFT
		event.ctrl_pressed=action=="heavy_attack"
		result[action]=[event]
	return result
static func context(action: String) -> String:
	return "loot" if action=="loot_all" else "world"
static func _allowed(action: String,event: InputEvent) -> bool:
	if action in ["attack","guard"]: return false
	if event is InputEventMouseButton:
		return event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] or action=="heavy_attack" and event.button_index==MOUSE_BUTTON_LEFT and event.ctrl_pressed
	return event is InputEventKey and event.physical_keycode not in MENU_KEYS and event.keycode not in MENU_KEYS
static func _same(first: InputEvent,second: InputEvent) -> bool:
	# Captured keys contain both logical and physical codes; defaults only need
	# physical codes. Compare the persisted identity so those cannot collide.
	return encode(first)==encode(second)
static func _apply(bindings: Dictionary) -> void:
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event in bindings[action]: InputMap.action_add_event(action,event)
static func install() -> void:
	if loaded: return
	loaded=true
	var bindings:=defaults()
	var config:=ConfigFile.new()
	var overrides: Dictionary={}
	if config.load(PATH)==OK and config.has_section("bindings"):
		var version:=int(config.get_value("layout","version",0))
		for action in config.get_section_keys("bindings"):
			if not bindings.has(action): continue
			var raw: Variant=config.get_value("bindings",action)
			if not raw is Dictionary: continue
			var event:=decode(raw)
			if not event or not _allowed(action,event): continue
			var code: int=event.physical_keycode if event is InputEventKey else 0
			if version<2 and action=="interact" and code==KEY_E: continue
			if version<3 and (action=="loot_all" and code==KEY_E or action=="skill_1" and code==KEY_1): continue
			if version==3 and action=="skill_1" and code==KEY_E: continue
			var duplicate:=false
			for other in overrides:
				if context(other)==context(action) and _same(event,overrides[other]): duplicate=true
			if not duplicate: overrides[action]=event
	# Validate the final mapping as a whole: valid key swaps must not depend on
	# the order of ConfigFile entries. Custom bindings beat newly added defaults.
	for action in bindings:
		if overrides.has(action): bindings[action]=[overrides[action]]; continue
		var remaining: Array=[]
		for event in bindings[action]:
			var occupied:=false
			for other in overrides:
				if context(other)==context(action) and _same(event,overrides[other]): occupied=true
			if not occupied: remaining.append(event)
		bindings[action]=remaining
	# A new core action must not steal an older customized shortcut.
	if bindings.weapon_art.is_empty():
		for code in [KEY_V,KEY_Z,KEY_X,KEY_H,KEY_Y,KEY_U,KEY_P,KEY_L]:
			var event:=_key(code); var occupied:=false
			for other in bindings:
				if context(other)!="world": continue
				for binding in bindings[other]:
					if _same(event,binding): occupied=true
			if not occupied: bindings.weapon_art=[event]; break
	_apply(bindings)
static func assign(action: String,event: InputEvent,save := true) -> OperationResult:
	var owned:=defaults()
	if not owned.has(action) or not event is InputEventKey and not event is InputEventMouseButton: return OperationResult.reject("invalid_binding")
	if not _allowed(action,event): return OperationResult.reject("reserved_key")
	event=decode(encode(event))
	for other in owned:
		if other==action or context(other)!=context(action): continue
		for binding in InputMap.action_get_events(other):
			if _same(event,binding): return OperationResult.reject("binding_in_use")
	if save:
		var config:=ConfigFile.new(); config.load(PATH)
		config.set_value("layout","version",LAYOUT_VERSION)
		config.set_value("bindings",action,encode(event))
		if not _save(config): return OperationResult.reject("save_failed")
	_apply({action:[event]})
	return OperationResult.success()
static func _save(config: ConfigFile) -> bool:
	var temporary:=PATH+".tmp"
	if config.save(temporary)!=OK: return false
	var result:=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(PATH))
	if result!=OK: DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return result==OK
static func reset_defaults() -> OperationResult:
	var config:=ConfigFile.new(); config.set_value("layout","version",LAYOUT_VERSION)
	if not _save(config): return OperationResult.reject("save_failed")
	_apply(defaults())
	return OperationResult.success()
static func encode(event: InputEvent) -> Dictionary:
	return {"key":(event.physical_keycode if event.physical_keycode else event.keycode) if event is InputEventKey else 0,"mouse":event.button_index if event is InputEventMouseButton else 0,"ctrl":event.ctrl_pressed,"alt":event.alt_pressed,"shift":event.shift_pressed}
static func decode(raw: Dictionary) -> InputEvent:
	var event: InputEventWithModifiers
	if int(raw.get("key",0))>0:
		var key:=_key(int(raw.key)); event=key
	elif int(raw.get("mouse",0))>0:
		var mouse:=InputEventMouseButton.new(); mouse.button_index=int(raw.mouse); event=mouse
	else: return null
	event.ctrl_pressed=bool(raw.get("ctrl",false)); event.alt_pressed=bool(raw.get("alt",false)); event.shift_pressed=bool(raw.get("shift",false))
	return event
static func labels(action: String) -> String:
	var result: Array[String]=[]
	for event in InputMap.action_get_events(action): result.append(event.as_text().replace(" (Physical)","").replace(" - Physical",""))
	return " / ".join(result) if not result.is_empty() else "—"
static func label(action: String) -> String:
	var bindings:=InputMap.action_get_events(action)
	return bindings[0].as_text().replace(" (Physical)","").replace(" - Physical","") if not bindings.is_empty() else "—"

static func action_for_source(source: String) -> String:
	if source=="left": return "cast_left"
	if source=="quick_e": return "cast_e"
	if source=="right": return "skill"
	if source.begins_with("item_"): return "quick_item_%d"%(int(source.trim_prefix("item_"))+1)
	return "skill_%d"%(int(source.trim_prefix("slot_"))+1)
