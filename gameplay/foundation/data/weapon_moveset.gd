class_name WeaponMoveset
extends Resource
## Each stroke requires a new attack press. Definitions never hold combo state.
@export var weapon_type := ""
@export_multiline var description := ""
@export var chain_window := .65
@export var attacks: Array[AttackProfile]=[]

const TITLES := {"blade":"刀剑","spear":"长矛","staff":"战杖","bow":"弓","beast":"兽类"}
func valid() -> bool:
	if not TITLES.has(weapon_type) or not is_finite(chain_window) or chain_window<=0 or attacks.is_empty(): return false
	for stroke in attacks:
		if not stroke or not stroke.valid(): return false
		if (weapon_type=="bow")!=(stroke.projectile_speed>0): return false
	return true
func describe() -> String:
	var text: String=TITLES.get(weapon_type,weapon_type)+" · 每段都需重新按攻击，收招后%.2f秒内衔接。"%chain_window
	text+="\n"+description
	var names:=PackedStringArray()
	for i in range(attacks.size()): names.append(attacks[i].title if not attacks[i].title.is_empty() else "第%d段"%(i+1))
	text+="\n"+" → ".join(names)+"\n末段结束重新起手；防御、闪避、施法、使用物品或换装中断接续。"
	for i in range(attacks.size()):
		var stroke:=attacks[i]
		text+="\n%d · %s · 起手%.2f / 恢复%.2f秒 · 距离%.0f · 扇面%.0f° · 体力%.0f · 冲击%.0f"%[i+1,names[i],stroke.windup,stroke.recovery,stroke.reach,stroke.angle_degrees,stroke.stamina_cost,stroke.impact]
		text+=" · 前踏%.0f · 出手移速%.0f%% / 收招恢复至%.0f%%"%[stroke.step_distance,stroke.movement_multiplier*100,stroke.recovery_movement_multiplier*100]
	return text
