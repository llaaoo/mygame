class_name FrontierControls
extends RefCounted
## Preferences are separate from campaign progress and never execute combinations.
const PATH := "user://frontier_controls.cfg"
static var quick_cast := true
static var _loaded := false
static func load_preferences() -> void:
	if _loaded: return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) == OK: quick_cast = bool(config.get_value("controls","quick_cast",true))
static func set_quick_cast(value: bool) -> bool:
	quick_cast = value
	var config := ConfigFile.new()
	config.set_value("controls","quick_cast",value)
	return config.save(PATH) == OK
