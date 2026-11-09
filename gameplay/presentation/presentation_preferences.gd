class_name PresentationPreferences
extends RefCounted
## Cosmetic preferences never enter a journey snapshot or change simulation time.
const PATH := "user://presentation.cfg"
const DEFAULTS := {"reduced_motion":false,"camera_feedback":true,"effects_quality":1,"world_volume":0.65,"ui_volume":0.45}
static var _values: Dictionary=DEFAULTS.duplicate()
static var _loaded := false
static var revision := 0
static func load_preferences() -> void:
	if _loaded: return
	_loaded=true
	var config:=ConfigFile.new()
	if config.load(PATH)!=OK: return
	for key in DEFAULTS:
		var value: Variant=config.get_value("presentation",key,DEFAULTS[key])
		if valid(key,value): _values[key]=value
static func valid(key: String,value: Variant) -> bool:
	if key in ["reduced_motion","camera_feedback"]: return value is bool
	if key=="effects_quality": return value is int and value>=0 and value<=2
	if key in ["world_volume","ui_volume"]: return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and value>=0 and value<=1
	return false
static func value(key: String) -> Variant:
	load_preferences()
	return _values.get(key)
static func set_option(key: String,setting: Variant) -> bool:
	load_preferences()
	if not valid(key,setting): return false
	var previous: Variant=_values[key]
	_values[key]=setting
	var config:=ConfigFile.new()
	for id in DEFAULTS: config.set_value("presentation",id,_values[id])
	if config.save(PATH)!=OK: _values[key]=previous; return false
	revision+=1
	return true
static func motion_scale() -> float: return 0.0 if value("reduced_motion") else 1.0
static func effect_limit() -> int: return [12,24,48][int(value("effects_quality"))]

