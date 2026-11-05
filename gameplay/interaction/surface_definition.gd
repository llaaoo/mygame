class_name SurfaceDefinition
extends Resource
@export var id: String
@export var title: String
@export var color := Color.TRANSPARENT
@export var status_paths: Array[String] = []
@export var cleanse_statuses: Array[String] = []
@export var refresh_statuses: Array[String] = []
@export var danger := 0.0
@export var danger_status: String
@export var expiry_state: String
@export var expiry_duration := 0.0
