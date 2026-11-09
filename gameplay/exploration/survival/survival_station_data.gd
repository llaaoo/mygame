class_name SurvivalStationData
extends Resource
@export var id: String
@export var presentation_profile: WorldAnimationProfile
@export var title: String
@export var pos := Vector2.ZERO
@export_enum("water", "cook", "forage") var kind := "water"
@export var clean := false
@export var cleaned_by_claim := ""
@export var lit := false
@export var heat_offset := Vector2(96, 0)
@export var harvest: Dictionary = {}
@export var regeneration_hours := 4.0

@export var required_claims: PackedStringArray = []
