class_name ExplorationPresenter
extends RefCounted
var game: CampaignGame

func _init(owner_game: CampaignGame) -> void:
	game = owner_game

func show_arrival() -> void:
	var first_visit := game.progress.claims.is_empty() and game.progress.cleared.is_empty()
	var title := "余烬监狱 · 初次远征" if first_visit else "余烬监狱 · 继续旅程"
	var text := "先读营地材料手册，取得水引，再去外院寻找火阵记录。\n\n这次先试一条规律：火花在火阵内变为火球，阵外仍是近身火花。按住动作键观察范围，松开施放。\n\n左键近战，右键格挡，R键火花，空格闪避，F调查；J日志，M材料，K编组，O装备。"
	if not first_visit:
		text = "监狱封锁已解除，可以回访遗漏支路或尝试不同操作。" if game.progress.completed else "已恢复你的知识、装备、材料与探索进度。"
		var reports: Array[String] = []
		for quest in game.quests:
			if (quest.is_complete(game.progress) or quest.has_available_approach(game.progress, game.player.stats_component)) and not game.progress.claims.has("quest." + quest.id): reports.append(quest.title)
		if not reports.is_empty(): text += "\n\n可交付委托：" + "、".join(reports)
		var passages: Array[String] = []
		for region: ExplorationRegionData in game.catalog.regions.values():
			for exit in region.exits:
				if not exit.camp_return_title.is_empty() and exit.claims_satisfied(game.progress): passages.append(region.title)
		if not passages.is_empty(): text += "\n\n营地检修通路可直达：" + "、".join(passages)
		text += "\n\nJ查看记录与待办，O查看当前装备。已清区域可在Esc选择本区试战：耗材照常消耗，击杀没有奖励，探索进度保留。"
	text += "\n\n远征口粮袋在营地西侧，N查看饮食、饮水与疲劳。回营不自动补满，在篝火主动短休或充分休整；缺补给时可吃免费粗食。"
	game.ui.show_panel(title, text, [{"title": "开始探索" if first_visit else "继续旅程", "callback": game.ui.close_modal}, {"title": "查看探索日志", "callback": game.ui.show_journal}])

func _show_training() -> void:
	var stats := game.player.stats_component
	var values := stats.derived_values()
	var primary: Dictionary = values.primary
	var text := "可用属性点：%d\n基础：力量%d · 智力%d · 敏捷%d · 耐力%d\n当前有效：力量%d · 智力%d · 敏捷%d · 耐力%d\n\n当前战斗与生存\n近战%d · 魔法加成%d · 生命上限%d · 法力上限%d\n移速%.0f · 属性准备时间×%.2f · 持续／陷阱伤害降低%.0f%%\n\n" % [stats.attribute_points, stats.strength, stats.intelligence, stats.agility, stats.endurance, primary.strength, primary.intelligence, primary.agility, primary.endurance, game.player.combat_component.attack_damage, stats.magic_damage, game.player.health_component.max_hp, game.player.mana_component.max_mp, game.player.move_speed, stats.preparation_multiplier, (1 - stats.hazard_damage_multiplier) * 100]
	text += "力量：增强近战，可承担需要力量的任务处理方式。\n智力：增强魔法与法力，可通过记录推演解决任务。\n敏捷：增强移动，超过10后每点缩短1.5%准备，最多30%。\n耐力：增加生命，超过10后每点减免2%持续、环境与陷阱伤害，最多40%；不会免疫状态。\n\n下一点基础派生变化（已计入主属性增益，其他修正另计）\n"
	var buttons: Array[Dictionary] = []
	for pair in [["strength", "力量"], ["intelligence", "智力"], ["agility", "敏捷"], ["endurance", "耐力"]]:
		var next := stats.derived_values({pair[0]: int(stats.get(pair[0])) + 1})
		var change := ""
		var benefit := ""
		match pair[0]:
			"strength":
				change = "基础近战%d→%d" % [roundi((10 + values.physical_damage) * game.player.melee_damage_multiplier), roundi((10 + next.physical_damage) * game.player.melee_damage_multiplier)]
				benefit = change
			"intelligence":
				change = "魔法加成%d→%d，基础法力%d→%d" % [values.magic_damage, next.magic_damage, values.max_mana, next.max_mana]
				benefit = "法力%d→%d" % [values.max_mana, next.max_mana]
			"agility":
				change = "基础移速%.0f→%.0f，属性准备×%.3f→×%.3f" % [game.player.base_move_speed + values.move_speed_bonus, game.player.base_move_speed + next.move_speed_bonus, values.preparation_multiplier, next.preparation_multiplier]
				benefit = "准备缩短%.1f%%→%.1f%%" % [(1 - values.preparation_multiplier) * 100, (1 - next.preparation_multiplier) * 100]
			"endurance":
				change = "基础生命%d→%d，危险伤害减免%.0f%%→%.0f%%" % [50 + values.max_hp_bonus, 50 + next.max_hp_bonus, (1 - values.hazard_damage_multiplier) * 100, (1 - next.hazard_damage_multiplier) * 100]
				benefit = "生命%d→%d" % [50 + values.max_hp_bonus, 50 + next.max_hp_bonus]
		text += pair[1] + " +1：" + change + "\n"
		buttons.append({"title": pair[1] + " +1 · " + benefit, "tooltip": change, "disabled": stats.attribute_points <= 0, "callback": _train.bind(pair[0])})
	text += "\n升级获得属性点。任务按提交时的有效属性检查，可借助临时增益；原有常规交付方式保留。训练结果自动保存。"
	buttons.append({"title": "完成训练", "callback": game.ui.close_modal})
	game.ui.show_panel("营地训练", text, buttons)

