class_name FieldcraftSkill
extends Resource
@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export var prerequisites: PackedStringArray=[]
@export var costs: Dictionary={"coin":6}
