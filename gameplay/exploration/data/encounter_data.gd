class_name ExplorationEncounterData
extends Resource

@export var persistent_id := ""
@export var group := ""
@export var pos: Vector2 = Vector2.ZERO
@export var hp: int = 1
@export var role: int = 0
@export var detect_range := 440.0
@export var speed: float = 105.0
@export var boss: bool = false
@export var profile: ExplorationEnemyProfile

@export var character: ActorCharacterData

@export var optional_encounter := false
