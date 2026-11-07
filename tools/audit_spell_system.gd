extends SceneTree
## Generates an inventory from registered live content, without granting game state.
var report: Dictionary={"actions":[],"operations":[],"rules":[],"materials":[],"items":[],"recipes":[],"statuses":{},"effects":{},"surfaces":[],"material_roles":[],"survival_recipes":SurvivalCatalog.RECIPES,"food_effects":SurvivalCatalog.FOODS,"surface_reactions":[],"hit_reactions":[]}
var seen: Dictionary={}
func _init() -> void: call_deferred("run")
func _walk(value: Variant,origin: String) -> void:
	if value is String and value.begins_with("res://") and value.ends_with(".tres") and ResourceLoader.exists(value):
		_walk(load(value),origin); return
	if value is Array or value is PackedStringArray:
		for item in value: _walk(item,origin)
		return
	if value is Dictionary:
		for item in value.values(): _walk(item,origin)
		return
	if not value is Resource or value is Script or value is Texture2D: return
	if seen.has(value.get_instance_id()): return
	seen[value.get_instance_id()]=true
	var path: String=value.resource_path
	if value is Buff:
		var id: String=value.status_id
		if id.is_empty(): id=value.buff_id
		if not id.is_empty():
			if not report.statuses.has(id): report.statuses[id]=[]
			report.statuses[id].append({"title":value.display_name,"path":path,"origin":origin,"duration":value.duration,"max_stacks":value.max_stacks,"exclusive_group":value.exclusive_group,"tick_damage":value.tick_damage,"tick_heal":value.tick_heal,"prevents_actions":value.prevents_actions,"empower":value.can_empower,"hint":value.tactical_hint,"description":value.describe(),"stat_modifiers":value.stat_modifiers,"stat_multipliers":value.stat_multipliers,"speed_multiplier":value.speed_multiplier,"damage_taken_multiplier":value.damage_taken_multiplier,"projectile_damage_multiplier":value.incoming_projectile_multiplier,"spell_damage_multiplier":value.spell_damage_multiplier,"empower_damage_multiplier":value.empower_damage_multiplier,"empower_mana_cost":value.empower_mana_cost,"cleanse":value.cleanse_statuses,"immunities":value.status_immunities})
	if value is SkillData:
		report.effects[value.get_id()]={"title":value.display_name,"path":path,"origin":origin,"type":SkillData.SkillType.keys()[value.skill_type],"base_mana":value.mp_cost,"damage":value.damage,"tags":value.tags,"field":value.field_type,"surface":value.creates_surface,"cast_type":value.cast_type,"cooldown":value.cooldown}
	for property in value.get_property_list():
		if property.name in ["script","resource_path","resource_name","resource_local_to_scene"] or not int(property.usage)&PROPERTY_USAGE_STORAGE: continue
		var child: Variant=value.get(property.name)
		if child is Resource or child is Array or child is PackedStringArray or child is Dictionary or child is String: _walk(child,origin+" → "+path.get_file())
func cell(value: Variant) -> String:
	return str(value).replace("|","/").replace("\n"," ")
