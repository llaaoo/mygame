class_name RepairFacilityData
extends Resource
## One fixed repair objective; progress is stored by existing world claims.
@export var id: String
@export var start_claim: String
@export var title: String
@export var pos := Vector2.ZERO
@export_multiline var description: String
@export var required_claims: PackedStringArray = []
@export var assembly: FieldWorkMethod
