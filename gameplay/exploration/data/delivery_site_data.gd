class_name DeliverySiteData
extends Resource
## A physical handover of inventory, paid only after interruptible work succeeds.
@export var id: String
@export var title: String
@export var pos := Vector2.ZERO
@export_multiline var description: String
@export var methods: Array[FieldWorkMethod] = []
@export var rewards: Dictionary = {}
@export var required_claims: PackedStringArray = []
