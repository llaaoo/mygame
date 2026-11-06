class_name ElementKnowledge
extends Node
## Knowledge is an observation ledger. It never gates world reactions.
var game: CampaignGame

func _ready() -> void:
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	surfaces.reaction_occurred.connect(_on_surface)
	var resolver := game.player.get_node("SkillSynergyResolver") as SkillSynergyResolver
	resolver.reaction_observed.connect(_on_hit_reaction)
	game.player.skill_manager.cast_committed.connect(_on_cast_committed)
	restore_clues()

func restore_clues() -> void:
	for region: ExplorationRegionData in game.catalog.regions.values():
		for note in region.discoveries:
			if game.progress.claims.has(note.id): read_clues(note)

func read_clues(note: ExplorationDiscoveryData) -> void:
	for id in note.element_clues:
		if ElementCatalog.definition(id): game.progress.element_clues[ElementCatalog.family_id(id)] = true

func _record(id: String, title: String) -> void:
	if game.progress.verified_reactions.has(id): return
	game.progress.verified_reactions[id] = true
	game._queue_save()
	game.ui.notify("已验证：" + title + " · J日志查看元素关系")

func _on_surface(id: String, cell: Vector2i, _source: String) -> void:
	if not is_instance_valid(game.region_root) or not is_instance_valid(game.player): return
	var point := Vector2(cell * 64) + Vector2(32, 32)
	if game.player.global_position.distance_to(point) > 300: return
	for rule in SurfaceCatalog.all_reactions():
		if rule.rule_id == id:
			_record("surface:" + id, surface_description(rule))
			return

func _on_hit_reaction(id: String, _position: Vector2) -> void:
	for rule in ElementReactionCatalog.all_rules():
		if rule.id == id:
			_record("hit:" + id, rule.display_name)
			return

func _on_cast_committed(plan: CastPlan) -> void:
	for component in plan.components:
		if not component.surface_state.is_empty() or not component.substitute_material.is_empty():
			var source := "material" if not component.substitute_material.is_empty() else "surface"
			_record("prepare:" + component.rule_id + ":" + source, component.skill.display_name + "·" + ("材料准备" if source == "material" else "地面准备"))

static func surface_description(rule: SurfaceReaction) -> String:
	var names: Array[String] = []
	for tag in rule.required_tags:
		var element := ElementCatalog.definition(tag)
		names.append(element.title if element else "冲击" if tag == "impact" else tag)
	return "%s＋%s→%s（%.0f秒）" % [SurfaceManager.surface_title(rule.required_state), "／".join(names), SurfaceManager.surface_title(rule.result_state), rule.result_duration]

func text() -> String:
	var result := "已读线索与实际验证分别记录；世界规律始终生效，不需要先解锁日志。\n\n"
	for element in ElementCatalog.all_definitions():
		result += element.title + " · " + ("已读线索\n" + element.description if game.progress.element_clues.has(element.id) else "尚无线索：探索相关记录") + "\n\n"
		if game.progress.element_clues.has(element.id):
			for aspect in ElementCatalog.aspects_for(element.id): result += "  " + aspect.description + "\n"
	result += "实际验证的地面关系\n"
	var found := false
	for rule in SurfaceCatalog.all_reactions():
		if game.progress.verified_reactions.has("surface:" + rule.rule_id):
			result += surface_description(rule) + "；站位与持续时间会改变用途。\n"
			found = true
	result += "\n实际验证的命中关系\n"
	for rule in ElementReactionCatalog.all_rules():
		if game.progress.verified_reactions.has("hit:" + rule.id):
			result += rule.display_name + "：" + rule.description + "\n"
			found = true
	result += "\n实际验证的恩赐准备\n"
	for rule: SpellCombinationRule in game.catalog.spell_rules.values():
		if rule.required_surface.is_empty(): continue
		if game.progress.verified_reactions.has("prepare:" + rule.id + ":surface"):
			result += "Shift凝神＋" + SurfaceManager.surface_title(rule.required_surface) + "→" + rule.result_skill.display_name + "；消耗脚下1格与%d MP（修正前），保留周围介质。\n" % rule.mana_cost
			found = true
		if game.progress.verified_reactions.has("prepare:" + rule.id + ":material"):
			var supplies := game.player.skill_manager.combinations.supplies
			var material: CastingMaterialData = supplies.catalog[rule.substitute_material]
			result += "Shift凝神＋" + material.title + "→" + rule.result_skill.display_name + "；消耗1份与%d MP（修正前），不消耗地面。\n" % (rule.mana_cost + material.extra_mana)
			found = true
	if not found: result += "尚未验证。先试着用已有工具改变环境，再在战斗中复用。\n"
	return result

func show_page() -> void:
	game.ui.show_panel("元素关系 · 水系形态与线索验证", text(), [{"title": "返回探索日志", "callback": game.ui.show_journal}, {"title": "继续探索", "callback": game.ui.close_modal}])
