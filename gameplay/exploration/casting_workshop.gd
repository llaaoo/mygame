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
	text += "\n为基础动作选择一种可选强化，只对适配的结果消费。相容的法阵和印记可共同响应，总费用相加；资源不足或准备条件改变，整次动作取消。特殊施法的必需材料不能关闭。\n\n按M开关；K可编组雷阵、回响铭印、毒雾等动作。互斥增益按优先级选择一个，同优先级取后布的阵；护盾爆破先于回响脉冲。悬停技能槽查看本次全部结果与总费用。"
	var buttons: Array[Dictionary] = []
	for id in game.player.skill_manager.known_actions:
		var skill: SkillData = game.player.skill_manager.pool.get_skill(id)
		if not skill:
			continue
		var material_id := str(supplies.selected.get(id, ""))
		buttons.append({"title": skill.display_name + " · " + (supplies.title(material_id) if not material_id.is_empty() else "基础"), "callback": show_action.bind(skill)})
	buttons.append({"title": "营地加工", "disabled": game.region_id != "camp", "callback": show_crafts})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("施法材料与配置", text, buttons)

func show_action(skill: SkillData) -> void:
	var controller: FireCombinationController = game.player.skill_manager.combinations
	var supplies := controller.supplies
	var plan := controller.preview(skill, game.player, Input.is_key_pressed(KEY_SHIFT))
	var text := "%s\n%s\n\n当前条件：%s · %d MP\n材料：%s\n" % [skill.display_name, skill.description, plan.effect_label, plan.cost, supplies.describe_cost(plan.material_costs) if not plan.material_costs.is_empty() else "无"]
	text += controller.boon_hint(plan) + "\n普通施法保留适配恩赐；按住Shift施法可消耗恩赐强化这次效果，之后失去其持续收益。\n"
	var buttons: Array[Dictionary] = [{"title": "无可选强化", "callback": _configure.bind(skill, "")}]
	for id in CastingSupplies.MATERIAL_IDS:
		var material: CastingMaterialData = supplies.catalog[id]
		var compatible := material.supports(skill.get_id(), skill.get_id())
		for recipe in controller.recipes:
			if recipe.trigger_action_id == skill.get_id() and controller.learned_recipes.has(recipe.id):
				compatible = compatible or material.supports(skill.get_id(), recipe.result_skill.get_id())
		if compatible:
			text += "\n%s（持有%d）\n%s\n" % [material.title, supplies.count(id), material.description]
			buttons.append({"title": "配置：" + material.title, "callback": _configure.bind(skill, id)})
	buttons.append({"title": "返回材料总览", "callback": show_materials})
	game.ui.show_panel("配置：" + skill.display_name, text, buttons)

func _configure(skill: SkillData, id: String) -> void:
	game.player.skill_manager.combinations.supplies.configure(skill.get_id(), id)
	game._save_progress()
	show_action(skill)

func show_crafts() -> void:
	if game.region_id != "camp":
		return
	var supplies: CastingSupplies = game.player.skill_manager.combinations.supplies
	var text := "使用探索获得的原料加工成品。休息不补满材料，已搜刮的固定来源不会重复发放。基础火、霜法术始终可不带材料使用。\n\n"
	var buttons: Array[Dictionary] = []
	for id in CastingSupplies.CRAFTS:
		var costs: Dictionary = CastingSupplies.CRAFTS[id]
		text += "%s ×1 ← %s\n" % [supplies.title(id), supplies.describe_cost(costs)]
		buttons.append({"title": "加工：" + supplies.title(id), "disabled": not supplies.can_pay(costs), "callback": _craft.bind(id)})
	buttons.append({"title": "材料与配置", "callback": show_materials})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("营地施法工作台", text, buttons)

func _craft(id: String) -> void:
	if game.region_id == "camp" and game.player.skill_manager.combinations.supplies.craft(id):
		game._save_progress()
	show_crafts()
