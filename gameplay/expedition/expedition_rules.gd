class_name ExpeditionRules
extends Resource
@export var base_point:=Vector2(-3700,2100)
@export var hours_per_thousand := .5
@export var minimum_hours := .5
@export var maximum_hours := 6.0
@export var rescue_hours := 2.0
@export var lose_pack_on_defeat := true
func quote(distance: float,interior := false) -> Dictionary:
	var hours:=clampf(ceil((distance*hours_per_thousand/1000.0+(1.0 if interior else 0.0))*2)/2,minimum_hours,maximum_hours)
	return {"hours":hours,"portions":maxi(1,ceili(hours/3.0))}
func valid() -> bool:
	return base_point.is_finite() and is_finite(hours_per_thousand) and hours_per_thousand>0 and is_finite(minimum_hours) and minimum_hours>0 and is_finite(maximum_hours) and maximum_hours>=minimum_hours and maximum_hours<=12 and is_finite(rescue_hours) and rescue_hours>0 and rescue_hours<=12
