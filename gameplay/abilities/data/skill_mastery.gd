class_name SkillMastery
extends Resource

enum School {
	DESTRUCTION,
	CONJURATION,
	RESTORATION,
	ALTERATION,
	ILLUSION,
}

@export var skill_id: String = ""
@export var school: School = School.DESTRUCTION
@export var level: int = 1
@export var xp: float = 0.0
@export var xp_to_next: float = 15.0
@export var perk_points: int = 0


func add_xp(amount: float) -> bool:
	xp += amount
	if xp >= xp_to_next and level < 100:
		return _level_up()
	return false


func _level_up() -> bool:
	xp -= xp_to_next
	level += 1
	xp_to_next = _calc_xp_for_level(level)
	if level % 5 == 0:
		perk_points += 1
	if xp >= xp_to_next and level < 100:
		_level_up()
	return true


static func _calc_xp_for_level(lvl: int) -> float:
	return lvl * lvl * 0.8 + lvl * 3.0 + 10.0


func get_progress() -> float:
	return xp / xp_to_next


func get_school_name() -> String:
	return School.keys()[school]
