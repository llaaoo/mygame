class_name FieldWorkSites
extends RefCounted
## Scene adapter: every real site uses one completion/payment authority.
var game: CampaignGame
func _init(owner_game: CampaignGame) -> void: game = owner_game

func reason(site: SpellWorldObject) -> String:
	if game._switching or not is_instance_valid(site) or not site.is_inside_tree() or site.get_parent() != game.region_root or site.spec not in game.current_data.spell_objects: return "设备已不可用"
	if site.completed or game.progress.claims.has(site.spec.id): return "设备已解封"
	return game.progress.condition_query.claims_reason(site.spec.required_claims)

func inspect(site: SpellWorldObject) -> void:
	if site.completed:
		if not site.spec.pickup_claim.is_empty(): take_part(site)
		else: game.presenter.inspect_puzzle(site.spec, true)
		return
	game.player.field_work.inspect(site, site.spec.title, site.spec.work_methods, _work_reason.bind(site), _commit_work.bind(site), site.spec.hint)

func on_inspected(_spec: SpellPuzzleData, _completed: bool, site: SpellWorldObject) -> void:
	inspect(site)

func complete_route(method_id: String, site: SpellWorldObject) -> bool:
	return complete(site, method_id)

func _work_reason(method: FieldWorkMethod, site: SpellWorldObject) -> String:
	if method not in site.spec.work_methods: return "未知作业方式"
	return reason(site)

func _commit_work(method: FieldWorkMethod, site: SpellWorldObject) -> bool:
	if not _work_reason(method, site).is_empty() or game.player.global_position.distance_to(site.global_position) > PlayerFieldWork.RANGE: return false
	return site.finish(method.id)

func complete(site: SpellWorldObject, method_id: String) -> bool:
	if not reason(site).is_empty(): return false
	return game.progress_service.solve_puzzle(site.spec, method_id)

func take_part(site: SpellWorldObject) -> bool:
	if not is_instance_valid(site) or site.get_parent() != game.region_root or site.spec not in game.current_data.spell_objects or game.player.health_component.is_dead or game.player.global_position.distance_to(site.global_position) > PlayerFieldWork.RANGE: return false
	if not game.progress.claims.has(site.spec.id) or site.spec.pickup_claim.is_empty(): return false
	if not game.progress.claim(site.spec.pickup_claim, "取得：" + site.spec.pickup_title, "已从" + site.spec.title + "取回" + site.spec.pickup_title + "，可用于营地修复。", [], []):
		game.ui.notify("部件已经取走。")
		return false
	site.part_taken = true
	site._refresh()
	game._save_progress()
	game.ui.notify("取得：" + site.spec.pickup_title + " · 已记入任务记录。")
	return true
