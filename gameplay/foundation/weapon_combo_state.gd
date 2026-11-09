class_name WeaponComboState
extends RefCounted
## Per-actor transient progress. Definitions and inventory never store a chain.
var weapon_uid := ""
var moveset: WeaponMoveset
var current_index := -1
var next_index := 0
var remaining := 0.0
var active := false
var family := ""
var hit_confirmed := false

func stage_for(uid: String,definition: WeaponMoveset) -> int:
	return next_index if uid==weapon_uid and definition==moveset and remaining>0 else 0

func begin(uid: String,definition: WeaponMoveset,action_family := "") -> void:
	var index:=stage_for(uid,definition)
	reset()
	if not definition or definition.attacks.is_empty(): return
	weapon_uid=uid; moveset=definition; current_index=index; active=true
	family=action_family

func confirm_contact(action_family: String) -> void:
	if moveset and not family.is_empty() and family==action_family: hit_confirmed=true

func permits_followup(technique: MartialTechnique,recovering := false) -> bool:
	return moveset!=null and hit_confirmed and technique.followup_profile!=null and technique.weapon_type==moveset.weapon_type and current_index in technique.followup_after and ((active and recovering) or (not active and remaining>0))

func complete() -> void:
	if not active: return
	active=false
	next_index=(current_index+1)%moveset.attacks.size()
	remaining=moveset.chain_window if next_index>0 else 0.0
	if next_index==0: reset()

func advance(delta: float,uid: String) -> void:
	if uid!=weapon_uid: reset(); return
	if active: return
	remaining=maxf(0,remaining-delta)
	if remaining==0: reset()

func reset() -> void:
	weapon_uid=""; moveset=null; current_index=-1; next_index=0
	remaining=0; active=false
	family=""; hit_confirmed=false

func snapshot() -> Dictionary:
	if not moveset: return {}
	var index:=current_index if active else next_index
	var title:=moveset.attacks[index].title
	return {"active":active,"index":index,"count":moveset.attacks.size(),"title":title if not title.is_empty() else "第%d段"%(index+1),"weapon":WeaponMoveset.TITLES.get(moveset.weapon_type,moveset.weapon_type),"remaining":remaining,"window":moveset.chain_window}
