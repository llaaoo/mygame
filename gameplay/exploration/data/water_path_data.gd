class_name WaterPathData
extends Resource
@export var title: String
## Runtime points are region-local. MapFeature authoring uses marker-local offsets;
## the scene compiler translates them before the existing runtime reads them.
@export var points := PackedVector2Array()
