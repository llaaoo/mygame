class_name ElementTrialRecorder
extends Node
## Measurements describe actual committed play, not projected combo counts.
const LABELS := ["冻结控制", "破冰兑现", "导电布场", "污染引燃"]
var game: MVPGame
var active := false
var run: Dictionary = {}
var _started := 0.0

func _ready() -> void:
	game.player.skill_manager.cast_committed.connect(_on_cast)
	game.player.combat_component.melee_started.connect(_on_melee)
	CombatExecutor.instance.damage_applied.connect(_on_damage)
	game.region_changed.connect(_on_region)

func _snapshot() -> Dictionary:
	var equipment := game.player.get_node("EquipmentManager") as EquipmentManager
	var ids: Array[String] = []
	for item in equipment.get_all_equipped(): ids.append(item.id)
	ids.sort()
	var stats: Dictionary = {}
	for key in Buff.PRIMARY_STATS: stats[key] = game.player.stats_component.get(key)
	return {"stats": stats, "max_hp": game.player.health_component.max_hp, "max_mp": game.player.mana_component.max_mp, "equipment": ids, "loadout": game.player.skill_manager.serialize_skill_state(), "supplies": game.player.skill_manager.combinations.supplies.serialize()}

func start(label: String) -> bool:
	if active or label not in LABELS: return false
	_started = GameRuntime.instance.get_simulation_runtime().elapsed_time
	run = {"label": label, "seconds": 0.0, "casts": 0, "melee": 0, "damage_dealt": 0, "damage_taken": 0, "mana_spent": 0, "materials": {}, "regions": [game.region_id], "initial": _snapshot(), "final": {}, "result": "进行中"}
	active = true
	game.ui.close_modal()
	game.ui.notify("开始记录：" + label + "。按自己的配置探索；J可结束记录。按实际配置和补给计量。")
	return true

func finish(result: String = "手动结束") -> Dictionary:
	if not active: return {}
	run.seconds = maxf(0.0, GameRuntime.instance.get_simulation_runtime().elapsed_time - _started)
	run.final = _snapshot()
	run.result = result
	active = false
	game.progress.trial_runs.append(run.duplicate(true))
	while game.progress.trial_runs.size() > 10: game.progress.trial_runs.pop_front()
	game._save_progress()
	return run.duplicate(true)

func _on_cast(plan: CastPlan) -> void:
	if not active: return
	run.casts += 1
	run.mana_spent += plan.cost
	for id in plan.material_costs:
		run.materials[id] = int(run.materials.get(id, 0)) + int(plan.material_costs[id])

func _on_melee() -> void:
	if active: run.melee += 1

func _on_damage(source: Node2D, target: Node2D, amount: int) -> void:
	if not active: return
	if target == game.player: run.damage_taken += amount
	elif source == game.player and target.is_in_group("enemy"): run.damage_dealt += amount

func _on_region(id: String) -> void:
	if active and (run.regions.is_empty() or run.regions.back() != id): run.regions.append(id)

func _finish_and_show() -> void:
	finish()
	show_page()

func show_page() -> void:
	var text := "实验路线\n营地→外院→档案室→外院→火药库→排水回廊→蓄水机房→营地。目标20—30分钟，实际用时由记录校准。\n\n档案室先试保留冻结与破冰；排水回廊试清洗、蒸汽庇护与污染；机房试阀门、断路和接回。档案室晶簇可由火花→震荡或凝霜→震荡处理，回廊封匣也可由实际蒸汽保持半秒解开；机房仍需要实际连通的导电水域。三处机关分别开放东北侧独立返营捷径，旧返程继续可用。三份实地观察与机关成果可在营地交付“狱中复核”。实验补给只领一次，基本战斗与原有出口不依赖某一种消耗品。回营地可换装备，K编组、M选材料。\n\n配置建议\n冻结控制：水引配霜盐或用霜阵施法，普通近战保留冻结减速；用走位和霜行维持空间。\n破冰兑现：先准备冻结，再以阵外震荡换取碎冰伤害并失去剩余控制。\n导电布场：先看水路与干地，再以雷晶粉水引或雷阵施法导电；留出自己的干燥落脚点。\n污染引燃：毒雾或毒水制造持续压力，等待或用火花兑现；清洁水与污染水用途不同。\n\n当前工具\n"
	for id in ["water_call", "pulse", "frost_sigil", "storm_sigil", "venom_mist"]:
		var skill := game.player.skill_manager.pool.get_skill(id)
		text += "%s：%s\n" % [skill.display_name, "已学，K可编组" if game.progress.actions.has(id) else "尚未掌握，沿路线查阅记录"]
	text += "\n记录包含实际施法与近战次数、已提交MP与材料消耗、造成伤害、自身受伤、游戏内用时和起止配置。菜单暂停时间不计入；由环境造成且无法归因玩家的伤害不计入造成伤害。初始属性/装备/补给保存在记录中，比较时应使用相近预算。最多保留10次；按自己的配置与补给开始。\n"
	if active:
		text += "\n正在记录：%s · %.1f秒 · 施法/近战合计%d次\n" % [run.label, GameRuntime.instance.get_simulation_runtime().elapsed_time - _started, int(run.casts) + int(run.melee)]
	for entry in game.progress.trial_runs:
		var region_titles: Array[String] = []
		for id in entry.regions:
			region_titles.append(game.catalog.regions[id].title if game.catalog.regions.has(id) else "未命名区域")
		var equipment_titles: Array[String] = []
		for id in entry.initial.get("equipment", []):
			equipment_titles.append(game.catalog.equipment[id].display_name if game.catalog.equipment.has(id) else "其他装备")
		text += "\n%s · %.1f秒 · %s\n施法%d / 近战%d · 造成%d / 受伤%d · MP%d\n材料：%s\n路线：%s\n起始装备：%s\n" % [entry.label, entry.seconds, entry.result, entry.casts, entry.melee, entry.damage_dealt, entry.damage_taken, entry.mana_spent, _material_text(entry.materials), "→".join(region_titles), "、".join(equipment_titles) if not equipment_titles.is_empty() else "无"]
		var stats: Dictionary = entry.initial.get("stats", {})
		text += "起始上限：生命%d / 法力%d；力%d 智%d 敏%d 耐%d\n起始材料：%s\n" % [entry.initial.get("max_hp", 0), entry.initial.get("max_mp", 0), stats.get("strength", 0), stats.get("intelligence", 0), stats.get("agility", 0), stats.get("endurance", 0), _material_text(entry.initial.get("supplies", {}).get("amounts", {}))]
		if entry.initial != entry.final: text += "过程中配置或库存发生变化，起止状态均已记录。\n"
	var buttons: Array[Dictionary] = []
	if active:
		buttons.append({"title": "结束并保存当前记录", "callback": _finish_and_show})
	else:
		for label in LABELS: buttons.append({"title": "开始记录：" + label, "callback": start.bind(label)})
	buttons.append({"title": "返回日志", "callback": game.ui.show_journal})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("元素实验 · 路线与配置记录", text, buttons)

func _material_text(amounts: Dictionary) -> String:
	var parts: Array[String] = []
	var supplies := game.player.skill_manager.combinations.supplies
	for id in amounts:
		if int(amounts[id]) > 0: parts.append("%s×%d" % [supplies.title(id), int(amounts[id])])
	return "、".join(parts) if not parts.is_empty() else "无"
