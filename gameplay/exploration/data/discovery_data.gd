class_name ExplorationDiscoveryData
extends Resource

@export var id: String
@export var title: String
@export var text: String
@export_multiline var intro_text: String = "" # First reading; full text is always kept in J.
@export var pos: Vector2 = Vector2.ZERO
@export var actions: Array[String] = []
@export var spell_rules: Array[String] = []
@export var equipment: Array[String] = []
@export var materials: Dictionary = {}
@export var heal: bool = false
@export var hide_when_claimed: bool = false
@export var requires_clear: bool = false
@export var kind: String = "note"

@export var element_clues: Array[String] = []
