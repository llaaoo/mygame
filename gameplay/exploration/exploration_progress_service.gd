class_name ExplorationProgressService
extends RefCounted
var game: CampaignGame
signal save_failed(message: String)
signal changed
var _save_dirty := false
var _save_delay := 0.0

func _init(owner_game: CampaignGame) -> void:
	game = owner_game

func _queue_save() -> void:
	_save_dirty = true
	_save_delay = 1.0

func record_service_result(id: String,title: String,text: String) -> void:
	for entry in game.progress.journal:
		if entry.id==id:
			entry.title=title; entry.text=text
			_queue_save(); changed.emit(); return
	game.progress.journal.append({"id":id,"title":title,"text":text})
	_queue_save(); changed.emit()

func tick(delta: float) -> void:
	if _save_dirty and game.ready_for_play and not game.get_tree().paused:
		_save_delay -= delta
		if _save_delay <= 0:
			_save_progress()

func _apply_knowledge() -> void:
	var backfilled := false
	# New techniques on already-read notes are backfilled without replaying rewards.
	for region: ExplorationRegionData in game.catalog.regions.values():
		for note in region.discoveries:
			if game.progress.claims.has(note.id):
				for id in note.actions:
					if game.catalog.actions.has(id) and not game.progress.actions.has(id):
						game.progress.actions[id]=true
						backfilled=true
				for id in note.spell_rules:
					if game.catalog.spell_rules.has(id) and not game.progress.spell_rules.has(id):
						game.progress.spell_rules[id] = true
						backfilled = true
	if backfilled: _queue_save()
	game.knowledge_changed()
	var sm := game.player.skill_manager
	var previous := sm.known_actions.duplicate()
	sm.known_actions = game.progress.actions.duplicate()
	sm.combinations.learned_rules = game.progress.spell_rules.duplicate()
	if sm.material_operations:
		for rule in SpellOperationCatalog.default_catalog().rules: sm.combinations.learned_rules[rule.id]=true
	for pair in [["pulse", 0], ["focus", 1], ["frost_sigil", 2], ["water_call", 3], ["fire_sigil", 4], ["ignite", 5]]:
		if game.progress.actions.has(pair[0]) and (previous.is_empty() or not previous.has(pair[0])):
			if sm.material_operations:
				var canonical:=SpellOperationCatalog.default_catalog().canonical(pair[0])
				var equipped:=false
				for i in range(SkillManager.MAX_SLOTS):
					if sm.get_slot(i) and sm.get_slot(i).data.get_id()==canonical: equipped=true
				if equipped: continue
			var slot: int = pair[1]
			if not sm.shortcuts.binding("slot_%d"%slot).is_empty():
				slot = -1
				for i in range(SkillManager.MAX_SLOTS):
					if sm.shortcuts.binding("slot_%d"%i).is_empty():
						slot = i
						break
			if slot >= 0:
				sm.equip_slot(slot, sm.pool.get_skill(pair[0]))
				var instance:=sm.get_slot(slot)
				if sm.material_operations and instance and sm.spell_forms.supports(instance.data): sm.shortcuts.set_selection("slot_%d"%slot,{"mode":"auto"})
	if sm.material_operations and game.progress.actions.has("water_call") and not previous.has("water_call"):
		for i in range(SkillManager.MAX_SLOTS):
			if sm.shortcuts.binding("slot_%d"%i).is_empty():
				sm.equip_slot(i,sm.pool.get_skill("disperse"))
				break
	if previous.is_empty():
		sm.equip_hand("right", sm.pool.get_skill("ignite"))

func _restore_character() -> void:
	var stats := game.player.stats_component
	for key in game.progress.character_state.get("stats", {}):
		if key in ["level", "experience", "exp_to_next", "attribute_points", "strength", "intelligence", "agility", "endurance"]:
			stats.set(key, int(game.progress.character_state.stats[key]))
	stats._recalculate_all()
	game.player._apply_stats()
	if game.player.mastery_manager and game.progress.character_state.has("mastery"):
		game.player.mastery_manager.restore_state(game.progress.character_state.mastery)
	stats.stat_changed.emit("level", stats.level)