func run() -> void:
	var catalog:=ExplorationContentCatalog.new(GrayriverDefinition.build())
	var operations:=SpellOperationCatalog.default_catalog()
	var actions: Dictionary={}
	for action: SkillData in catalog.actions.values():
		var id:=operations.canonical(action.get_id())
		if id==action.get_id(): actions[id]=action
	for operation in operations.operations: actions[operation.action.get_id()]=operation.action
	for id in actions:
		var action: SkillData=actions[id]
		report.actions.append({"id":id,"title":action.display_name,"type":SkillData.SkillType.keys()[action.skill_type],"cast_type":action.cast_type,"base_mana":action.mp_cost,"cooldown":action.cooldown,"preparation":action.preparation,"channel_rate":action.channel_mp_per_sec,"channel_interval":action.channel_tick_interval})
		_walk(action,"current_action")
	for operation in operations.operations:
		var row: Dictionary={"id":operation.action.get_id(),"operation":operation.action.operation_id,"title":operation.action.display_name,"aliases":Array(operation.aliases),"payloads":[]}
		for payload in operation.payloads:
			row.payloads.append({"id":payload.id,"title":payload.title,"material":payload.material_id,"quantity":payload.quantity if not payload.material_id.is_empty() else 0,"source_kind":payload.source_kind,"source_field":payload.source_field,"base_mana":operation.action.mp_cost+payload.extra_mana,"damage":payload.damage,"surface":payload.surface,"field":payload.field_type,"channel_rate":operation.action.channel_mp_per_sec,"channel_interval":operation.action.channel_tick_interval,"effect":payload.effect.get_id() if payload.effect else "","description":payload.describe()})
			_walk(operation.compose(payload),"composed_payload:"+operation.action.get_id()+"/"+payload.id)
		report.operations.append(row)
	var rules: Dictionary=catalog.spell_rules.duplicate()
	for rule in operations.rules: rules[rule.id]=rule
	for rule: SpellCombinationRule in rules.values():
		report.rules.append({"id":rule.id,"action":rule.trigger_action_id,"condition":rule.condition_label(),"result":rule.result_skill.get_id(),"result_title":rule.result_skill.display_name,"mana":rule.mana_cost,"priority":rule.priority,"status":rule.required_caster_status,"consume_status":rule.consume_caster_status,"stacks":rule.consume_stacks,"field":rule.required_field_type,"surface":rule.required_surface,"empower":rule.requires_empower})
		_walk(rule,"combination_rule:"+rule.id)
	var supplies:=CastingSupplies.new()
	for material: CastingMaterialData in supplies.catalog.values():
		report.materials.append({"id":material.id,"title":material.title,"extra_mana":material.extra_mana,"description":material.description})
	for recipe: CraftingRecipe in supplies.crafting_recipes.values():
		report.recipes.append({"id":recipe.id,"inputs":recipe.inputs,"output":recipe.output_id,"quantity":recipe.output_count})
	for item in ItemCatalog.default_catalog().items:
		if item.use_profile:
			report.items.append({"id":item.id,"title":item.display_name,"kind":ItemUseDefinition.Kind.keys()[item.use_profile.kind],"seconds":item.use_profile.duration,"stamina":item.use_profile.stamina,"capacity":item.use_profile.capacity,"reach":item.use_profile.reach})
			_walk(item.use_profile,"item_use:"+item.id)
	for element in ElementCatalog.all_definitions()+ElementCatalog.all_aspects(): _walk(element,"element:"+element.id)
	for state in SurfaceCatalog.STATE_IDS:
		var surface:=SurfaceCatalog.definition(state)
		report.surfaces.append({"id":state,"title":surface.title})
		_walk(surface,"surface:"+state)
	for reaction in SurfaceCatalog.all_reactions():
		var values: Dictionary={}
		for property in reaction.get_property_list():
			if property.name in ["rule_id","required_state","required_tags","result_state","result_duration","spread_to_neighbors","spread_tags","spread_damage","entity_status_path"]: values[property.name]=reaction.get(property.name)
		report.surface_reactions.append(values)
	for reaction in ElementReactionCatalog.all_rules():
		report.hit_reactions.append({"id":reaction.id,"title":reaction.display_name,"description":reaction.description,"tags":reaction.required_hit_tags,"target_status":reaction.required_target_status,"caster_status":reaction.required_caster_status,"bonus_damage_ratio":reaction.bonus_damage_ratio,"consume_target_status":reaction.consume_target_status,"triggered_skill":reaction.triggered_skill_id})
		_walk(reaction,"hit_reaction:"+reaction.id)
	var roles: Dictionary={}
	for row in report.materials: roles[row.id]={"id":row.id,"title":row.title,"modifier":true,"primary_for":[],"recipe_inputs":[],"made_by":[]}
	for operation in report.operations:
		for payload in operation.payloads:
			if payload.material.is_empty(): continue
			if not roles.has(payload.material): roles[payload.material]={"id":payload.material,"title":supplies.title(payload.material),"modifier":false,"primary_for":[],"recipe_inputs":[],"made_by":[]}
			roles[payload.material].primary_for.append(operation.title+"/"+payload.title)
	for recipe in report.recipes:
		var ingredients: Array=recipe.inputs.keys(); ingredients.append(recipe.output)
		for id: String in ingredients:
			if not roles.has(id): roles[id]={"id":id,"title":supplies.title(id),"modifier":false,"primary_for":[],"recipe_inputs":[],"made_by":[]}
			if id==recipe.output: roles[id].made_by.append(recipe.id)
			else: roles[id].recipe_inputs.append(recipe.id)
	report.material_roles.assign(roles.values())
	report["counts"]={"actions":report.actions.size(),"operations":report.operations.size(),"payloads":0,"rules":report.rules.size(),"modifier_materials":report.materials.size(),"usable_item_definitions":report.items.size(),"manufacturing_recipes":report.recipes.size(),"status_ids":report.statuses.size(),"effect_definitions":report.effects.size(),"surfaces":report.surfaces.size(),"surface_reactions":report.surface_reactions.size(),"hit_reactions":report.hit_reactions.size(),"material_item_ids":report.material_roles.size(),"survival_recipes":SurvivalCatalog.RECIPES.size(),"food_effects":SurvivalCatalog.FOODS.size()}
	for row in report.operations: report.counts.payloads+=row.payloads.size()
	var output:=OS.get_environment("SPELL_REVIEW_OUTPUT")
	if output.is_empty(): output="/tmp/grayriver-spell-inventory"
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output.path_join("spell_inventory.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	var md:="# 当前施法资源清单\n\n由 `tools/audit_spell_system.gd` 从灰河谷登记动作、操作目录、组合规则、物品用途、元素与地面定义生成。数值为定义基础值，不含属性、疲劳、装备和恩赐修正；材料描述中的制造配方不等于法术组合。完整字段见 [JSON](spell_inventory.json)。历史升级分支的被动触发不代表当前动作可装备。effect_definitions包含49个临时组合变体及其引用的旧结果/升级定义，不是独立技能数量；statuses统计由Resource与显式路径引用到的Buff定义；武器涂层、生存食品计时和地面状态另列，不混算。\n\n## 基础动作\n\n| ID | 动作 | 输入形态 | 基础MP | 冷却 | 准备 |\n|---|---|---|---|---|---|\n"
	for row in report.actions: md+="| %s | %s | %s | %s | %s | %s |\n"%[row.id,cell(row.title),row.cast_type,cell(str(row.base_mana) if row.cast_type!="channel" else str(row.channel_rate)+"MP/秒，"+str(row.channel_interval)+"秒结算"),row.cooldown,row.preparation]
	md+="\n## 动作与介质\n\n| 动作 | 介质/样式 | 实物 | 现场来源 | 基础总MP | 结果 |\n|---|---|---|---|---|---|\n"
	for operation in report.operations:
		for row in operation.payloads: md+="| %s | %s `%s` | %s | %s | %s | %s |\n"%[cell(operation.title),cell(row.title),row.id,row.material+" ×"+str(row.quantity) if not row.material.is_empty() else "无",row.source_kind+":"+row.source_field if not row.source_kind.is_empty() else "无",cell(str(row.base_mana) if operation.id!="sustain" else str(row.base_mana)+" + "+str(row.channel_rate)+"MP/秒"),cell(row.effect if not row.effect.is_empty() else row.field+" "+row.surface)]
	md+="\n## 条件组合\n\n| ID | 动作 | 条件 | 结果 | 基础MP |\n|---|---|---|---|---|\n"
	for row in report.rules: md+="| %s | %s | %s | %s | %s |\n"%[row.id,row.action,cell(row.condition),cell(row.result_title),row.mana]
	md+="\n## 单次修饰材料\n\n| ID | 名称 | 额外MP | 作用 |\n|---|---|---|---|\n"
	for row in report.materials: md+="| %s | %s | %s | %s |\n"%[row.id,cell(row.title),row.extra_mana,cell(row.description)]
	md+="\n## 物品动作\n\n| ID | 名称 | 类型 | 准备秒 | 体力 | 容量 | 投送距离 |\n|---|---|---|---|---|---|---|\n"
	for row in report.items: md+="| %s | %s | %s | %s | %s | %s | %s |\n"%[row.id,cell(row.title),row.kind,row.seconds,row.stamina,row.capacity,row.reach]
	md+="\n## Buff与状态\n\n同ID可有不同来源定义/运行变体，下表逐项展示，不能当作可叠加状态数量。临时能量同属一个互斥组；食物计时与具体武器涂层另由生存/物品服务管理。\n\n| ID | 名称 | 时长 | 层数 | 互斥组 | 周期伤/治疗 | 控制 | 可兑现 | 效果 |\n|---|---|---|---|---|---|---|---|---|\n"
	for id in report.statuses:
		var variants: Dictionary={}
		for row in report.statuses[id]:
			var line:="| %s | %s | %s | %s | %s | %s / %s | %s | %s | %s |\n"%[id,cell(row.title),row.duration,row.max_stacks,row.exclusive_group,row.tick_damage,row.tick_heal,row.prevents_actions,row.empower,cell(row.description)]
			if not variants.has(line): md+=line; variants[line]=true
	md+="\n## 命中反应\n\n| ID | 名称 | 条件与效果 |\n|---|---|---|\n"
	for row in report.hit_reactions: md+="| %s | %s | %s |\n"%[row.id,cell(row.title),cell(row.description)]
	md+="\n## 地面反应\n\n| 原状态 | 命中标签 | 新状态 | 持续秒 |\n|---|---|---|---|\n"
	for row in report.surface_reactions: md+="| %s | %s | %s | %s |\n"%[row.required_state,cell(row.required_tags),row.result_state,row.result_duration]
	md+="\n## 材料职责与制造联动\n\n| ID | 名称 | 可作修饰 | 主介质用途 | 制造投入 | 制造产出 |\n|---|---|---|---|---|---|\n"
	for row in report.material_roles: md+="| %s | %s | %s | %s | %s | %s |\n"%[row.id,cell(row.title),row.modifier,cell(row.primary_for),cell(row.recipe_inputs),cell(row.made_by)]
	md+="\n## 制造配方\n\n| 产物 | 数量 | 原料 |\n|---|---|---|\n"
	for row in report.recipes: md+="| %s | %s | %s |\n"%[row.output,row.quantity,cell(row.inputs)]
	file=FileAccess.open(output.path_join("SPELL_INVENTORY.md"),FileAccess.WRITE); file.store_string(md); file.close()
	print("Spell inventory: ",JSON.stringify(report.counts))
	quit()
