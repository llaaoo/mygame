class_name ExplorationPresenter
extends RefCounted
var game: MVPGame

func _init(owner_game: MVPGame) -> void:
	game = owner_game

func _show_training() -> void:
	var stats := game.player.stats_component
	var text := "可用属性点：%d\n力量 %d · 智力 %d · 敏捷 %d · 耐力 %d\n\n战斗获得经验，升级获得属性点。力量影响近战，智力影响魔法，敏捷影响移动，耐力影响生命。训练结果自动保存。" % [stats.attribute_points, stats.strength, stats.intelligence, stats.agility, stats.endurance]
	var buttons: Array[Dictionary] = []
	for pair in [["strength", "力量"], ["intelligence", "智力"], ["agility", "敏捷"], ["endurance", "耐力"]]:
		buttons.append({"title": pair[1] + " +1", "disabled": stats.attribute_points <= 0, "callback": _train.bind(pair[0])})
	buttons.append({"title": "完成训练", "callback": game.ui.close_modal})
	game.ui.show_panel("营地训练", text, buttons)

func _train(stat: String) -> void:
	game.progress_service.train(stat)
	_show_training()

func _update_objective() -> void:
	game.ui.heading.text = game.current_data.title + (" · 已清理" if game.progress.cleared.has(game.region_id) else "")
	game.ui.objective.text = game.current_data.description + ("\n剩余敌人：%d" % game.active_enemies.size() if not game.active_enemies.is_empty() else "")
	if game.region_id == "boss" and game.progress.choices.get("waterworks_choice", "") == "cooling":
		game.ui.objective.text += "\n冷却水路生效：领主生命 -25%，火抗降至10%。"

func _show_quests() -> void:
	var text := "艾妲：把你发现的知识和监狱的变化带回来。奖励每项只发放一次，重置遭遇不会重复领取。\n\n" if game.progress.claims.has("cartographer_rescued") else "委托留在营地，随时可以查看和交付。奖励每项只发放一次。\n\n"
	var buttons: Array[Dictionary] = []
	for quest in game.quests:
		var claimed := game.progress.claims.has("quest." + quest.id)
		var complete := quest.is_complete(game.progress)
		var status := "已交付" if claimed else ("可交付" if complete else "进行中")
		text += "%s [%s] %d/%d\n%s\n奖励：%d 属性点\n\n" % [quest.title, status, quest.objective_count(game.progress), quest.required_claims.size() + quest.required_clears.size(), quest.description, quest.attribute_points]
		buttons.append({"title": ("已交付：" if claimed else "交付：") + quest.title, "disabled": claimed or not complete, "callback": _claim_quest.bind(quest)})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("营地委托", text, buttons)

func _claim_quest(quest: ExplorationQuestData) -> void:
	game.progress_service.claim_quest(quest)
	_show_quests()

func _show_world_event(entry: ExplorationWorldEventData) -> void:
	if not game.active_enemies.is_empty():
		game.ui.notify("机房守卫仍在巡逻，先清场再操作阀门。")
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
	var text := "行动提示\n左键近战；右键/6火花；1震荡、2凝神、3霜阵、4水引、5火阵需探索学习。雷阵与泼洒树脂用K编组；M配置材料，营地工作台加工。J关闭日志。\n\n法术联动\n水引→冰霜：凝冻，额外30%伤害；冰霜→火球：融化，额外60%；水引→火球：蒸发，额外30%；水引→雷矢/雷环：导电，额外45%；雷息→雷矢/雷环：额外35%。目标反应使用命中时的状态，地面反应另行改变水、冰、蒸汽和带电区域。\n\n路线与清理进度\n营地 → 外院 → 火药库 → 重卫关隘 → 熔炉大厅\n外院 → 军械档案 → 静默祈堂\n火药库 → 排水回廊 → 蓄水机房\n"
	for id in game.catalog.regions:
		var data: ExplorationRegionData = game.catalog.regions[id]
		var state := "已清理" if game.progress.cleared.has(id) else ("已探索" if game.progress.visited.has(id) else "未探索")
		text += "%s · %s\n" % [data.title, state]
	text += "\n实验线索\n不同类型的法阵可以共同保留，站在重叠处观察同一动作的变化；同类重建只更新自己的阵。资源费用会在预览中合计。\n余烬战意赋予近战火焰性质，可对敌人和物体使用同一套火焰反应。\n雷电沿连通水面传播，干燥空隙会截断它；观察地面，也注意自己的站位。\n"
	text += "\n恩赐的保留与消耗\n普通施法保留恩赐：余烬/霜行使适配火焰/冰霜法术伤害+20%；雷息保留原有雷击命中+35%。按住Shift施放适配动作可消耗恩赐，额外3 MP：余烬换取更高伤害与燃烧区，霜行换取穿透/范围，雷息换取散射/范围。释放后失去其攻击、移速等持续收益。\n共鸣护盾在普通震荡时保留，Shift＋震荡才消耗护盾爆破。回响印记仍是一次性准备，正常转化即消费。悬停技能槽查看本次保留/消耗的状态。\n"
	text += "\n营地委托（回营地交付）\n"
	for quest in game.quests:
		text += "%s · %s · %d/%d\n%s\n" % [quest.title, "已交付" if game.progress.claims.has("quest." + quest.id) else ("可交付" if quest.is_complete(game.progress) else "进行中"), quest.objective_count(game.progress), quest.required_claims.size() + quest.required_clears.size(), quest.description]
	text += "\n已学组合\n"
	for rule in game.player.skill_manager.combinations.rules:
		if game.progress.spell_rules.has(rule.id):
			var action := game.player.skill_manager.pool.get_skill(rule.trigger_action_id)
			var condition_cost := " + 1次法阵触发" if not rule.required_field_type.is_empty() else (" + 消耗准备状态" if rule.consume_caster_status else "")
			text += "%s + %s → %s · %d MP%s\n%s\n" % [rule.condition_label(), action.display_name, rule.result_skill.display_name, rule.mana_cost, condition_cost, rule.result_skill.description]
	text += "\n当前水路\n"
	match str(game.progress.choices.get("waterworks_choice", "")):
		"cooling": text += "冷却熔炉：新遭遇的领主生命 -25%，火抗降至10%。\n"
		"conduit": text += "魔力导流：进入区域后法力回复由3提高到5 MP/秒。\n"
		_: text += "尚未重启。深入排水回廊的蓄水机房调查。\n"
	text += "\n发现记录\n"
	for note in game.progress.journal:
		text += "\n%s\n%s\n" % [note.title, note.text]
	return text


func inspect_discovery(entry: ExplorationDiscoveryData, node: ExplorationInteractable) -> void:
	if entry.requires_clear and not game.active_enemies.is_empty():
		game.ui.notify("先清除守卫，再靠近这里调查。")
		return
	if game.progress_service.discover(entry):
		node.set_title(entry.title + "（已记录）")
		if entry.id == "cartographer_rescued":
			game.ui.notify("测绘员已沿清理过的道路返回营地。回去交付委托可领取成长奖励。")
		if entry.hide_when_claimed:
			node.queue_free()
	game.ui.show_panel(entry.title, entry.text, [{"title": "记入日志，继续探索", "callback": game.ui.close_modal}])

func inspect_puzzle(spec: SpellPuzzleData, completed: bool) -> void:
	game.ui.show_panel(spec.title, "机关已解开，奖励已保存。" if completed else spec.hint, [{"title": "继续探索", "callback": game.ui.close_modal}])
