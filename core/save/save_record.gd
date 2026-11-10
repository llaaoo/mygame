class_name SaveRecord
extends RefCounted
## Parameterless, side-effect-free data owners. Add optional fields in one place.
var _unknown_save_fields: Dictionary={}
func save_version() -> int: return 1
func save_dependencies() -> PackedStringArray: return []
func migrate_save_data(data: Dictionary,from_version: int) -> Variant:
	# Revision 0 is the unversioned legacy payload, already additive-compatible.
	return data.duplicate(true) if from_version==0 else null
func serialize_save_data() -> Dictionary:
	return SaveFields.capture(self,_unknown_save_fields)
func validate_save_data(value: Variant) -> bool:
	return SaveFields.valid(self,value)
func deserialize_save_data(data: Dictionary) -> void:
	if SaveFields.valid(self,data): _unknown_save_fields=SaveFields.restore(self,data)
