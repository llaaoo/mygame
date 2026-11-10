class_name EncounterTactics
extends Resource
## Immutable territory/role rules. Observations and targets belong to each live enemy.
enum Role { HUNTER, SENTRY, BULWARK, SKIRMISHER }
@export var role: Role=Role.SENTRY
@export var warning_radius := 240.0
@export var defend_radius := 95.0
@export var warning_seconds := 2.5
@export var alarm_radius := 360.0
@export var search_seconds := 6.0
@export_multiline var observation := ""
func valid() -> bool:
	if role not in Role.values() or observation.is_empty():return false
	for value in [warning_radius,defend_radius,warning_seconds,alarm_radius,search_seconds]:
		if not is_finite(value) or value<=0:return false
	return defend_radius<warning_radius and warning_radius<=600 and warning_seconds>=.5 and warning_seconds<=10 and alarm_radius<=600 and search_seconds<=30
