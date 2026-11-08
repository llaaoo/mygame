class_name CastingWorkshop
extends RefCounted
var game: Node

func _init(owner_game: Node) -> void:
	game = owner_game

func show_materials() -> void:
	var screen:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	screen.get_node("Navigation/Caption").text="释放准备"
	screen.tabs.add_child(FoundationWidgets.button("快捷栏编组",func(): game.ui.close_modal(); game.player.skill_pool_ui.open()))
	screen.tabs.add_child(FoundationWidgets.button("营地加工",show_crafts,not game.is_at_base()))
	screen.tabs.add_child(FoundationWidgets.button("调和台回收",show_recycling,not recycling_available()))
	screen.status.text="选择基础动作 · 查看真实费用与释放来源"
	screen.search.placeholder_text="搜索已学动作…"
	screen.search.text_changed.connect(func(value: String): _source_rows(screen,value))
	game.ui.show_view("材料与释放来源",screen)
	_source_rows(screen,"")

func _source_rows(screen: ExpeditionScreen,query: String) -> void:
	FoundationWidgets.clear(screen.rows)
	var first: SkillData
	for skill: SkillData in game.player.skill_manager.pool.skills:
		if not skill or skill.combination_only or not game.player.skill_manager.knows_action(skill): continue
		if not query.is_empty() and not skill.display_name.contains(query): continue
		if not first: first=skill
		var button:=FoundationWidgets.button(skill.display_name,_source_detail.bind(screen,skill))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.icon=InterfaceIcons.skill(skill); button.expand_icon=true; button.add_theme_constant_override("icon_max_width",22)
		screen.rows.add_child(button)
	if first: _source_detail(screen,first)
	else:
		FoundationWidgets.clear(screen.detail)
		screen.detail.add_child(FoundationWidgets.label("没有符合条件的已学动作。",16,true))

func _source_detail(screen: ExpeditionScreen,skill: SkillData) -> void:
	FoundationWidgets.clear(screen.detail)
	var controller: ConditionalCastController=game.player.skill_manager.combinations
	var source:=QuickslotMaterials.source_for(game.player.skill_manager,skill)
	var plan: CastPlan=game.player.skill_manager.preview_source(source) if not source.is_empty() else controller.preview(skill,game.player)
	var card:=FoundationWidgets.card(screen.detail,skill.display_name,skill.description)
	card.add_child(FoundationWidgets.label("本次 → "+plan.effect_label,18))
	card.add_child(FoundationWidgets.label("%d MP · 准备 %.2f秒"%[plan.cost,plan.preparation],14,true))
	if not plan.material_costs.is_empty(): card.add_child(FoundationWidgets.label(controller.supplies.describe_cost(plan.material_costs),14))
	if not plan.ready: card.add_child(FoundationWidgets.label(plan.reason,14))
	var configure:=FoundationWidgets.button("配置："+skill.display_name,show_action.bind(skill))
	configure.icon=GameUIStyle.icon("chevron-right"); configure.expand_icon=true; configure.add_theme_constant_override("icon_max_width",18)
	screen.detail.add_child(configure)
	FoundationWidgets.disclosure(screen.detail,"来源与消耗规则","选择不扣物资。成功释放才结算真实来源；耗尽或失效会拒绝，不自动换料。K和M共用按槽来源；轮盘确认后再按快捷键施放，改料不会重置冷却。组合条件需亲手准备，额外修饰只作用于一次施法。")

