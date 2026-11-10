class_name TrainingCatalog
extends Resource
@export var actor_id := "river.enemy.service.trainer"
@export var work_position := Vector2(-3300,2350)
@export var rest_position := Vector2(-3960,2680)
@export var schedule: NPCSchedule
@export var offers: Array[LearningOffer]=[]
@export var fieldcraft_skills: PackedStringArray=[]
# Keep immutable definitions alive; ResourceLoader's cache does not own them.
static var _default: TrainingCatalog
static func default_catalog() -> TrainingCatalog:
	if not _default: _default=load("res://content/training/catalog.tres") as TrainingCatalog
	return _default

func offer(id: String) -> LearningOffer:
	for entry in offers:
		if entry and entry.id==id: return entry
	return null
func validate() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	if actor_id.is_empty() or not work_position.is_finite() or not rest_position.is_finite(): errors.append("Invalid trainer identity/locations")
	for id in fieldcraft_skills:
		if not FieldcraftCatalog.default_catalog().skill(id) or fieldcraft_skills.count(id)!=1: errors.append("Invalid/duplicate trainer fieldcraft lesson: "+id)
	for entry in offers:
		if not entry or not entry.valid() or seen.has(entry.id): errors.append("Invalid/duplicate learning offer"); continue
		seen[entry.id]=true
		if not MartialArts.definition(entry.technique.id) or MartialArts.definition(entry.technique.id)!=entry.technique: errors.append("Unregistered training technique: "+entry.id)
	return errors
