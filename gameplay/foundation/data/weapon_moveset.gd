class_name WeaponMoveset
extends Resource
## Each stroke requires a new attack press. Definitions never hold combo state.
@export var weapon_type := ""
@export var chain_window := .65
@export var attacks: Array[AttackProfile]=[]

const TITLES := {"blade":"刀剑","spear":"长矛","staff":"战杖","bow":"弓"}
func describe() -> String:
	var text: String=TITLES.get(weapon_type,weapon_type)+" · 每段都需重新按攻击，收招后%.2f秒内衔接。"%chain_window
	for i in range(attacks.size()):
		var stroke:=attacks[i]
		text+="\n第%d段 · 起手%.2f / 恢复%.2f秒 · 距离%.0f · 扇面%.0f° · 体力%.0f · 冲击%.0f"%[i+1,stroke.windup,stroke.recovery,stroke.reach,stroke.angle_degrees,stroke.stamina_cost,stroke.impact]
	return text
