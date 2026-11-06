class_name RepairFacilityService
extends RefCounted
## Fixed facility construction shares the live-work/payment/lifecycle boundary.
var game: CampaignGame
func _init(owner_game: CampaignGame) -> void: game = owner_game

func mount(spec: RepairFacilityData) -> void:
	var node := game.builder._add_interaction(spec.title, spec.pos, Callable(), "mechanism")
	node.set_meta("repair_facility", spec)
	if spec.service == "outpost": node.set_meta("survival_field_rest", spec.id)
	_refresh(node, spec)
	node.callback = inspect.bind(node, spec)

func _refresh(node: ExplorationInteractable, spec: RepairFacilityData) -> void:
	node.set_title(spec.title + ((" · 野外短休" if spec.service == "outpost" else " · 材料回收") if game.progress.claims.has(spec.id) else " · 待修复"))

func inspect(node: ExplorationInteractable, spec: RepairFacilityData) -> void:
	if not _valid(node, spec): return
	game.progress.claims["seen." + spec.id] = true
	game._queue_save()
	if game.progress.claims.has(spec.id):
		if spec.service == "outpost": game.survival.inspect_field_rest(node)
		else: game.workshop.show_recycling()
		return
	if not spec.start_claim.is_empty() and game.progress.claim(spec.start_claim, "委托：" + spec.title, spec.description, [], []):
		game._save_progress()
		game.ui.notify("已记录：" + spec.title + "。J可查看当前步骤。")
	var options: Array[FieldWorkMethod] = [spec.assembly]
	game.player.field_work.inspect(node, spec.title, options, _reason.bind(node, spec), _assemble.bind(node, spec), spec.description)

func _valid(node: ExplorationInteractable, spec: RepairFacilityData) -> bool:
	return not game._switching and is_instance_valid(node) and node.get_parent() == game.region_root and spec in game.current_data.facilities and not game.player.health_component.is_dead and game.player.global_position.distance_to(node.global_position) <= PlayerFieldWork.RANGE

func _reason(method: FieldWorkMethod, node: ExplorationInteractable, spec: RepairFacilityData) -> String:
	if not _valid(node, spec) or method != spec.assembly: return "设施已不可用"
	if game.progress.claims.has(spec.id): return "设施已修复"
	if spec.requires_clear:
		if not game.is_area_cleared(spec.pos): return "先清理本区，再建设前哨"
		if game.has_hostiles_near(spec.pos): return "现场仍有敌人，无法建设"
	for id in spec.required_claims:
		if not game.progress.claims.has(id): return "还需：" + claim_title(id)
	return ""

func _assemble(method: FieldWorkMethod, node: ExplorationInteractable, spec: RepairFacilityData) -> bool:
	if not _reason(method, node, spec).is_empty(): return false
	var supplies := game.player.skill_manager.combinations.supplies
	supplies.begin_transaction()
	if not supplies.pay(method.material_costs):
		supplies.finish_transaction(false)
		return false
	var text := spec.description if spec.completion_text.is_empty() else spec.completion_text
	if not game.progress.claim(spec.id, spec.title + " · 已完成", text, [], []):
		supplies.finish_transaction(false)
		return false
	game.progress.choices[spec.id] = method.id
	_refresh(node, spec)
	game.builder.mount_available_stations()
	var notify := supplies.finish_transaction(true)
	if notify.is_valid(): notify.call()
	game._save_progress()
	game.ui.notify(text)
	return true

func claim_title(id: String) -> String: return id