func _train(stat: String) -> void:
	game.progress_service.train(stat)
	_show_training()

func _update_objective() -> void:
	game.ui.heading.text = game.current_data.title + (" · 已清理" if game.progress.cleared.has(game.region_id) else "")
	if game.practice_active: game.ui.heading.text = game.current_data.title + " · 本区试战"
	game.ui.objective.text = game.current_data.description + ("\n剩余敌人：%d" % game.active_enemies.size() if not game.active_enemies.is_empty() else "")
	if game.region_id == "boss" and game.progress.choices.get("waterworks_choice", "") == "cooling":
		game.ui.objective.text += "\n冷却水路生效：领主生命 -25%，火抗降至10%。"

func _show_quests() -> void:
	var text := "艾妲：把你发现的知识和监狱的变化带回来。奖励每项只发放一次，重置遭遇不会重复领取。\n\n" if game.progress.claims.has("cartographer_rescued") else "委托留在营地，随时可以查看和交付。奖励每项只发放一次。\n\n"
	var buttons: Array[Dictionary] = []
	for quest in game.quests:
		var claimed := game.progress.claims.has("quest." + quest.id)
		var complete := quest.is_complete(game.progress)
		var alternate := quest.has_available_approach(game.progress, game.player.stats_component)
		var status := "已交付" if claimed else ("可交付" if complete else "可选交付" if alternate else "进行中")
		text += "%s [%s] %d/%d\n%s\n奖励：%d 属性点\n\n" % [quest.title, status, quest.objective_count(game.progress), quest.required_claims.size() + quest.required_clears.size(), quest.description, quest.attribute_points]
		buttons.append({"title": ("已交付：" if claimed else "交付：") + quest.title, "disabled": claimed or not complete, "callback": _claim_quest.bind(quest)})
		for approach in quest.approaches:
			var available := approach.available(game.progress, game.player.stats_component)
			var hint := game.player.stats_component.describe_requirements(approach.required_attributes) + "；" + _approach_evidence(approach)
			text += "可选方式：%s\n%s\n%s\n" % [approach.title, approach.description, hint]
			buttons.append({"title": approach.title + ("（已交付）" if claimed else ""), "tooltip": approach.description + "\n" + hint, "disabled": claimed or not available, "callback": _claim_quest.bind(quest, approach.id)})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("营地委托", text, buttons)

func _claim_quest(quest: ExplorationQuestData, approach_id: String = "") -> void:
	game.progress_service.claim_quest(quest, approach_id)
	_show_quests()

func _approach_evidence(approach: ExplorationQuestApproachData) -> String:
	var missing: Array[String] = []
	for id in approach.required_clears:
		if not game.progress.cleared.has(id): missing.append("清理" + game.catalog.regions[id].title)
	for id in approach.required_claims:
		if game.progress.claims.has(id): continue
		for region: ExplorationRegionData in game.catalog.regions.values():
			for entry in region.discoveries + region.spell_objects + region.events:
				if entry.id == id: missing.append(entry.title)
	return "现场凭据齐备" if missing.is_empty() else "还需：" + "、".join(missing)

