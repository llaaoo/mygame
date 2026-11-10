class_name SaveValues
extends RefCounted
## Bounded value-only snapshots. Never instantiate saved Objects or execute code.
const MAX_DEPTH := 32
const MAX_VALUES := 1000000
static func valid(value: Variant) -> bool:
	return _check(value,0,[0])
static func _check(value: Variant,depth: int,budget: Array) -> bool:
	budget[0]+=1
	if depth>MAX_DEPTH or budget[0]>MAX_VALUES: return false
	match typeof(value):
		TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID,TYPE_NODE_PATH: return false
		TYPE_FLOAT: return is_finite(value)
		TYPE_STRING,TYPE_STRING_NAME: return str(value).length()<=4000000
		TYPE_ARRAY:
			if value.is_typed() and value.get_typed_builtin()==TYPE_OBJECT: return false
			for item in value:
				if not _check(item,depth+1,budget): return false
		TYPE_DICTIONARY:
			if value.is_typed() and (value.get_typed_key_builtin()==TYPE_OBJECT or value.get_typed_value_builtin()==TYPE_OBJECT): return false
			for key in value:
				if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT] or not _check(value[key],depth+1,budget): return false
		TYPE_VECTOR2,TYPE_VECTOR3,TYPE_VECTOR4,TYPE_QUATERNION,TYPE_BASIS,TYPE_TRANSFORM2D,TYPE_TRANSFORM3D: return value.is_finite()
		TYPE_RECT2,TYPE_AABB: return value.position.is_finite() and value.size.is_finite()
		TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
		TYPE_PROJECTION: return value.x.is_finite() and value.y.is_finite() and value.z.is_finite() and value.w.is_finite()
		TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_VECTOR4_ARRAY,TYPE_PACKED_COLOR_ARRAY,TYPE_PACKED_STRING_ARRAY:
			for item in value:
				if not _check(item,depth+1,budget): return false
	return true
static func copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value.duplicate() if typeof(value)>=TYPE_PACKED_BYTE_ARRAY else value
