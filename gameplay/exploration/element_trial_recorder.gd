class_name ElementTrialRecorder
extends Node
## Measurements describe actual committed play, not projected combo counts.
const LABELS := ["冻结控制", "破冰兑现", "导电布场", "污染引燃"]
var game: CampaignGame
var active := false
var run: Dictionary = {}
var _started := 0.0

func _ready() -> void:
	game.player.skill_manager.cast_committed.connect(_on_cast)
	game.player.combat_component.melee_started.connect(_on_melee)
	game.player.field_work.work_committed.connect(_on_work)
	game.player.field_work.work_started.connect(_on_work_started)
	game.player.field_work.work_cancelled.connect(_on_work_cancelled)
	game.player.health_component.recovered.connect(_on_recovery.bind("hp"))
	game.player.mana_component.recovered.connect(_on_recovery.bind("mp"))
	SurfaceManager.instance.reaction_occurred.connect(_on_surface)
	(game.player.get_node("SkillSynergyResolver") as SkillSynergyResolver).reaction_recorded.connect(_on_hit_reaction)
	CombatExecutor.instance.damage_applied.connect(_on_damage)
	game.region_changed.connect(_on_region)

func _snapshot() -> Dictionary:
	var equipment := game.player.get_node("EquipmentManager") as EquipmentManager
	var ids: Array[String] = []
	for item in equipment.get_all_equipped(): ids.append(item.id)
	ids.sort()
	var stats: Dictionary = {}
	for key in Buff.PRIMARY_STATS: stats[key] = game.player.stats_component.get(key)
	return {"stats": stats, "max_hp": game.player.health_component.max_hp, "max_mp": game.player.mana_component.max_mp, "equipment": ids, "loadout": game.player.skill_manager.serialize_skill_state(), "supplies": game.player.skill_manager.combinations.supplies.serialize(), "survival": game.survival.serialize(), "world_choices": game.progress.choices.duplicate()}

func start(label: String) -> bool:
	if active or label not in LABELS: return false
	_started = GameRuntime.instance.get_simulation_runtime().elapsed_time
	run = {"recovery": {"hp": {}, "mp": {}}, "work_attempts": {}, "work_interruptions": {}, "cast_steps": [], "surface_steps": [], "label": label, "seconds": 0.0, "casts": 0, "melee": 0, "damage_dealt": 0, "damage_taken": 0, "mana_spent": 0, "materials": {}, "regions": [game.region_id], "initial": _snapshot(), "final": {}, "result": "进行中"}
	active = true
	game.ui.close_modal()
	game.ui.notify("开始记录：" + label + "。此项仅记录操作，不应用装备、素材、Buff或连招；J可结束记录。")
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
	if run.cast_steps.size() < 128:
		var explanation: Array[String] = []
		for step in plan.explanation: explanation.append(step.text)
		run.cast_steps.append({"action": plan.action.get_id(), "result": plan.effect_label, "explanation": explanation})
	run.casts += 1
	run.mana_spent += plan.cost
	for id in plan.material_costs:
		run.materials[id] = int(run.materials.get(id, 0)) + int(plan.material_costs[id])

func _on_recovery(amount: float, source: String, resource: String) -> void:
	if active and amount > 0:
		run.recovery[resource][source] = float(run.recovery[resource].get(source, 0)) + amount

func _on_work_started(method: FieldWorkMethod) -> void:
	if active: run.work_attempts[method.id] = int(run.work_attempts.get(method.id, 0)) + 1

func _on_work_cancelled(method: FieldWorkMethod, _reason: String) -> void:
	if active: run.work_interruptions[method.id] = int(run.work_interruptions.get(method.id, 0)) + 1

func _on_surface(id: String, cell: Vector2i, source: String) -> void:
	if active and run.surface_steps.size() < 128: run.surface_steps.append({"reaction": id, "cell": [cell.x, cell.y], "source": source})

func _on_hit_reaction(details: Dictionary) -> void:
	if active and run.surface_steps.size() < 128: run.surface_steps.append(details.duplicate(true))

func _on_melee() -> void:
	if active: run.melee += 1

