class_name CastingWorkshop
extends RefCounted
var game: Node

func _init(owner_game: Node) -> void:
	game = owner_game

func show_materials() -> void:
	var supplies: CastingSupplies = game.player.skill_manager.combinations.supplies
	var text := "施法材料\n"
	for id in CastingSupplies.MATERIAL_IDS:
		text += "%s ×%d\n" % [supplies.title(id), supplies.count(id)]
	text += "\n原料\n"
	for id in CastingSupplies.RAW_TITLES:
		text += "%s ×%d\n" % [supplies.title(id), supplies.count(id)]
	text += "\n为本次基础动作选择一种素材：实际使用成功后清除；中断不扣料并保留选择，不适配则不消费。离区、死亡和读档清除选择。相容的法阵和印记可共同响应，总费用相加；资源不足或准备条件改变，整次动作取消。特殊施法的必需材料不能关闭。\n\n按M开关；K可编组雷阵、回响铭印、毒雾等动作。互斥增益按优先级选择一个，同优先级取后布的阵；护盾爆破先于回响脉冲。悬停技能槽查看本次全部结果与总费用。"
	var buttons: Array[Dictionary] = []
	for id in game.player.skill_manager.known_actions:
		var skill: SkillData = game.player.skill_manager.pool.get_skill(id)
		if not skill:
			continue
		var material_id := str(supplies.selected.get(id, ""))
		buttons.append({"title": skill.display_name + " · " + (supplies.title(material_id) if not material_id.is_empty() else "基础"), "callback": show_action.bind(skill)})
	buttons.append({"title": "营地加工", "disabled": not game.is_at_base(), "callback": show_crafts})
	buttons.append({"title": "调和台回收" + ("" if recycling_available() else "（需营地修复）"), "disabled": not recycling_available(), "callback": show_recycling})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("施法材料与本次选择", text, buttons)

func show_action(skill: SkillData) -> void:
	var controller: ConditionalCastController = game.player.skill_manager.combinations
	var supplies := controller.supplies
	var text := "%s\n%s\n\n%s\n\n" % [skill.display_name, skill.description, controller.describe_comparison(skill, game.player)]
	text += "材料先改变性质，再处理恩赐和装备借阵。污染水不能洗毒，导电会波及自身。节律护手使Shift部分消费恩赐，保留剩余时长50%，使用较弱伤害倍率。\n"
	var buttons: Array[Dictionary] = [{"title": "本次不加素材", "callback": _configure.bind(skill, "")}]
	for id in CastingSupplies.MATERIAL_IDS:
		var material: CastingMaterialData = supplies.catalog[id]
		var preparation_hint := ""
		var compatible := material.supports(skill.get_id(), skill.get_id(), skill)
		for rule in controller.rules:
			if rule.trigger_action_id == skill.get_id() and controller.learned_rules.has(rule.id):
				compatible = compatible or rule.substitute_material == id or material.supports(skill.get_id(), rule.result_skill.get_id(), rule.result_skill)
				if rule.substitute_material == id:
					preparation_hint = "Shift凝神：替代地面准备" + rule.result_skill.display_name + "，额外%d MP；只作为介质，不附加投射物改造。" % material.extra_mana
		if compatible:
			text += "\n%s（持有%d）\n%s\n" % [material.title, supplies.count(id), material.description + ("\n" + preparation_hint if not preparation_hint.is_empty() else "")]
			buttons.append({"title": "本次选择：" + material.title, "callback": _configure.bind(skill, id)})
	buttons.append({"title": "返回材料总览", "callback": show_materials})
	game.ui.show_panel("本次选择：" + skill.display_name, text, buttons)

func _configure(skill: SkillData, id: String) -> void:
	game.player.skill_manager.combinations.supplies.configure(skill.get_id(), id)
	game._save_progress()
	show_action(skill)

func show_crafts() -> void:
	if not game.is_at_base():
		return
	var supplies: CastingSupplies = game.player.skill_manager.combinations.supplies
	var text := "使用探索获得的原料加工成品。休息不补满材料，已搜刮的固定来源不会重复发放。基础火、霜法术始终可不带材料使用。\n\n"
	var buttons: Array[Dictionary] = []
	for id in supplies.crafting_recipes:
		var costs: Dictionary = supplies.crafting_recipes[id].inputs
		text += "%s%s ×1 ← %s\n" % [supplies.title(id), "（尚未学习，探索记录可解锁）" if not supplies.knows_recipe(id) else "", supplies.describe_cost(costs)]
		buttons.append({"title": "加工：" + supplies.title(id), "disabled": not supplies.knows_recipe(id) or not supplies.can_pay(costs), "callback": _craft.bind(id)})
	buttons.append({"title": "材料与配置", "callback": show_materials})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("营地施法工作台", text, buttons)

func _craft(id: String) -> void:
	if game.is_at_base() and game.player.skill_manager.combinations.supplies.craft(id):
		game._save_progress()
	show_crafts()

func recycling_available() -> bool:
	return game.is_at_base() and not game._switching and not game.player.health_component.is_dead and game.progress.claims.has(AlchemyRepairService.REPAIRED)

func recycle(id: String) -> bool:
	if not recycling_available(): return false
	if not game.player.skill_manager.combinations.supplies.recycle(id): return false
	game._save_progress()
	return true

func show_recycling() -> void:
	if not recycling_available(): return
	var supplies: CastingSupplies = game.player.skill_manager.combinations.supplies
	var text := "消耗两批成品，返还一批原制造配方投入。每次只处理一份，不递归拆解、不补满材料；精炼灰等中间成品原样返还。\n\n"
	var buttons: Array[Dictionary] = []
	for id in CastingSupplies.MATERIAL_IDS:
		var preview := supplies.recycle_preview(id)
		if preview.is_empty(): continue
		text += "消耗：%s\n返还：%s\n\n" % [supplies.describe_cost(preview.costs), supplies.describe_cost(preview.returns)]
		buttons.append({"title": "回收一份：" + supplies.title(id), "disabled": not supplies.can_pay(preview.costs), "callback": _recycle.bind(id)})
	buttons.append({"title": "材料与配置", "callback": show_materials})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("调和台 · 材料回收", text, buttons)

func _recycle(id: String) -> void:
	if not recycle(id): game.ui.notify("回收条件已变化，未扣除材料。")
	show_recycling()
