class_name WeaponArtState
extends RefCounted
## Per-actor physical input history. Ordinary combo indices remain in WeaponComboState.
var weapon_uid := ""
var clock := 0.0
var gap := 0.65
var _steps: Array[Dictionary]=[]
func begin(uid: String,kind: String,family: String,chain_gap: float,hold_grace := 0.0) -> void:
	if uid!=weapon_uid or not _steps.is_empty() and (not _steps.back().completed or clock-float(_steps.back().completed_at)>gap+hold_grace): reset()
	weapon_uid=uid; gap=chain_gap
	_steps.append({"kind":kind,"family":family,"released":false,"hit":false,"completed":false,"completed_at":0.0})
	while _steps.size()>MartialRoute.MAX_STEPS: _steps.pop_front()
func can_continue(recovering := false) -> bool:
	return not _steps.is_empty() and (not _steps.back().completed and recovering or _steps.back().completed and clock-float(_steps.back().completed_at)<=gap)
func released(family: String) -> void:
	if not _steps.is_empty() and _steps.back().family==family: _steps.back().released=true
func confirm_contact(family: String) -> void:
	for step in _steps:
		if step.family==family:
			step.hit=true
			return
func confirmed(family: String) -> bool:
	return not _steps.is_empty() and _steps.back().family==family and _steps.back().hit
func complete(overrun: float) -> void:
	if _steps.is_empty() or not _steps.back().released or _steps.back().completed: return
	_steps.back().completed=true; _steps.back().completed_at=clock-maxf(0,overrun)
func advance(delta: float,uid: String) -> void:
	clock+=delta
	if uid!=weapon_uid: reset()
func reset() -> void:
	weapon_uid=""; _steps.clear()
func match_route(route: MartialRoute,recovering := false,hold_grace := 0.0) -> Dictionary:
	if _steps.size()<route.sequence.size(): return {}
	var first:=_steps.size()-route.sequence.size()
	var families:=PackedStringArray()
	for index in range(route.sequence.size()):
		var step:=_steps[first+index]
		if step.kind!=route.sequence[index] or not step.released: return {}
		if not step.completed and (index!=route.sequence.size()-1 or not recovering): return {}
		if route.hit_rule==MartialRoute.HitRule.ALL and not step.hit: return {}
		families.append(step.family)
	var last: Dictionary=_steps.back()
	if route.hit_rule==MartialRoute.HitRule.LAST and not last.hit: return {}
	var remaining:=maxf(0,route.window+hold_grace-(clock-float(last.completed_at))) if last.completed else route.window
	if remaining<=.000001: return {}
	return {"token":"/".join(families),"remaining":remaining,"recovering":not last.completed}
