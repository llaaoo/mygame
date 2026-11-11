class_name InputBindings
extends RefCounted
## Gameplay defaults and user overrides have one owner. Menu-only bindings can
## overlap world bindings; UI ownership prevents them firing in both contexts.
const PATH := "user://actor_bindings.cfg"
const LAYOUT_VERSION := 9
const KEYS := {
	"move_left":KEY_A,"move_right":KEY_D,"move_up":KEY_W,"move_down":KEY_S,
	"dodge":KEY_SPACE,"interact":KEY_F,"loot_all":KEY_T,"field_method":KEY_C,
	"skill_1":KEY_1,"skill_2":KEY_2,"skill_3":KEY_3,
	"skill_4":KEY_4,"skill_5":KEY_5,"skill_6":KEY_6,
	"cast_left":KEY_Q,"cast_e":KEY_E,"skill":KEY_R,"sprint":KEY_ALT,"drop_pack":KEY_B,
	"quick_item_1":KEY_7,"quick_item_2":KEY_8,"quick_item_3":KEY_9,"quick_item_4":KEY_0,
}
const MENU_ACTIONS := {"menu_actions":KEY_TAB,"menu_journal":KEY_J,"menu_materials":KEY_G,"menu_map":KEY_M,"menu_supplies":KEY_N,"menu_equipment":KEY_O,"menu_inventory":KEY_I,"menu_loadout":KEY_K,"menu_progression":KEY_P}
const MENU_KEYS := [KEY_ESCAPE,KEY_F5,KEY_F9,KEY_CTRL]
static var loaded := false
static var revision := 0
static func _key(code: Key) -> InputEventKey:
	var event:=InputEventKey.new(); event.physical_keycode=code
	return event
static func defaults() -> Dictionary:
	var result: Dictionary={}
	for action in KEYS:
		result[action]=[_key(KEYS[action])]
	for action in MENU_ACTIONS: result[action]=[_key(MENU_ACTIONS[action])]
	for action in ["attack","guard","material_wheel"]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_MIDDLE if action=="material_wheel" else MOUSE_BUTTON_RIGHT if action=="guard" else MOUSE_BUTTON_LEFT
		event.ctrl_pressed=false
		result[action]=[event]
	var art:=InputEventMouseButton.new(); art.button_index=MOUSE_BUTTON_LEFT; art.ctrl_pressed=true
	result["weapon_art"]=[art]
	result["heavy_attack"]=[] # Optional legacy keyboard binding; mouse heavy is a gesture.
	return result
static func context(action: String) -> String:
	return "loot" if action=="loot_all" else "world"
static func _conflicts(first: String,second: String) -> bool:
	return first in MENU_ACTIONS or second in MENU_ACTIONS or context(first)==context(second)
static func _overlaps(first: String,event: InputEvent,second: String,other: InputEvent) -> bool:
	if not _conflicts(first,second): return false
	# A global menu owns its physical key even with modifiers: closing it must
	# never leak an InputMap edge into a world action sharing the same key.
	if (first in MENU_ACTIONS or second in MENU_ACTIONS) and event is InputEventKey and other is InputEventKey:
		return encode(event).key==encode(other).key
	return _same(event,other)
static func _allowed(action: String,event: InputEvent) -> bool:
	if action in ["attack","guard"]: return false
	if action in MENU_ACTIONS and not event is InputEventKey: return false
	if action in MENU_ACTIONS and (event.physical_keycode in [KEY_ALT,KEY_SHIFT,KEY_META] or event.keycode in [KEY_ALT,KEY_SHIFT,KEY_META]): return false
	if action=="weapon_art": return event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed
	if event is InputEventMouseButton:
		return event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] or action=="weapon_art" and event.button_index==MOUSE_BUTTON_LEFT and event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed
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
	revision+=1
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
			if version<7 and action=="weapon_art" and code==KEY_V: continue
			if version<2 and action=="interact" and code==KEY_E: continue
			if version<3 and (action=="loot_all" and code==KEY_E or action=="skill_1" and code==KEY_1): continue
			if version==3 and action=="skill_1" and code==KEY_E: continue
			var duplicate:=false
			for other in overrides:
				if _overlaps(action,event,other,overrides[other]): duplicate=true
			if not duplicate: overrides[action]=event
	# Validate the final mapping as a whole: valid key swaps must not depend on
	# the order of ConfigFile entries. Custom bindings beat newly added defaults.
	for action in bindings:
		if overrides.has(action): bindings[action]=[overrides[action]]; continue
		var remaining: Array=[]
		for event in bindings[action]:
			var occupied:=false
			for other in overrides:
				if _overlaps(action,event,other,overrides[other]): occupied=true
			if not occupied: remaining.append(event)
		bindings[action]=remaining
	_apply(bindings)
static func assign(action: String,event: InputEvent,save := true) -> OperationResult:
	var owned:=defaults()
	if not owned.has(action) or not event is InputEventKey and not event is InputEventMouseButton: return OperationResult.reject("invalid_binding")
	if not _allowed(action,event): return OperationResult.reject("reserved_key")
	event=decode(encode(event))
	for other in owned:
		if other==action or not _conflicts(other,action): continue
		for binding in InputMap.action_get_events(other):
			if _overlaps(action,event,other,binding): return OperationResult.reject("binding_in_use")
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

## Canonical keys are only a compatibility projection for existing view routing.
## Real input always matches the authoritative InputMap, so the old key stops opening a menu.
static func menu_key(event: InputEvent) -> int:
	if not event is InputEventKey: return 0
	if event.keycode in MENU_KEYS: return event.keycode
	# Godot deliberately ignores required modifiers for key-release matching.
	# This query describes the binding, so normalize only the local lookup event.
	var lookup: InputEventKey=event
	if not event.pressed:
		lookup=event.duplicate() as InputEventKey
		lookup.pressed=true
	for action in MENU_ACTIONS:
		if lookup.is_action(action,true): return MENU_ACTIONS[action]
	for action in MENU_ACTIONS:
		if lookup.is_action(action): return MENU_ACTIONS[action]
	return 0
static func menu_action(key: int) -> String:
	for action in MENU_ACTIONS:
		if MENU_ACTIONS[action]==key: return action
	return ""
static func menu_label(key: int) -> String:
	var action:=menu_action(key)
	return label(action) if not action.is_empty() else OS.get_keycode_string(key)
## Only authored control instructions use this formatter. Slot/item labels keep
## their real identity and must never be passed through default-key substitution.
static func menu_help(text: String) -> String:
	var expression:=RegEx.create_from_string("(?<![A-Za-z0-9_])(Tab|[JGMNOIKP])(?=$|[^A-Za-z0-9_])")
	var matches:=expression.search_all(text)
	var result:=text
	for i in range(matches.size()-1,-1,-1):
		var found:=matches[i]
		for action in MENU_ACTIONS:
			if OS.get_keycode_string(MENU_ACTIONS[action])==found.get_string():
				result=result.left(found.get_start())+label(action)+result.substr(found.get_end())
				break
	return result

static func action_for_source(source: String) -> String:
	if source=="left": return "cast_left"
	if source=="quick_e": return "cast_e"
	if source=="right": return "skill"
	if source.begins_with("item_"): return "quick_item_%d"%(int(source.trim_prefix("item_"))+1)
	return "skill_%d"%(int(source.trim_prefix("slot_"))+1)
