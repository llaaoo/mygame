class_name ExplorationEnemyProfile
extends Resource
## AI role/appearance/timing. Character definitions own attributes when present;
## legacy encounters retain their HP, speed and melee parameters.
@export var id: String
@export var title: String
@export_enum("哨兵", "士兵", "重兵") var appearance_preset := 0
@export_enum("近战", "远程", "混合") var role := 0
@export var melee_damage := 9
@export var melee_cooldown := 1.0
@export var attack_range := 55.0
@export var ranged_preferred_range := 180.0

@export var melee_windup := 0.4
@export var melee_recovery := 0.25
@export var ranged_windup := 0.45
