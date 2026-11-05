class_name AlchemyRepairService
extends RefCounted
const REPAIRED := "alchemy.repaired"
const PUMP := "alchemy.pump_open"
const REGULATOR := "alchemy.regulator_open"
var game: MVPGame
func _init(owner_game: MVPGame) -> void: game = owner_game

func mount(spec: RepairFacilityData) -> void:
	var node := game.builder._add_interaction(spec.title, spec.pos, Callable(), "mechanism")
	_refresh(node, spec)
	node.callback = inspect.bind(node, spec)

func _refresh(node: ExplorationInteractable, spec: RepairFacilityData) -> void:
	node.set_title(spec.title + (" · 材料回收" if game.progress.claims.has(spec.id) else " · 待修复"))

func inspect(node: ExplorationInteractable, spec: RepairFacilityData) -> void:
	if not _valid(node, spec): return
	if game.progress.claims.has(spec.id):
		game.workshop.show_recycling()
		return
	if game.progress.claim(spec.start_claim, "委托：" + spec.title, spec.description, [], []):
		game._save_progress()
		game.ui.notify("接下检修委托：先在档案室寻找图纸。J可查看当前步骤。")
	var options: Array[FieldWorkMethod] = [spec.assembly]
	game.player.field_work.inspect(node, spec.title, options, _reason.bind(node, spec), _assemble.bind(node, spec), spec.description)

func _valid(node: ExplorationInteractable, spec: RepairFacilityData) -> bool:
	return not game._switching and game.region_id == "camp" and is_instance_valid(node) and node.get_parent() == game.region_root and spec in game.current_data.facilities and not game.player.health_component.is_dead and game.player.global_position.distance_to(node.global_position) <= PlayerFieldWork.RANGE

func _reason(method: FieldWorkMethod, node: ExplorationInteractable, spec: RepairFacilityData) -> String:
	if not _valid(node, spec) or method != spec.assembly: return "调和台已不可用"
	if game.progress.claims.has(spec.id): return "调和台已修复"
	for id in spec.required_claims:
		if not game.progress.claims.has(id): return "还需：" + claim_title(id)
	return ""

func _assemble(method: FieldWorkMethod, node: ExplorationInteractable, spec: RepairFacilityData) -> bool:
	if not _reason(method, node, spec).is_empty() or not method.material_costs.is_empty(): return false
	if not game.progress.claim(spec.id, "调和台重启", "泵芯与调压器已安装。营地永久开放材料回收：消耗两批成品，返还一批原配方投入。还可在委托板交付，领取1属性点（一次）。", [], []): return false
	game.progress.choices[spec.id] = method.id
	_refresh(node, spec)
	game._save_progress()
	game.ui.notify("调和台已修复：靠近E或M进入回收。委托板可交付1属性点奖励。")
	return true

func on_opened(spec: SpellPuzzleData) -> void:
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	if spec.id == PUMP:
		# React with water instead of replacing ice/fire/electricity with a medium.
		for patch in game.current_data.surface_patches:
			if patch.disabled_by_claim == PUMP:
				surfaces.apply_area(game.region_root.to_global(patch.pos), patch.radius, ["water"], "修复排污泵")
	elif spec.id == REGULATOR:
		surfaces.apply_area(game.region_root.to_global(spec.pos), 105, [], "调压器泄压", "steam", 6)

func claim_title(id: String) -> String:
	match id:
		"alchemy.started": return "营地接下检修委托"
		"alchemy.schematic": return "档案室调和台图纸"
		"alchemy.pump_taken": return "回廊泵芯（解封后靠近E取件）"
		"alchemy.regulator_taken": return "机房调压器（解封后靠近E取件）"
	return id

func status_text() -> String:
	if game.progress.claims.has(REPAIRED): return "调和台已重启：营地E或M可回收多余成品；委托板奖励仅领一次。"
	var text := "重启调和台\n营地东北调和台接下委托；档案室图纸可提前阅读。解封与取件分开，部件不占施法材料库存。\n"
	for id in ["alchemy.started", "alchemy.schematic", "alchemy.pump_taken", "alchemy.regulator_taken"]:
		text += ("✓ " if game.progress.claims.has(id) else "□ ") + claim_title(id) + "\n"
	text += "回廊：力量14站定2秒，或火→水→冲击／凝霜→冲击；冲净旧毒区也会失去阻挡敌人的毒地。\n机房：智力14站定2.5秒，或实际蒸汽保持0.5秒，或树脂制剂1＋晶砂2站定1.5秒；首次解封会泄出6秒蒸汽。\n回营地组装3秒，无额外材料。现场E查看、Q切换、E开始；战斗继续，受伤或其他动作会打断，成功才扣料。\n"
	return text