func _restore_player() -> void:
	game.player.health_component.is_dead = false
	game.player.health_component.invincible = false
	game.player.health_component.hp = game.player.health_component.max_hp
	game.player.mana_component.mp = game.player.mana_component.max_mp
	game.player.health_changed.emit(game.player.health_component.hp, game.player.health_component.max_hp)
	game.player.mp_changed.emit(game.player.mana_component.mp, game.player.mana_component.max_mp)
	game.player.collision_shape.set_deferred("disabled", false)
	game.player.set_process(true)
	game.player.set_physics_process(true)
	game.player.state_machine.transition_to("idle")
	game.player.mana_component.mp_regen_rate = 5.0 if game.progress.choices.get("waterworks_choice", "") == "conduit" else 3.0
	game.player.health_component.regen_rate = 0.6
	game.player.skill_manager.combinations.reset_session(game.rules.physical_inventory)

func _save_progress() -> void:
	if not game.persistence_enabled:
		return
	if game.session and game.session.restoring_effects:
		_queue_save(); return
	if SaveManager.instance.save_game(game.save_slot):
		_save_dirty = false
	else:
		_save_dirty = true
		_save_delay = 5.0
		save_failed.emit("保存未完成，当前进度仍保留在内存。原存档已保留，可按F5重试。")

func _sync_progress() -> void:
	if game.session and game.session.sync_extra.is_valid(): game.session.sync_extra.call()
	# Include already emitted world facts even when saving before the next runtime frame.
	GameRuntime.instance.get_command_bus().flush_world_facts()
	if game.equipment_service:
		game.equipment_service.sync()
	if game.session: game.progress.foundation=game.session.snapshot()
	game.progress.journey = game.journey_location()
	if game.survival: game.progress.survival_state = game.survival.serialize()
	game.progress.casting_supplies = game.player.skill_manager.combinations.supplies.serialize(true)
	game.progress.world_states = GameRuntime.instance.get_world_runtime().state_manager.get_all_states().duplicate(true)
	game.progress.loadout = game.player.skill_manager.serialize_skill_state()
	game.progress.loadout["__configured"] = {}
	var stats: Dictionary = {}
	for key in ["level", "experience", "exp_to_next", "attribute_points", "strength", "intelligence", "agility", "endurance"]:
		stats[key] = game.player.stats_component.get(key)
	game.progress.character_state = {"stats": stats, "mastery": game.player.mastery_manager.serialize_state() if game.player.mastery_manager else {}}

func _restore_loadout() -> void:
	if game.progress.loadout.is_empty():
		return
	var sm := game.player.skill_manager
	sm.unequip_hand("left")
	sm.unequip_hand("right")
	for source in QuickslotLoadout.SOURCES: sm.shortcuts.clear(source)
	sm.restore_skill_state(game.progress.loadout)

func replay_encounters() -> void:
	if game.trial_recorder and game.trial_recorder.active: game.trial_recorder.finish("重置遭遇")
	game.progress.cleared.clear()
	game.progress.completed = false
	game.progress.world_states.clear()
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states({})
	game.request_travel("camp")

func practice_encounters() -> bool:
	if not game.can_practice(): return false
	game.ui.close_modal()
	game.practice_active = true
	if game.session: game.session.set_player_rewards(false)
	var layout := game.current_data.make_layout()
	game.current_data.reserve_interaction_space(layout)
	for i in range(game.current_data.encounters.size()):
		game._spawn_enemy(game.current_data.encounters[i], layout, i, false)
	game._update_objective()
	game.ui.notify("本区试战：耗材照常消耗；击杀无经验、掉落或残魂。离区结束，已解机关与探索进度保留。")
	return true


func train(stat: String) -> bool:
	if not game.player.stats_component.spend_attribute_point(stat):
		return false
	_save_progress()
	return true

