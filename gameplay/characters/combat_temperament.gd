class_name CombatTemperament
extends Resource
## Immutable decision timing; each brain owns its observations and cooldowns.
@export var reaction_delay := .18
@export var defense_interval := 1.8
@export var guard_duration := .36
@export var attack_pause := .35
@export var retreat_fraction := .28
@export var preferred_reach := .85
func valid() -> bool:
	for key in ["reaction_delay","defense_interval","guard_duration","attack_pause","retreat_fraction","preferred_reach"]:
		if not is_finite(float(get(key))) or float(get(key))<0: return false
	return reaction_delay>=.1 and defense_interval>=1 and guard_duration>=.2 and guard_duration<=.8 and retreat_fraction>=.2 and retreat_fraction<=.6 and preferred_reach>=.6 and preferred_reach<=1
