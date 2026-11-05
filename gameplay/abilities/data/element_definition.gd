class_name ElementDefinition
extends Resource
@export var id: String
## Empty for a base element; a non-empty parent identifies a form of that element.
@export var parent_id: String
@export var title: String
@export var color := Color.WHITE
@export_multiline var description: String
@export var hit_status_paths: Array[String] = []