func claim_quest(quest: ExplorationQuestData, approach_id: String = "") -> bool:
	if not game.is_at_base() or quest not in game.quests or not quest.can_claim(game.progress, game.player.stats_component, approach_id):
		return false
	var approach := quest.find_approach(approach_id)
	var report := "营地收到你的报告，获得 %d 属性点。" % quest.attribute_points
	if approach: report += "\n完成方式：" + approach.title + "。" + approach.description
	if not game.progress.claim("quest." + quest.id, "委托完成：" + quest.title, report, [], []):
		return false
	game.progress.choices["quest." + quest.id] = approach_id if approach else "standard"
	game.player.stats_component.attribute_points += quest.attribute_points
	_save_progress()
	changed.emit()
	return true

func choose_world_event(entry: ExplorationWorldEventData, choice: ExplorationWorldChoiceData) -> bool:
	if entry not in game.current_data.events or choice not in entry.choices or game.has_hostiles_near(entry.pos):
		return false
	for id in entry.required_claims:
		if not game.progress.claims.has(id): return false
	if entry.irreversible and game.progress.claims.has(entry.id): return false
	game.progress.choices[entry.id] = choice.id
	for id in choice.grants_claims:
		game.progress.claim(id, choice.title, choice.text, [], [])
	var record := choice.title + "：" + choice.text
	if not game.progress.claim(entry.id, entry.title, record, [], []):
		for note in game.progress.journal:
			if note.id == entry.id:
				note.text = record
	_save_progress()
	changed.emit()
	return true

func discover(entry: ExplorationDiscoveryData) -> bool:
	if entry not in game.current_data.discoveries or (entry.requires_clear and game.has_hostiles_near(entry.pos)):
		return false
	var reward := game.equipment_service.grant(entry)
	if not game.progress.claim(entry.id, entry.title, entry.text, entry.actions, entry.spell_rules):
		if reward:
			_save_progress()
		return reward
	if game.knowledge: game.knowledge.read_clues(entry)
	game.grant_material_reward(entry.id, entry.title, entry.pos, entry.materials)
	_apply_knowledge()
	if entry.heal:
		game.player.heal(60, "discovery")
		game.player.restore_mp(60, "discovery")
	_save_progress()
	changed.emit()
	return true

func solve_puzzle(spec: SpellPuzzleData, method_id: String = "") -> bool:
	if spec not in game.current_data.spell_objects or game.progress.claims.has(spec.id):
		return false
	for claim in spec.required_claims:
		if not game.progress.claims.has(claim): return false
	var costs: Dictionary = {}
	var method_title := {"thermal_impact": "火→水→冲击", "frost_impact": "凝霜→冲击", "steam": "实际蒸汽保持0.5秒"}.get(method_id, method_id) as String
	var accepted := method_id.is_empty() and spec.work_methods.is_empty()
	for i in range(spec.routes.size()):
		var route := spec.routes[i]
		if method_id == (route.id if not route.id.is_empty() else "spell_%d" % i): accepted = true
	for method in spec.work_methods:
		if method.id != method_id: continue
		method_title = method.title
		if game.player.health_component.is_dead or not game.player.stats_component.meets_requirements(method.required_attributes): return false
		costs = method.material_costs
		accepted = true
	var supplies := game.player.skill_manager.combinations.supplies
	if not accepted or not supplies.can_pay(costs): return false
	var report := spec.completion_text if not spec.completion_text.is_empty() else spec.hint + "\n机关已解开，材料收入行囊。"
	if not spec.work_methods.is_empty(): report += "\n完成方式：" + method_title + ("；消耗：" + supplies.describe_cost(costs) if not costs.is_empty() else "；无施法材料投入。")
	supplies.begin_transaction()
	if not supplies.pay(costs) or not game.progress.claim(spec.id, spec.title, report, [], []):
		supplies.finish_transaction(false)
		return false
	if not spec.work_methods.is_empty(): game.progress.choices[spec.id] = method_id
	game.grant_material_reward(spec.id, spec.title, spec.pos, spec.materials)
	var notify := supplies.finish_transaction(true)
	_queue_save()
	if notify.is_valid(): notify.call()
	changed.emit()
	return true
