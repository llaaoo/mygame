class_name SpellPuzzleData
extends Resource

@export var id: String
@export var title: String
@export var pos: Vector2 = Vector2.ZERO
@export var routes: Array[SpellPuzzleRoute] = []
@export var hint: String
@export var materials: Dictionary = {}
@export var required_claims: PackedStringArray = []
@export var work_methods: Array[FieldWorkMethod] = []
@export var pickup_claim: String = ""
@export var pickup_title: String = ""
@export_multiline var completion_text: String = ""
