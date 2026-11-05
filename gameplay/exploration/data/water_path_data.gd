class_name WaterPathData
extends Resource
@export var title: String
## Points in region-local coordinates, sampled at cell centers.
@export var points := PackedVector2Array()
