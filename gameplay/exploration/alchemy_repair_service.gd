class_name AlchemyRepairService
extends RepairFacilityService
const REPAIRED := "alchemy.repaired"
const PUMP := "alchemy.pump_open"
const REGULATOR := "alchemy.regulator_open"

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
	text += "回廊：力量14站定2秒，或火→水→冲击／凝霜→冲击；冲净旧毒区也会失去阻挡敌人的毒地。\n机房：智力14站定2.5秒，或实际蒸汽保持0.5秒，或树脂制剂1＋晶砂2站定1.5秒；首次解封会泄出6秒蒸汽。\n回营地组装3秒，无额外材料。现场F查看、C切换、F开始；战斗继续，受伤或其他动作会打断，成功才扣料。\n"
	return text
