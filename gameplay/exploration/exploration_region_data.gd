class_name ExplorationRegionData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var room_type: String = "barracks"
@export var seed: int = 1
@export var encounters: Array[ExplorationEncounterData] = []
@export var discoveries: Array[ExplorationDiscoveryData] = []
@export var events: Array[ExplorationWorldEventData] = []
@export var spell_objects: Array[SpellPuzzleData] = []
@export var exits: Array[ExplorationExitData] = []

func reserve_interaction_space(layout: RefCounted) -> void:
	# Authored points take precedence over the reusable random obstacle pattern.
	for obstacle in layout.obstacles.duplicate():
		var rect := Rect2(obstacle.position - obstacle.size * 0.5, obstacle.size).grow(48)
		for entry in interaction_points():
			if rect.has_point(entry.pos):
				layout.obstacles.erase(obstacle)
				break

func interaction_points() -> Array[Resource]:
	var points: Array[Resource] = []
	points.append_array(discoveries)
	points.append_array(events)
	points.append_array(exits)
	points.append_array(spell_objects)
	return points