func _on_work(method: FieldWorkMethod) -> void:
	if not active: return
	run["work_actions"] = int(run.get("work_actions", 0)) + 1
	for id in method.material_costs:
		run.materials[id] = int(run.materials.get(id, 0)) + int(method.material_costs[id])

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
	var text := "实验记录\n这些名称只标记实际操作，不会装备方案、准备恩赐或自动施法。先观察身边条件，再亲手使用已学基础动作；记录保留成本、失败与世界变化。\n\n已到达的实验地点\n"
	for id in ["camp", "yard", "archive", "powder", "drain", "cistern"]:
		if game.progress.visited.has(id): text += game.catalog.regions[id].title + "\n"
	if game.progress.claims.has("field.archive_observation"): text += "\n档案室观察：保留冻结减速，或用阵外震荡兑现伤害并接回水路。\n"
	if game.progress.claims.has("field.drain_observation"): text += "\n回廊观察：清洁水、蒸汽与污染用途不同，自己也要承担危险地面。\n"
	if game.progress.claims.has("field.cistern_observation"): text += "\n机房观察：干地断路，冻结可切断连接，破冰恢复通路。\n"
	if game.progress.claims.has("alchemy.started"): text += "\n检修委托详见J：解封与取件分开，现场作业不暂停；可先创造安全窗口再站定。\n"
	text += "\n当前工具\n"
	for id in ["water_call", "pulse", "frost_sigil", "storm_sigil", "venom_mist"]:
		var skill := game.player.skill_manager.pool.get_skill(id)
		if game.player.skill_manager.knows_action(skill): text += skill.display_name + "：已学，K可编组\n"
	text += "\n已经发现并解锁的检修通路可直接返场。已清理区域按Esc可重试本区，耗材照常消耗，击杀没有经验、掉落或残魂；探索进度保留。\n\n记录包含实际施法、近战与作业次数、已提交MP与材料消耗、造成伤害、自身受伤、游戏内用时和起止配置。菜单暂停时间不计入；由环境造成且无法归因玩家的伤害不计入造成伤害。初始属性/装备/补给保存在记录中，比较时应使用相近预算。最多保留10次；开始按钮只给记录命名，不修改动作、库存、装备、恩赐或世界。\n"
	if active:
		text += "\n正在记录：%s · %.1f秒 · 施法/近战合计%d次\n" % [run.label, GameRuntime.instance.get_simulation_runtime().elapsed_time - _started, int(run.casts) + int(run.melee)]
	for entry in game.progress.trial_runs:
		var region_titles: Array[String] = []
		for id in entry.regions:
			region_titles.append(game.catalog.regions[id].title if game.catalog.regions.has(id) else "未命名区域")
		var equipment_titles: Array[String] = []
		for id in entry.initial.get("equipment", []):
			equipment_titles.append(game.catalog.equipment[id].display_name if game.catalog.equipment.has(id) else "其他装备")
		text += "\n%s · %.1f秒 · %s\n施法%d / 近战%d / 作业%d · 造成%d / 受伤%d · MP%d\n材料：%s\n路线：%s\n起始装备：%s\n" % [entry.label, entry.seconds, entry.result, entry.casts, entry.melee, entry.get("work_actions", 0), entry.damage_dealt, entry.damage_taken, entry.mana_spent, _material_text(entry.materials), "→".join(region_titles), "、".join(equipment_titles) if not equipment_titles.is_empty() else "无"]
		text += "实际恢复（按来源）：" + JSON.stringify(entry.get("recovery", {})) + "\n作业尝试/中断：" + JSON.stringify(entry.get("work_attempts", {})) + " / " + JSON.stringify(entry.get("work_interruptions", {})) + "\n"
		var steps: Array = entry.get("cast_steps", [])
		if not steps.is_empty():
			text += "实际过程（最近8次）：\n"
			for step in steps.slice(maxi(0, steps.size() - 8)):
				text += str(step.action) + " → " + str(step.result) + "\n" + "；".join(step.get("explanation", [])) + "\n"
		for step in entry.get("surface_steps", []).slice(0, 8):
			text += "实际反应：" + str(step.reaction) + " · " + str(step.source) + "\n"
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