func show_action(skill: SkillData) -> void:
	if game.rules.material_operations and is_instance_valid(game.player.material_wheel):
		var source:=QuickslotMaterials.source_for(game.player.skill_manager,skill,game.player.material_wheel.last_source)
		game.ui.close_modal()
		if source.is_empty():
			game.player.skill_pool_ui.open_for(skill)
			game.ui.notify("先将这个动作绑定快捷槽，再用M选材。")
		else:
			game.player.material_wheel.remember_source(source)
			game.player.material_wheel.open()
		return
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
	var selected:=""
	var query:=""
	if not game.is_at_base(): return
	var supplies: CastingSupplies=game.player.skill_manager.combinations.supplies
	var screen:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	screen.get_node("Navigation/Caption").text="工作台"
	screen.tabs.add_child(FoundationWidgets.label("配方加工",20))
	screen.tabs.add_child(FoundationWidgets.label("探索解锁配方
制造消费真实材料
休息不会补货",13,true))
	screen.search.text=query
	screen.search.placeholder_text="查找配方或原料…"
	var selection:=selected
	if selection.is_empty():
		for id in supplies.crafting_recipes:
			if supplies.knows_recipe(id): selection=id; break
	screen.set_meta("selected_recipe",selection)
	var refresh:=func(value: String): _craft_rows(screen,str(screen.get_meta("selected_recipe","")),value)
	screen.search.text_changed.connect(refresh)
	screen.status.text="%d项配方 · 选择一项查看产出和原料"%supplies.crafting_recipes.size()
	screen.footer.add_child(FoundationWidgets.button("材料与配置",show_materials))
	screen.footer.add_child(FoundationWidgets.button("继续探索",game.ui.close_modal))
	game.ui.show_view("营地工作台",screen)
	_craft_rows(screen,selection,query)

func _craft_rows(screen: ExpeditionScreen, selected: String, query: String) -> void:
	FoundationWidgets.clear(screen.rows)
	var supplies: CastingSupplies=game.player.skill_manager.combinations.supplies
	var recipe_ids:=supplies.crafting_recipes.keys()
	recipe_ids.sort_custom(func(a: String,b: String):
		if supplies.knows_recipe(a)!=supplies.knows_recipe(b): return supplies.knows_recipe(a)
		return supplies.title(supplies.crafting_recipes[a].output_id)<supplies.title(supplies.crafting_recipes[b].output_id))
	for id in recipe_ids:
		var recipe: CraftingRecipe=supplies.crafting_recipes[id]
		if not query.is_empty() and not (supplies.title(recipe.output_id)+supplies.describe_cost(recipe.inputs)).to_lower().contains(query.to_lower()): continue
		var learned:=supplies.knows_recipe(id)
		var button:=FoundationWidgets.button(supplies.title(recipe.output_id)+"
"+("原料齐备" if supplies.can_pay(recipe.inputs) else "缺少原料") if learned else supplies.title(recipe.output_id)+"
尚未学会",_craft_select.bind(screen,id))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text=true
		GameUIStyle.apply_button(button,GameUIStyle.ACCENT,id==selected)
		screen.rows.add_child(button)
	_craft_detail(screen,selected)

func _craft_select(screen: ExpeditionScreen,id: String) -> void:
	screen.set_meta("selected_recipe",id)
	_craft_rows(screen,id,screen.search.text)

func _craft_detail(screen: ExpeditionScreen,id: String) -> void:
	FoundationWidgets.clear(screen.detail)
	var supplies: CastingSupplies=game.player.skill_manager.combinations.supplies
	if not supplies.crafting_recipes.has(id):
		screen.detail.add_child(FoundationWidgets.label("寻找探索记录，学习第一份配方。",16,true))
		return
	var recipe: CraftingRecipe=supplies.crafting_recipes[id]
	var card:=FoundationWidgets.card(screen.detail,supplies.title(recipe.output_id),"产出 ×%d · 持有 %d"%[recipe.output_count,supplies.count(recipe.output_id)])
	var definition:=ItemCatalog.default_catalog().definition(recipe.output_id)
	if definition: card.add_child(FoundationWidgets.label(definition.description,14))
	card.add_child(HSeparator.new())
	card.add_child(FoundationWidgets.label("所需原料",15))
	for material in recipe.inputs:
		var count:=supplies.count(material)
		var line:=FoundationWidgets.label("%s    %d / %d"%[supplies.title(material),count,recipe.inputs[material]],14)
		if count<int(recipe.inputs[material]): line.add_theme_color_override("font_color",GameUIStyle.GOLD)
		card.add_child(line)
	if not supplies.knows_recipe(id): card.add_child(FoundationWidgets.label("尚未学会 · 探索记录可解锁",14,true))
	var action:=FoundationWidgets.button("加工："+supplies.title(recipe.output_id),_craft_selected.bind(screen,id),not supplies.knows_recipe(id) or not supplies.can_pay(recipe.inputs))
	action.icon=GameUIStyle.icon("anvil"); action.expand_icon=true; action.add_theme_constant_override("icon_max_width",20)
	screen.detail.add_child(action)
	if supplies.inventory_store:
		var pocket:=supplies.inventory_store.count(supplies.actor_id,recipe.output_id,false,true)
		card.add_child(FoundationWidgets.label("当前口袋%d / 背包%d；战斗施法只使用口袋材料。"%[pocket,supplies.count(recipe.output_id)-pocket],14,true))
		if supplies.count(recipe.output_id)>0: screen.detail.add_child(FoundationWidgets.button("整理："+supplies.title(recipe.output_id),_prepare_output.bind(recipe.output_id)))

func _prepare_output(id: String) -> void:
	game.ui.close_modal()
	game.inventory_screen.open_item(id)

func _craft_selected(screen: ExpeditionScreen,id: String) -> void:
	# Same domain transaction as keyboard interaction; the view only refreshes its snapshot.
	var supplies: CastingSupplies=game.player.skill_manager.combinations.supplies
	var recipe:=supplies.crafting_recipes.get(id) as CraftingRecipe
	var message:="未完成：请检查工作台范围、配方、原料及产出空间。"
	if game.is_at_base() and recipe and supplies.craft(id):
		game._save_progress()
		var pocket:=supplies.inventory_store.count(supplies.actor_id,recipe.output_id,false,true) if supplies.inventory_store else supplies.count(recipe.output_id)
		message="制成%s ×%d · 当前口袋%d / 背包%d"%[supplies.title(recipe.output_id),recipe.output_count,pocket,supplies.count(recipe.output_id)-pocket]
		if pocket==0: message+=" · 先点整理，移入口袋后才能用于战斗。"
	game.ui.notify(message)
	screen.status.text=message
	_craft_rows(screen,id,screen.search.text)

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
	var screen:=preload("res://gameplay/foundation/ui/expedition_screen.tscn").instantiate() as ExpeditionScreen
	screen.get_node("Navigation/Caption").text="来源选择"
	screen.tabs.add_child(FoundationWidgets.label(skill.display_name,20))
	screen.tabs.add_child(FoundationWidgets.button("返回材料总览",show_materials))
	screen.status.text="选择后保留 · 不自动换料 · 成功释放才消费"
	screen.search.placeholder_text="查找介质…"
	var selected:=str(supplies.selected.get(skill.get_id(),operation.default_payload))
	var refresh:=func(query: String):
		FoundationWidgets.clear(screen.rows)
		for payload in operation.payloads:
			if not query.is_empty() and not payload.title.contains(query): continue
			var current:=selected==payload.id
			var button:=FoundationWidgets.button(("✓ 当前：" if current else "选择：")+payload.title,_select_payload.bind(skill,payload.id),not manager.knows_action(skill))
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.clip_text=true
			GameUIStyle.apply_button(button,GameUIStyle.ACCENT,current)
			screen.rows.add_child(button)
	screen.search.text_changed.connect(refresh)
	var payload:=operation.payload(selected)
	var plan:=manager.combinations.preview(skill,game.player)
	var card:=FoundationWidgets.card(screen.detail,payload.title if payload else "未装填",skill.description)
	card.add_child(FoundationWidgets.label("%d MP · 准备 %.2f秒"%[plan.cost,plan.preparation],16))
	if payload:
		card.add_child(FoundationWidgets.label(payload.describe(game.rules.timed_fields),14))
		var cost:="无需材料" if payload.material_id.is_empty() else supplies.describe_cost({payload.material_id:payload.quantity})
		if payload.source_kind=="field": cost="脚下"+FireSigil.title_for(payload.source_field)+" · 消耗1次实际充能"
		if payload.source_kind=="soul": cost="附近真实残魂 · 消耗1个"
		if skill.operation_id=="disperse": cost="每0.5秒：2 MP＋该瓶1剂；每瓶3剂"
		card.add_child(FoundationWidgets.label(cost,14,true))
	if not plan.ready: card.add_child(FoundationWidgets.label(plan.reason,14))
	for material: CastingMaterialData in supplies.catalog.values():
		if not material.supports(skill.get_id(),plan.skill.get_id(),plan.skill): continue
		var current:=str(supplies.modifiers.get(skill.get_id(),""))==material.id
		screen.detail.add_child(FoundationWidgets.button(("✓ 本次修饰：" if current else "本次修饰：")+material.title,_select_modifier.bind(skill,material.id)))
	if supplies.modifiers.has(skill.get_id()): screen.detail.add_child(FoundationWidgets.button("清除本次修饰",_select_modifier.bind(skill,"")))
	FoundationWidgets.disclosure(screen.detail,"操作与实物规则","介质选定后保留，离区、死亡或读档清除。物资不足不会自动换料。喷洒需先制造喷剂；按住所编组键持续释放，松开即停。K固定来源的快捷槽不受M影响。")
	game.ui.show_view("释放介质："+skill.display_name,screen)
	refresh.call("")

func _select_payload(skill: SkillData,id: String) -> void:
	var manager: SkillManager=game.player.skill_manager
	manager.combinations.supplies.select_payload(skill,id,manager)
	show_payloads(skill)

func _select_modifier(skill: SkillData,id: String) -> void:
	game.player.skill_manager.combinations.supplies.configure_modifier(skill,id)
	show_payloads(skill)