func _show_world_event(entry: ExplorationWorldEventData) -> void:
	for id in entry.required_claims:
		if not game.progress.claims.has(id):
			game.ui.notify("设备尚未接通：先处理附近的实际水路机关。")
			return
	if game.has_hostiles_near(entry.pos):
		game.ui.notify("附近守卫仍在巡逻，先确保设备周围安全。")
		return
	var selected: String = game.progress.choices.get(entry.id, "")
	var text: String = entry.text + "\n\n"
	var buttons: Array[Dictionary] = []
	for choice in entry.choices:
		text += choice.title + ("（当前）" if selected == choice.id else "") + "\n" + choice.text + "\n\n"
		buttons.append({"title": choice.title, "disabled": selected == choice.id, "callback": _choose_world_event.bind(entry, choice)})
	text += "只能维持一条水路；可以回来改道。效果从下一次进入区域生效，不会重新生成已清场的敌人。"
	buttons.append({"title": "稍后决定", "callback": game.ui.close_modal})
	game.ui.show_panel(entry.title, text, buttons)

func _choose_world_event(entry: ExplorationWorldEventData, choice: ExplorationWorldChoiceData) -> void:
	if not game.progress_service.choose_world_event(entry, choice):
		return
	game.ui.close_modal()
	game.ui.notify("水路已改道，通往营地的检修梯已开启。")
	if not game.region_root.has_node("WaterworksShortcut"):
		var shortcut := game._add_interaction("检修梯：返回营地", Vector2(0, 300), func(): game.request_travel("camp"), "passage")
		shortcut.name = "WaterworksShortcut"

func journal_text() -> String:
	var text := "行动提示\n左键近战、右键格挡；R/6火花；1震荡、2凝神、3霜阵、4水引、5火阵需探索学习。雷阵与泼洒树脂用K编组；M选择本次材料，营地工作台加工。J关闭日志。\n\n法术联动\n已有动作可以通过元素、材料、恩赐、法阵和装备改变用途。点击“元素关系”查看已读线索与实际验证；未验证的高级关系不会提前列出。\n\n路线与清理进度\n仅列出已经到达的地点；现场调查可发现新支路。\n"
	for id in game.catalog.regions:
		if not game.progress.visited.has(id): continue
		var data: ExplorationRegionData = game.catalog.regions[id]
		var state := "已清理" if game.progress.cleared.has(id) else ("已探索" if game.progress.visited.has(id) else "未探索")
		text += "%s · %s\n" % [data.title, state]
	text += "\n机关检修捷径\n"
	for region: ExplorationRegionData in game.catalog.regions.values():
		if not game.progress.visited.has(region.id): continue
		for exit in region.exits:
			if exit.target == "camp" and not exit.required_claims.is_empty():
				text += region.title + " · " + exit.title + ("：已开启，营地可直达返场\n" if exit.claims_satisfied(game.progress) else "：待解开对应机关\n" + exit.locked_message + "\n")

	text += "\n已发现补给与建设\n"
	for region: ExplorationRegionData in game.catalog.regions.values():
		for station in region.survival_stations:
			if game.progress.claims.has("seen." + station.id): text += region.title + " · " + station.title + "\n"
		for facility in region.facilities:
			if game.progress.claims.has("seen." + facility.id) or game.progress.claims.has(facility.id):
				text += region.title + " · " + facility.title + ("：已建成\n" if game.progress.claims.has(facility.id) else "：待建设\n" + facility.description + "\n")
	text += "\n未取部件\n"
	for pair in [[AlchemyRepairService.PUMP, "alchemy.pump_taken", "排水回廊泵芯"], [AlchemyRepairService.REGULATOR, "alchemy.regulator_taken", "蓄水机房调压器"]]:
		if game.progress.claims.has(pair[0]) and not game.progress.claims.has(pair[1]): text += "□ " + pair[2] + "：已解封，靠近设备E取件\n"
	if game.progress.claims.has("alchemy.started") or game.progress.claims.has("alchemy.schematic"): text += "\n" + game.alchemy.status_text() + "\n"
	text += "\n远征生存（N补给）\n" + game.survival.description() + "\n"
	text += "\n本区试战\n在已清理区域按Fsc，可单独重试当地敌人。耗材照常消耗，击杀无经验、掉落或残魂；知识、机关、委托和其他区域进度保持。\n"
	text += "\n保留与兑现\n普通施法保留恩赐；Shift请求消费适配恩赐，形态与总成本见技能槽预览。节律护手可改为部分消费：保留当前剩余时长50%，较弱伤害倍率，每份另加3 MP。蕴魂、回响和护盾不受部分消费影响。\n"
	text += "\n营地委托（回营地交付）\n"
	for quest in game.quests:
		text += "%s · %s · %d/%d\n%s\n" % [quest.title, "已交付" if game.progress.claims.has("quest." + quest.id) else ("可交付" if quest.is_complete(game.progress) else "进行中"), quest.objective_count(game.progress), quest.required_claims.size() + quest.required_clears.size(), quest.description]
	text += "\n魂术与装备\n战死守卫留下60秒残魂，汲魂转为45秒蕴魂。普通施法保留，Shift用火花/震荡/凝神/水引各兑现1层；回响和护盾爆破保持更高优先级。O查看固定装备、来源与取舍，营地可换装。\n"
	text += "\n已学组合\n"
	for rule in game.player.skill_manager.combinations.rules:
		if game.progress.spell_rules.has(rule.id):
			var action := game.player.skill_manager.pool.get_skill(rule.trigger_action_id)
			var condition_cost := " + 蕴魂%d层" % rule.consume_stacks if rule.consume_stacks > 0 else " + 1次法阵触发" if not rule.required_field_type.is_empty() else (" + 消耗准备状态" if rule.consume_caster_status else "")
			text += "%s + %s → %s · %d MP%s\n%s\n" % [rule.condition_label(), action.display_name, rule.result_skill.display_name, rule.mana_cost, condition_cost, rule.result_skill.description]
	text += "\n当前水路\n"
	match str(game.progress.choices.get("waterworks_choice", "")):
		"cooling": text += "冷却熔炉：新遭遇的领主生命 -25%，火抗降至10%。\n"
		"conduit": text += "魔力导流：进入区域后法力回复由3提高到5 MP/秒。\n"
		_: text += "尚未重启。继续调查已发现的支路与设备。\n"
	text += "\n发现记录\n"
	for note in game.progress.journal:
		text += "\n%s\n%s\n" % [note.title, note.text]
	return text


