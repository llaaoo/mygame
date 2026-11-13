class_name CorpseHarvesting
extends RefCounted
## UI/world adapter; inventory owns every source UID and the atomic conversion.
var game: GrayriverGame
func _init(owner_game: GrayriverGame) -> void: game=owner_game
func entries(corpse_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for row in game.session.inventory.entries(corpse_id+".anatomy"):
		var part: Variant=row.properties.get("harvest")
		if not HarvestPart.valid(part): continue
		var refusal:=reason(corpse_id,row.uid,part)
		result.append({"id":"harvest:"+row.uid,"uid":row.uid,"kind":"harvest","item":row.definition,"title":part.title,"text":"需要技艺：%s\n工具：%s\n完成后得到：%s\n\n未学会的部位会保留，可学习后回来处理。移动、受伤、离区或失去工具会中断，不消耗部位。"%[FieldcraftCatalog.default_catalog().skill(part.skill).title,ItemCatalog.default_catalog().definition(part.tool).display_name,game.survival.supplies.describe_cost(part.outputs)],"subtitle":refusal if not refusal.is_empty() else "可处理 · %.1f秒"%float(part.duration),"part":part.duplicate(true)})
	return result
func reason(corpse_id: String,uid: String,expected: Dictionary,tool_uid := "") -> String:
	if not HarvestPart.valid(expected): return "部位配置无效"
	if not game.loot.available(corpse_id): return "靠近这具遗骸再处理"
	var store:=game.session.inventory;var entry:=store.item(uid)
	if not entry or store.locate(uid)!=corpse_id+".anatomy" or entry.properties.get("harvest",{})!=expected: return "原部位已处理或发生变化"
	if not game.player.actor_context.fieldcraft.knows("player",expected.skill): return "尚未学会："+FieldcraftCatalog.default_catalog().skill(expected.skill).title
	if tool_uid.is_empty(): tool_uid=store.find_owned("player",expected.tool)
	if tool_uid.is_empty() or not store.item(tool_uid) or store.item(tool_uid).definition_id!=expected.tool or store.locate(tool_uid) not in store.actor_containers("player"): return "需要随身工具："+ItemCatalog.default_catalog().definition(expected.tool).display_name
	var corpse:=game.loot.corpses.get(corpse_id) as Node2D
	if game.player.global_position.distance_to(corpse.global_position)>PlayerFieldWork.RANGE: return "靠近遗骸再处理（80范围内）"
	var ray:=PhysicsRayQueryParameters2D.create(game.player.global_position,corpse.global_position,1,[game.player.get_rid()])
	if not game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return "遗骸被墙体阻挡"
	var preview:=store.process_anatomy("player",corpse_id,uid,false)
	return "" if preview.accepted else "产物放不下，先腾出携带空间" if preview.reason=="capacity" else "部位已不可用"
func inspect(corpse_id: String,uid: String) -> void:
	var row:=game.session.inventory.item(uid)
	if not row or not HarvestPart.valid(row.properties.get("harvest")): return
	var part: Dictionary=row.properties.harvest.duplicate(true)
	var tool_uid:=game.session.inventory.find_owned("player",part.tool)
	var refusal:=reason(corpse_id,uid,part,tool_uid)
	if not refusal.is_empty(): game.ui.notify(refusal);return
	game.ui.close_modal()
	var method:=FieldWorkMethod.new();method.id="harvest.corpse."+uid;method.title=part.title;method.duration=float(part.duration);method.animation_id=&"work_gather"
	game.player.field_work.inspect(game.loot.corpses[corpse_id],part.title,[method],func(_method):return reason(corpse_id,uid,part,tool_uid),func(_method):return complete(corpse_id,uid,part,tool_uid),"沿切口仔细处理；移动或受伤会中断，未处理的部位保留。")
func complete(corpse_id: String,uid: String,part: Dictionary,tool_uid: String) -> bool:
	if not reason(corpse_id,uid,part,tool_uid).is_empty(): return false
	var result:=game.session.inventory.process_anatomy("player",corpse_id,uid)
	if not result.accepted: return false
	game.loot.corpses[corpse_id].refresh()
	game.ui.notify("完成"+str(part.title)+"："+game.survival.supplies.describe_cost(part.outputs))
	game._save_progress()
	return true
