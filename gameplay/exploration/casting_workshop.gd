class_name CastingWorkshop
extends RefCounted
var game: Node

func _init(owner_game: Node) -> void:
	game = owner_game

func show_materials() -> void:
	var supplies: CastingSupplies = game.player.skill_manager.combinations.supplies
	var text := "施法材料\n"
	for id in supplies.crafting_recipes:
		text += "%s ×%d\n" % [supplies.title(id), supplies.count(id)]
	text += "\n原料\n"
	for id in CastingSupplies.RAW_TITLES:
		text += "%s ×%d\n" % [supplies.title(id), supplies.count(id)]
	text += "\n释放介质选定后可重复使用，每次手动施放都消耗实物，耗尽不自动换料。额外改造素材只作用于本次施法，成功后清除；中断不扣料，不适配则不消费。离区、死亡和读档清除选择。相容的法阵和印记可共同响应，总费用相加；资源不足或准备条件改变，整次动作取消。特殊施法的必需材料不能关闭。\n\n按M开关；K可编组铭刻法阵、喷洒介质、震荡、凝神等基础动作。互斥增益按优先级选择一个，同优先级取后布的阵；护盾爆破先于回响脉冲。悬停技能槽查看本次全部结果与总费用。"
	var buttons: Array[Dictionary] = []
	for skill: SkillData in game.player.skill_manager.pool.skills:
		if not skill or skill.combination_only or not game.player.skill_manager.knows_action(skill): continue
		var id:=skill.get_id()
		var material_id:=str(supplies.selected.get(id,""))
		var label:=supplies.title(material_id) if not material_id.is_empty() else "基础"
		if not skill.operation_id.is_empty():
			var operation:=SpellOperationCatalog.default_catalog().operation(skill.operation_id)
			var payload:=operation.payload(str(supplies.selected.get(id,operation.default_payload)))
			label=payload.title if payload else "未装填"
		buttons.append({"title":skill.display_name+" · "+label,"callback":show_action.bind(skill)})
	buttons.append({"title": "营地加工", "disabled": not game.is_at_base(), "callback": show_crafts})
	buttons.append({"title": "调和台回收" + ("" if recycling_available() else "（需营地修复）"), "disabled": not recycling_available(), "callback": show_recycling})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("施法材料与本次选择", text, buttons)

func show_action(skill: SkillData) -> void:
	if not skill.operation_id.is_empty():
		show_payloads(skill)
		return
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
	var text := "使用探索获得的原料加工成品。休息不补满材料，已搜刮的固定来源不会重复发放。凝能阵无需材料；元素法阵与喷洒按选定介质消费实物。\n\n"
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
	for id in supplies.crafting_recipes:
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

func show_payloads(skill: SkillData) -> void:
	var manager: SkillManager=game.player.skill_manager
	var supplies:=manager.combinations.supplies
	var operation:=SpellOperationCatalog.default_catalog().operation(skill.operation_id)
	var plan:=manager.combinations.preview(skill,game.player)
	var text:=skill.description+"\n\n本次："+plan.effect_label+"\n%d MP · 准备%.2f秒\n"%[plan.cost,plan.preparation]+("可释放" if plan.ready else plan.reason)+"\n"
	var buttons: Array[Dictionary]=[]
	for payload in operation.payloads:
		var unlocked:=manager.knows_action(skill)
		var cost:="无需材料" if payload.material_id.is_empty() else supplies.describe_cost({payload.material_id:payload.quantity})
		if payload.source_kind=="field": cost="消耗脚下"+FireSigil.title_for(payload.source_field)+"的1次实际充能"
		if payload.source_kind=="soul": cost="消耗附近的1个真实残魂"
		if skill.operation_id=="disperse": cost="每0.5秒：2 MP＋该瓶1剂；每瓶3剂"
		if supplies.inventory_store and not payload.material_id.is_empty(): cost+=" · 口袋%d"%supplies.inventory_store.count(supplies.actor_id,payload.material_id,false,true)
		text+="\n"+payload.title+("（尚未学会）" if not unlocked else "")+"\n"+cost+(" · 额外%d MP"%payload.extra_mana if payload.extra_mana>0 else "")+"\n"+payload.describe()+"\n"
		var current:=str(supplies.selected.get(skill.get_id(),operation.default_payload))==payload.id
		buttons.append({"title":("✓ 当前：" if current else "选择：")+payload.title,"disabled":not unlocked,"focused":current,"callback":_select_payload.bind(skill,payload.id)})
	for material: CastingMaterialData in supplies.catalog.values():
		if not material.supports(skill.get_id(),plan.skill.get_id(),plan.skill): continue
		var current:=str(supplies.modifiers.get(skill.get_id(),""))==material.id
		buttons.append({"title":("✓ 本次修饰：" if current else "本次修饰：")+material.title,"callback":_select_modifier.bind(skill,material.id)})
	if supplies.modifiers.has(skill.get_id()): buttons.append({"title":"清除本次修饰","callback":_select_modifier.bind(skill,"")})
	text+="\n每次手动施放成功才消耗口袋实物；选定介质会保留，方便连续施放。离区/死亡/读档清除选择。物资不足不会自动换成别的介质。N可在安全时整理物资。喷剂需先制造：清水喷剂使用制造时装入的水，不会直接吸走水囊；按住技能键喷洒，松开即停。毒地可以被清洗或点燃。"
	buttons.append({"title":"返回材料总览","callback":show_materials})
	game.ui.show_panel("释放介质："+skill.display_name,text,buttons)

func _select_payload(skill: SkillData,id: String) -> void:
	var manager: SkillManager=game.player.skill_manager
	manager.combinations.supplies.select_payload(skill,id,manager)
	show_payloads(skill)

func _select_modifier(skill: SkillData,id: String) -> void:
	game.player.skill_manager.combinations.supplies.configure_modifier(skill,id)
	show_payloads(skill)
