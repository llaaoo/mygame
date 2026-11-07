extends SceneTree
## Resource census, not proof that a player has exercised every reachable definition.
func _init() -> void: call_deferred("run")
func keys(values: Dictionary) -> Array:
	var result:=values.keys(); result.sort(); return result
func add_source(target: Dictionary,id: String,source: String) -> void:
	if not target.has(id): target[id]=[]
	if source not in target[id]: target[id].append(source)
func collect_skills(folder: String,definitions: Dictionary) -> void:
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with(".tres"): continue
		var skill:=load(folder.path_join(name)) as SkillData
		if skill: definitions[skill.get_id()]=skill.resource_path
	for child in DirAccess.get_directories_at(folder): collect_skills(folder.path_join(child),definitions)
func run() -> void:
	var chapter:=GrayriverDefinition.build()
	var operations:=SpellOperationCatalog.default_catalog()
	var supplies:=CastingSupplies.new()
	var player_sources: Dictionary={"ignite":["starter"]}
	var rule_sources: Dictionary={}
	var npc_sources: Dictionary={}
	var recipe_sources: Dictionary={}
	var gear_sources: Dictionary={}
	var current_gear: Dictionary={}
	for region in chapter.regions:
		for note in region.discoveries:
			for id in note.actions: add_source(player_sources,operations.canonical(id),note.id)
			for id in note.spell_rules: add_source(rule_sources,id,note.id)
			for id in note.get_meta("crafting_recipes",[]): add_source(recipe_sources,id,note.id)
			for id in note.equipment: add_source(gear_sources,id,note.id)
		for encounter in region.encounters:
			if not encounter.character: continue
			for skill in encounter.character.skills: add_source(npc_sources,skill.get_id(),encounter.character.id)
			for item in encounter.character.equipment: add_source(gear_sources,item.id,encounter.character.id)
	var published: Dictionary=player_sources.duplicate(true)
	for id in npc_sources:
		for source in npc_sources[id]: add_source(published,id,source)
	var results: Dictionary={}
	var payload_results: Dictionary={}
	for operation in operations.operations:
		if not player_sources.has(operation.action.get_id()): continue
		for payload in operation.payloads:
			if payload.effect:
				add_source(published,payload.effect.get_id(),operation.action.get_id()+"."+payload.id)
				add_source(payload_results,payload.effect.get_id(),operation.action.get_id()+"."+payload.id)
	for rule in chapter.spell_rules:
		if rule_sources.has(rule.id): results[rule.result_skill.get_id()]=rule.id; published[rule.result_skill.get_id()]=[rule.id]
	for rule in operations.rules:
		results[rule.result_skill.get_id()]=rule.id; published[rule.result_skill.get_id()]=[rule.id]
	var pool:=load("res://gameplay/abilities/registry/player_skill_pool.tres") as SkillPool
	var definitions: Dictionary={}
	for skill in pool.skills: definitions[skill.get_id()]=skill.resource_path
	for skill in chapter.actions: definitions[skill.get_id()]=skill.resource_path
	var authored: Dictionary={}
	collect_skills("res://gameplay/abilities/data",authored)
	collect_skills("res://content/spell_operations",authored)
	var authored_without_source: Array[String]=[]
	for id in authored:
		if not published.has(id) and not player_sources.has(operations.canonical(id)): authored_without_source.append(id)
	authored_without_source.sort()
	var without_source: Array[String]=[]
	for id in definitions:
		if not published.has(id) and not player_sources.has(operations.canonical(id)): without_source.append(id)
	without_source.sort()
	for item in ItemCatalog.default_catalog().equipment(): current_gear[item.id]=item.resource_path
	var legacy_gear: Dictionary={}
	for item in EquipmentCatalog.get_all(): legacy_gear[item.id]=item.resource_path
	var missing_recipes: Array[String]=[]
	for id in supplies.crafting_recipes:
		if not recipe_sources.has(id): missing_recipes.append(id)
	missing_recipes.sort()
	var report:={"kind":"authored_resource_sources","scope":"Grayriver definitions; not a runtime coverage or dead-code proof","regions":chapter.regions.size(),"quests":chapter.quests.size(),"player_actions_with_world_sources":player_sources,"npc_actions_with_sources":npc_sources,"conditional_results_with_sources":results,"operation_payload_effects_with_sources":payload_results,"known_pool_definition_count":definitions.size(),"pool_entries_without_direct_current_source":without_source,"all_authored_skill_definition_count":authored.size(),"authored_skills_without_direct_current_source":authored_without_source,"legacy_room_skill_rewards":RunManager.SKILL_REWARD_IDS,"legacy_coverage":JSON.parse_string(FileAccess.get_file_as_string("res://content/spell_operations/legacy_coverage.json")),"note":"Entries without direct sources may belong to legacy room rewards, skill trees, dynamic elemental knowledge or tools; do not delete from this list alone.","current_equipment":keys(current_gear),"legacy_equipment":keys(legacy_gear),"equipment_world_sources":gear_sources,"crafting_recipe_count":supplies.crafting_recipes.size(),"crafting_recipe_world_sources":recipe_sources,"recipes_without_note_source":missing_recipes}
	var path:="res://docs/validation/project_content_usage.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): path=arg.trim_prefix("--output=")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not file: push_error("Cannot write resource audit"); quit(1); return
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("Content source census: ",player_sources.size()," player actions, ",results.size()," results, ",current_gear.size()," current equipment, ",without_source.size()," pool entries without direct current sources")
	quit()