func inspect_discovery(entry: ExplorationDiscoveryData, node: ExplorationInteractable, full: bool = false) -> void:
	if entry.requires_clear and not game.active_enemies.is_empty():
		game.ui.notify("先清除守卫，再靠近这里调查。")
		return
	var first_read := not game.progress.claims.has(entry.id)
	if game.progress_service.discover(entry):
		if is_instance_valid(node): node.set_title(entry.title + "（已记录）")
		if entry.id == "cartographer_rescued":
			game.ui.notify("测绘员已沿清理过的道路返回营地。回去交付委托可领取成长奖励。")
		if entry.hide_when_claimed and is_instance_valid(node) and not game.equipment_service.has_pending_rewards(entry):
			node.queue_free()
	var brief := first_read and not full and not entry.intro_text.is_empty()
	var text := entry.intro_text + "\n\n完整用法已记入J日志，可随时回看。" if brief else entry.text
	var buttons: Array[Dictionary] = [{"title": "记入日志，继续探索", "callback": game.ui.close_modal}]
	if brief: buttons.append({"title": "查看完整记录", "callback": inspect_discovery.bind(entry, null, true)})
	if not entry.equipment.is_empty(): text += "\n\n背包已满时，装备保留在原处，再次调查即可领取。"
	for id in entry.equipment:
		var item := game.catalog.equipment.get(id) as EquipmentData
		if item:
			var received := game.progress.claims.has("equipment."+entry.id+"."+id)
			text += "\n\n%s：%s\n%s\n按O查看装备与来源，返回镇中整备。" % ["已领取装备" if received else "装备留在此处（背包已满）", item.display_name, item.description]
			buttons.append({"title": "查看：" + item.display_name, "callback": game.equipment_service.show_detail.bind(id)})
	game.ui.show_panel(entry.title, text, buttons)

func inspect_puzzle(spec: SpellPuzzleData, completed: bool) -> void:
	game.ui.show_panel(spec.title, "机关已解开，奖励已保存。" if completed else spec.hint, [{"title": "继续探索", "callback": game.ui.close_modal}])
