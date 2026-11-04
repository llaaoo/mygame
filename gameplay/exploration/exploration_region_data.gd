class_name ExplorationRegionData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var room_type: String = "barracks"
@export var seed: int = 1
@export var encounters: Array[Dictionary] = []
@export var discoveries: Array[Dictionary] = []
@export var events: Array[Dictionary] = []
@export var spell_objects: Array[Dictionary] = []
@export var exits: Array[Dictionary] = []

func reserve_interaction_space(layout: RefCounted) -> void:
	# Authored points take precedence over the reusable random obstacle pattern.
	for obstacle in layout.obstacles.duplicate():
		var rect := Rect2(obstacle.position - obstacle.size * 0.5, obstacle.size).grow(48)
		for entry in discoveries + events + exits + spell_objects:
			if rect.has_point(entry.pos):
				layout.obstacles.erase(obstacle)
				break
