class_name SaveAdapter
extends RefCounted
## Existing domain services keep their own state format and validation.
var _capture: Callable
var _restore: Callable
var _validate: Callable
var _defaults: Dictionary
var _unknown: Dictionary={}
func _init(capture: Callable,restore: Callable,validate: Callable) -> void:
	_capture=capture;_restore=restore;_validate=validate
	_defaults=_capture.call().duplicate(true)
func serialize_save_data() -> Dictionary:
	var result:=_unknown.duplicate(true);result.merge(_capture.call(),true)
	return result
func deserialize_save_data(data: Dictionary) -> void:
	_unknown=data.duplicate(true)
	for key in _defaults: _unknown.erase(key)
	_restore.call(_defaults.duplicate(true) if data.is_empty() else data)
func validate_save_data(data: Variant) -> bool:
	return data is Dictionary and bool(_validate.call(_defaults if data.is_empty() else data))
