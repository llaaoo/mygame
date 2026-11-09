class_name PresentationCatalog
extends Resource
@export var cues: Array[PresentationCue]=[]
static func defaults() -> PresentationCatalog: return load("res://content/presentation/cues.tres") as PresentationCatalog
func cue(id: StringName) -> PresentationCue:
	for definition in cues:
		if definition and definition.id==id: return definition
	return null
func validation_errors() -> PackedStringArray:
	var errors:=PackedStringArray()
	var seen: Dictionary={}
	for definition in cues:
		if not definition or not definition.valid(): errors.append("Invalid presentation cue"); continue
		if seen.has(definition.id): errors.append("Duplicate presentation cue: "+str(definition.id))
		for error in PresentationScene.validation_errors(definition.visual_scene): errors.append(str(definition.id)+": "+error)
		seen[definition.id]=true
	return errors

