class_name MartialRoute
extends Resource
## A short, authored physical sequence; never stores actor progress.
enum Form { BASE, FOLLOWUP }
enum HitRule { NONE, LAST, ALL }
const MAX_STEPS := 4
@export var id := ""
@export var sequence: Array[String]=[]
@export var form: Form=Form.BASE
@export var hit_rule: HitRule=HitRule.NONE
@export_range(.1,3,.05) var window := 1.1
@export var priority := 0
func valid() -> bool:
	if id.is_empty() or sequence.is_empty() or sequence.size()>MAX_STEPS or not is_finite(window) or window<=0 or window>3: return false
	if form not in [Form.BASE,Form.FOLLOWUP] or hit_rule not in [HitRule.NONE,HitRule.LAST,HitRule.ALL]: return false
	for step in sequence:
		if step not in ["light","heavy"]: return false
	return true
func describe() -> String:
	var steps:=PackedStringArray()
	for step in sequence: steps.append("轻击" if step=="light" else "重击")
	return " → ".join(steps)+( " · 末击有效命中" if hit_rule==HitRule.LAST else " · 每击有效命中" if hit_rule==HitRule.ALL else " · 实际挥出")
