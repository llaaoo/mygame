class_name AttackProfile
extends Resource
@export var ammo_id := ""
@export var projectile_speed := 0.0
@export var windup := 0.18
@export var active := 0.12
@export var recovery := 0.30
@export var reach := 56.0
@export var angle_degrees := 100.0
@export var stamina_cost := 12.0
@export var impact := 20.0
@export var damage_multiplier := 1.0
@export var movement_multiplier := 0.25
func heavy() -> AttackProfile:
	var value:=duplicate(true) as AttackProfile
	value.windup*=2.5
	value.recovery*=1.7
	value.stamina_cost*=2
	value.impact*=2
	value.damage_multiplier*=1.5
	return value

func valid() -> bool:
	for key in ["projectile_speed","windup","active","recovery","reach","angle_degrees","stamina_cost","impact","damage_multiplier","movement_multiplier"]:
		if not is_finite(float(get(key))) or float(get(key))<0: return false
	if not ammo_id.is_empty() and (projectile_speed<=0 or not ItemCatalog.default_catalog().definition(ammo_id)): return false
	if projectile_speed>0 and ammo_id.is_empty(): return false
	return active>0 and reach>0 and angle_degrees>0 and angle_degrees<=360 and movement_multiplier<=1
