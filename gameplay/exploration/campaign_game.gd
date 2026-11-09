class_name CampaignGame
extends Node
signal region_changed(id: String)

var interface_root: Node
var world_root: Node2D
var session: CampaignSession
var rules: RulesetDefinition=RulesetDefinition.new()
var catalog: ExplorationContentCatalog
const SAVE_SLOT := 2
const SECTION := "exploration_mvp"
var save_slot := SAVE_SLOT
var save_section := SECTION

var progress := ExplorationProgress.new()
var player: Player
var region_root: Node2D
var region_id := ""
var current_data: ExplorationRegionData
var active_enemies: Array[Enemy] = []
var ui: ExpeditionUI
var _switching := false
var _defeated := false
var practice_active := false # Regional rehearsal only; never serialized as progress.
var progress_service: ExplorationProgressService
var presenter: ExplorationPresenter
var builder: ExplorationRegionBuilder
var _save_dirty: bool:
	get: return progress_service._save_dirty if progress_service else false
var persistence_enabled := true
var ready_for_play := false
var _restarting := false
var quests: Array[ExplorationQuestData] = []
var equipment_service: ExpeditionEquipment
var inventory_actions: InventoryActions
var inventory_screen: ActorInventoryScreen
var knowledge: ElementKnowledge
var trial_recorder: ElementTrialRecorder
var workshop: CastingWorkshop
var field_sites: FieldWorkSites
var deliveries: SupplyDeliveryService
var alchemy: AlchemyRepairService
var survival: SurvivalService
var retreat: ExpeditionRetreat
var _renderer := PrisonArena.new()

func _ready() -> void:
	if not catalog:
		catalog=ExplorationContentCatalog.new()
	interface_root=Node.new()
	interface_root.name="Interface"
	add_child(interface_root)
	world_root=Node2D.new()
	world_root.name="World"
	add_child(world_root)
	progress_service = ExplorationProgressService.new(self)
	presenter = ExplorationPresenter.new(self)
	builder = ExplorationRegionBuilder.new(self)
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	player = $Player
	session=CampaignSession.new()
	session.name="CampaignSession"
	add_child(session)
	session.configure(catalog,rules)
	session.production.configure(session.inventory,ProductionCatalog.default_catalog(),3600.0/WorldTime.instance.time_scale)
	progress.condition_query=ConditionQuery.new()
	progress.condition_query.progress=progress
	progress.condition_query.items=session.inventory
	progress.condition_query.relations=session.relations
	progress.condition_query.regions=catalog.regions
	progress.condition_query.catalog=catalog
	session.condition_query=progress.condition_query
	session.save_requested=_queue_save
	session.inspect_actor=inspect_actor
	session.hostility_changed=actor_became_hostile
	session.observe_combat(GameRuntime.instance.get_combat_executor())
	session.hour_query=WorldTime.instance.get_hour
	session.death_handler=record_actor_loot
	player.skill_manager.combinations.allow_layered_fields = true
	var preview: Node2D = preload("res://gameplay/abilities/fields/field_placement_preview.gd").new()
	preview.name = "FieldPlacementPreview"
	player.add_child(preview)
	player.add_child(preload("res://gameplay/abilities/fields/preparation_overlay.gd").new())
	for action in catalog.chapter.actions:
		player.skill_manager.pool.add_skill(action)
	for rule in player.skill_manager.combinations.rules:
		player.skill_manager.pool.add_skill(rule.result_skill)
	var saves := SaveManager.instance
	saves.active_slot = save_slot
	saves.progress_only = true
	saves.register_section(save_section, progress)
	saves.progress_reload_requested.connect(reload_progress)
	saves.before_save.connect(_sync_progress)
	progress.deserialize_save_data(saves.read_extension(save_slot, save_section))
	session.restore(progress.foundation)
	if rules.physical_inventory: WorldTime.instance.bind_elapsed(session.elapsed_seconds)
	var load_status := saves.last_read.status
	player.skill_manager.combinations.supplies.restore(progress.casting_supplies)
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states(progress.world_states)
	ui = ExpeditionUI.new()
	ui.progress = progress
	ui.journal_provider = journal_text
	interface_root.add_child(ui)
	ui.material_action=func():
		if is_instance_valid(player.material_wheel): player.material_wheel.open()
	if is_instance_valid(player.material_wheel): player.material_wheel.save_request=_queue_save
	session.notify=ui.notify
	progress_service.save_failed.connect(ui.notify)
	progress_service.changed.connect(presenter._update_objective)
	ui.travel_requested.connect(request_travel)
	retreat = ExpeditionRetreat.new(self)
	ui.retreat_requested.connect(retreat.begin)
	ui.replay_requested.connect(replay_encounters)
	ui.practice_requested.connect(progress_service.practice_encounters)
	ui.practice_available = can_practice
	player.skill_manager.combinations.feedback_requested.connect(ui.notify)
	player.field_work.feedback_requested.connect(ui.notify)
	equipment_service = ExpeditionEquipment.new(self)
	if player.inventory_panel:
		player.inventory_panel.equip_request=equipment_service.equip
		player.inventory_panel.unequip_request=equipment_service.unequip
		player.inventory_panel.change_reason=equipment_service.change_reason
	ui.equipment_requested.connect(equipment_service.show_equipment)
	workshop = CastingWorkshop.new(self)
	field_sites = FieldWorkSites.new(self)
	alchemy = AlchemyRepairService.new(self)
	deliveries = SupplyDeliveryService.new(self)
	survival = SurvivalService.new()
	survival.game = self
	player.survival = survival
	add_child(survival)
	survival.restore(progress.survival_state)
	ui.survival_requested.connect(survival.show_page)
	ui.materials_requested.connect(workshop.show_materials)
	knowledge = ElementKnowledge.new()
	knowledge.game = self
	add_child(knowledge)
	ui.elements_requested.connect(knowledge.show_page)
	trial_recorder = ElementTrialRecorder.new()
	trial_recorder.game = self
	add_child(trial_recorder)
	ui.trials_requested.connect(trial_recorder.show_page)
	quests.assign(catalog.chapter.quests)
	player.died.connect(_on_player_died)
	_apply_knowledge()
	if rules.material_operations: player.skill_manager.enable_material_operations()
	_restore_loadout()
	_restore_character()
	equipment_service.restore()
	session.equip_item=equipment_service.equip
	session.bind_actor(player,"player",progress.equipment_counts,progress.equipment_loadout)
	if rules.physical_inventory:
		inventory_actions=InventoryActions.new(player,session)
		inventory_actions.equip_request=equipment_service.equip
		inventory_actions.unequip_request=equipment_service.unequip
		inventory_actions.management_reason=equipment_service.change_reason
		inventory_actions.removal_reason=equipment_service.removal_reason
		inventory_actions.save_request=_queue_save
		inventory_screen=ActorInventoryScreen.new()
		inventory_screen.actor=player; inventory_screen.session=session; inventory_screen.actions=inventory_actions
		inventory_screen.use_request=use_inventory_item
		inventory_screen.notify=ui.notify
		interface_root.add_child(inventory_screen)
		session.ground_page=func(id: String): inventory_screen.open("all",id)
	var start := start_location()
	_change_region(start.region, start.position)
	ready_for_play = true
	player.skill_manager.hand_changed.connect(func(_source: String): _queue_save())
	player.skill_manager.binding_changed.connect(func(_source: String): _queue_save())
	player.skill_manager.combinations.supplies.changed.connect(_queue_save)
	(player.get_node("EquipmentManager") as EquipmentManager).loadout_changed.connect(_queue_save)
	presenter.show_arrival()
	if player.skill_manager.combinations.supplies.discarded_legacy_selection:
		ui.notify("材料已改为本次选择：旧自动绑定已清除，库存保留。M轮盘按快捷槽选择来源，K完整编组。")

	if load_status == SaveRepository.Status.RECOVERED:
		ui.notify("主存档不可用，已从有效备份恢复进度。")
	elif load_status not in [SaveRepository.Status.VALID, SaveRepository.Status.MISSING]:
		ui.notify("存档无法读取，原文件已保留。当前旅程不会覆盖它；请先恢复存档。")

func use_inventory_item(uid: String) -> void:
	var item:=session.inventory.item(uid)
	if not item: return
	var definition:=session.inventory.definitions.get(item.definition_id) as ItemData
	if not definition: return
	if definition.use_profile:
		if definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY:
			var operation:=SpellOperationCatalog.default_catalog().operation("disperse")
			var source:=QuickslotMaterials.source_for(player.skill_manager,operation.action,player.material_wheel.last_source)
			if source.is_empty():
				ui.notify("先在K编组喷洒动作，或把这瓶绑定任意快捷键。")
				player.skill_pool_ui.open_for(operation.action)
				return
			for payload in operation.payloads:
				if payload.material_id==definition.id and QuickslotMaterials.select(player,source,{"payload":payload.id,"modifier":"","uid":uid}):
					ui.notify("已为"+InputBindings.label(InputBindings.action_for_source(source))+"选择这瓶喷剂。")
					_queue_save()
					return
			ui.notify("这瓶喷剂不在可用口袋中。")
		elif not player.actor_context.item_actions.begin(uid,definition.use_profile.kind==ItemUseDefinition.Kind.THROWABLE,player.get_mouse_direction()): ui.notify("无法使用：检查口袋、武器和当前动作。")
	elif SurvivalCatalog.FOODS.has(definition.id): survival.begin_eating(definition.id)

func get_active_region() -> Node2D:
	return region_root

func request_travel(destination: String, arrival: Vector2 = Vector2.INF) -> void:
	if _switching or not catalog.regions.has(destination):
		return
	_switching = true
	call_deferred("_change_region", destination, arrival)

func _clear_temporary() -> void:
	GameUIStyle.close_gameplay_views(player)
	if is_instance_valid(player.material_wheel): player.material_wheel.close()
	if session: session.leave_region()
	GameRuntime.instance.get_region_session().leave(region_root, player)
	region_root = null
	active_enemies.clear()

func _change_region(destination: String, arrival: Vector2 = Vector2.INF) -> void:
	var previous_hp := player.health_component.hp
	var previous_mp := player.mana_component.mp
	var was_dead := player.health_component.is_dead
	_clear_temporary()
	practice_active = false
	session.set_player_rewards(progress.choices.get("river.rehearsal","")!="yes")
	region_id = destination
	progress.visited[destination] = true
	current_data = catalog.regions[destination]
	region_root = Node2D.new()
	region_root.name = "ExplorationRegion"
	GameRuntime.instance.get_region_session().mount(region_root, world_root)
	var layout := current_data.make_layout()
	current_data.reserve_interaction_space(layout)
	if destination == "camp" and not current_data.open_field:
		layout.obstacles.clear()
	session.mount_region(destination,region_root,layout)
	render_terrain(layout)
	region_root.add_child(preload("res://gameplay/exploration/surface_overlay.gd").new())
	player.global_position = layout.entry_offset
	if arrival.is_finite() and layout.is_point_clear(arrival, 20):
		player.global_position = arrival
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		var view_size := get_viewport().get_visible_rect().size / camera.zoom
		var frame := Vector2(maxf(layout.arena_size.x + 72, view_size.x), maxf(layout.arena_size.y + 72, view_size.y)) * .5
		camera.limit_left = floori(-frame.x)
		camera.limit_right = ceili(frame.x)
		camera.limit_top = floori(-frame.y)
		camera.limit_bottom = ceili(frame.y)
		camera.reset_smoothing()
		camera.force_update_scroll()
	if destination == "camp" or survival._awaiting_vitals:
		_restore_player()
		survival.camp_arrival(previous_hp, previous_mp, was_dead)
	if destination == "camp":
		_build_camp()
	else:
		_build_props(layout)
		if not progress.cleared.has(destination):
			for i in range(current_data.encounters.size()):
				_spawn_enemy(current_data.encounters[i], layout, i)
	builder.build_element_objects()
	for entry in current_data.discoveries:
		_add_discovery(entry)
	for entry in current_data.events:
		_add_interaction(entry.title, entry.pos, _show_world_event.bind(entry), "mechanism")
	for spec in current_data.spell_objects:
		var object := SpellWorldObject.new()
		object.world_art=rules.world_interaction_art
		object.spec = spec
		object.position = spec.pos
		object.completed = progress.claims.has(spec.id)
		object.part_taken = not spec.pickup_claim.is_empty() and progress.claims.has(spec.pickup_claim)
		object.eligibility = field_sites.reason.bind(object)
		object.completion_handler = field_sites.complete_route.bind(object)
		object.solved.connect(_on_spell_object_solved)
		if not spec.work_methods.is_empty():
			object.inspected.connect(field_sites.on_inspected.bind(object))
		else:
			object.inspected.connect(presenter.inspect_puzzle)
		region_root.add_child(object)
	for entry in current_data.exits:
		_add_interaction(entry.title, entry.pos, _use_exit.bind(entry), "passage")
	if destination == "camp" and progress.cleared.has("gate"):
		_add_interaction("捷径：重卫关隘", Vector2(0, 280), func(): request_travel("gate"), "passage")
	if destination == "camp" and catalog.regions.has("cistern") and progress.choices.has("waterworks_choice"):
		_add_interaction("捷径：蓄水机房", Vector2(-300, 280), func(): request_travel("cistern"), "passage")
	if destination == "cistern" and progress.choices.has("waterworks_choice"):
		var shortcut := _add_interaction("检修梯：返回营地", Vector2(0, 300), func(): request_travel("camp"), "passage")
		shortcut.name = "WaterworksShortcut"
	player.mana_component.mp_regen_rate = 5.0 if progress.choices.get("waterworks_choice", "") == "conduit" else 3.0
	_defeated = false
	player.ui_blocked = false
	_switching = false
	_update_objective()
	session.finish_effect_restoration()
	region_changed.emit(destination)
	_save_progress()

func _use_exit(entry: ExplorationExitData) -> void:
	if not entry.claims_satisfied(progress):
		ui.notify(entry.locked_message)
		return
	if entry.requires_clear and not active_enemies.is_empty():
		ui.notify("通道封锁：先清除本区域守卫。")
		return
	if not entry.required_action.is_empty() and not progress.actions.has(entry.required_action):
		ui.notify(entry.locked_message)
		return
	if region_id == "boss" and entry.target == "camp" and progress.completed:
		ui.show_panel("监狱封锁已解除", "你击败了火焰领主，完成这次探索。\n\n已掌握的技能、法术组合、发现记录与捷径已保存。可以返回营地探索遗漏支路，或在暂停菜单重置遭遇再试不同组合。", [{"title": "返回营地", "callback": func(): ui.close_modal(); request_travel("camp")}])
		return
	request_travel(entry.target, entry.arrival)

func _on_enemy_died(enemy: Enemy, generation: int) -> void:
	if not GameRuntime.instance.get_region_session().is_current(generation):
		return
	if is_instance_valid(enemy) and enemy.rewards_enabled:
		var soul := SoulRemnant.new()
		region_root.add_child(soul)
		soul.global_position = enemy.global_position
	active_enemies.erase(enemy)
	if practice_active:
		if active_enemies.is_empty():
			practice_active = false
			ui.notify("本区试战完成。没有击杀奖励，探索与机关进度保持；Esc可再次试战。")
		_update_objective()
		return
	if active_enemies.is_empty():
		progress.cleared[region_id] = true
		if region_id == "boss":
			progress.completed = true
		ui.notify("区域已清理，前方通路开启。" if region_id != "boss" else "火焰领主已倒下。前往出口完成探索！")
		call_deferred("_save_progress")
	_update_objective()

func _on_player_died() -> void:
	if _defeated:
		return
	_defeated = true
	if trial_recorder and trial_recorder.active: trial_recorder.call_deferred("finish", "死亡中断")
	if player.actor_context: session.mark_dead(player)
	progress.deaths += 1
	player.skill_manager.combinations.supplies.clear_selection()
	player.skill_manager.combinations.cancel("死亡")
	player.skill_manager.combinations.clear_field()
	_save_progress()
	ui.show_panel("远征中断", "返回营地后恢复半数生命和法力，并保留最低饱食饮水。到篝火主动休整或吃粗食，库存不会免费补满。已学知识、已清理区域和发现记录保留；未清理遭遇重新开始。", [{"title": "返回营地", "callback": func(): ui.close_modal(); request_travel("camp")}], true)

func reload_progress() -> void:
	var data := SaveManager.instance.read_extension(save_slot, save_section)
	if not SaveManager.instance.last_read.usable():
		ui.notify("没有可读取的有效存档，当前旅程与原存档已保留。")
		return
	ui.close_modal()
	if trial_recorder: trial_recorder.active = false
	_clear_temporary()
	progress.deserialize_save_data(data)
	session.restore(progress.foundation)
	if progress.foundation.is_empty(): player.skill_manager.combinations.supplies.restore(progress.casting_supplies)
	else: player.skill_manager.combinations.supplies.clear_selection()
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states(progress.world_states)
	_apply_knowledge()
	_restore_loadout()
	session.restore_shortcuts(player)
	_restore_character()
	equipment_service.restore()
	session.restore_actor_state(player)
	knowledge.restore_clues()
	survival.restore(progress.survival_state)
	var start := start_location()
	request_travel(start.region, start.position)

func _on_spell_object_solved(spec: SpellPuzzleData) -> void:
	if progress.claims.has(spec.id):
		alchemy.on_opened(spec)
		if not spec.work_methods.is_empty():
			player.field_work.cancel("设备已解封")
			player.field_work.close_panel()
		var unlocked: Array[String] = []
		var camp_direct := false
		for exit in current_data.exits:
			if spec.id in exit.required_claims and exit.claims_satisfied(progress):
				unlocked.append(exit.title)
				if not exit.camp_return_title.is_empty(): camp_direct = true
		var message := spec.completion_text if not spec.completion_text.is_empty() else "机关已解开，物资已保留在现场或收入行囊。"
		if not unlocked.is_empty(): message += "\n捷径已开启："+"、".join(unlocked)+("；营地可直达此处。" if camp_direct else "；使用现场出口通行。")
		var reports := progress_service.quest_feedback(spec.id)
		if not reports.is_empty(): message += "\n"+reports
		ui.notify(message)

func can_practice() -> bool:
	return ready_for_play and not _switching and not _defeated and not player.health_component.is_dead and not practice_active and progress.cleared.has(region_id) and not current_data.encounters.is_empty() and active_enemies.is_empty()

func _queue_save() -> void:
	progress_service._queue_save()

func confirm_new_journey() -> void:
	if _restarting: return
	ui.show_panel("重新开始灰河谷？","人物成长、技能知识、背包与穿戴、任务、探索、敌人和游戏时间都会从初始状态开始。\n\n当前旅程与原主/备份存档会先归档保留。操作设置与监狱独立存档保留。",[{"title":"取消，继续当前旅程","callback":ui.close_modal},{"title":"归档旧旅程并重新开始","callback":func(): call_deferred("start_new_journey")}])

func start_new_journey() -> void:
	if _restarting or not ready_for_play: return
	var scene:=load(scene_file_path) as PackedScene
	if not scene:
		ui.notify("无法重新打开当前游戏场景，当前旅程保持。")
		return
	_restarting=true
	if not SaveManager.instance.start_new_campaign(save_slot,save_section,ExplorationProgress.new().serialize_save_data()):
		_restarting=false
		ui.notify("新旅程未建立：无法安全归档或写入存档，当前旅程保持。")
		return
	persistence_enabled=false; ready_for_play=false
	if trial_recorder: trial_recorder.active=false
	GameUIStyle.close_gameplay_views(player); ui.close_modal()
	var error:=get_tree().change_scene_to_packed(scene)
	if error!=OK: ui.notify("新存档已建立，但场景切换失败；请退出重进。旧旅程已归档，当前运行不会覆盖新存档。")

func _apply_knowledge() -> void:
	progress_service._apply_knowledge()

func _restore_character() -> void:
	progress_service._restore_character()

func _restore_player() -> void:
	progress_service._restore_player()

func _save_progress() -> void:
	progress_service._save_progress()

func _sync_progress() -> void:
	progress_service._sync_progress()

func _restore_loadout() -> void:
	progress_service._restore_loadout()

func replay_encounters() -> void:
	progress_service.replay_encounters()

func _show_training() -> void:
	presenter._show_training()

func _train(stat: String) -> void:
	presenter._train(stat)

func _update_objective() -> void:
	presenter._update_objective()

func _show_quests() -> void:
	presenter._show_quests()

func _claim_quest(quest: ExplorationQuestData, approach_id: String = "") -> void:
	presenter._claim_quest(quest, approach_id)

func _show_world_event(entry: ExplorationWorldEventData) -> void:
	presenter._show_world_event(entry)

func _choose_world_event(entry: ExplorationWorldEventData, choice: ExplorationWorldChoiceData) -> void:
	presenter._choose_world_event(entry, choice)

func journal_text() -> String:
	return presenter.journal_text()

func _build_camp() -> void:
	builder._build_camp()

func _build_props(layout: RefCounted) -> void:
	builder._build_props(layout)

func _spawn_enemy(spec: ExplorationEncounterData, layout: RefCounted, index: int, rewards: bool = true) -> void:
	builder._spawn_enemy(spec, layout, index, rewards)

func _add_interaction(title: String, point: Vector2, callback: Callable, kind: String = "note") -> ExplorationInteractable:
	return builder._add_interaction(title, point, callback, kind)

func _add_discovery(entry: ExplorationDiscoveryData) -> void:
	builder._add_discovery(entry)

func _process(delta: float) -> void:
	if progress_service:
		progress_service.tick(delta)

func render_terrain(layout: RunRoomLayout) -> void:
	_renderer.build(region_root, layout)

func is_at_base() -> bool: return region_id == "camp"
func has_hostiles_near(_point: Vector2) -> bool: return not active_enemies.is_empty()
func is_area_cleared(_point: Vector2) -> bool: return progress.cleared.has(region_id)
func knowledge_changed() -> void: pass
func journey_location() -> Dictionary: return {}
func start_location() -> Dictionary: return {"region": "camp", "position": Vector2.INF}

func inspect_actor(_actor: Enemy) -> void: pass
func actor_became_hostile(actor: CharacterBody2D) -> void:
	if actor is Enemy and not active_enemies.has(actor): active_enemies.append(actor)
	progress.cleared.erase(region_id)

func record_actor_loot(_actor: CharacterBody2D) -> void: pass

func grant_material_reward(source_id: String, title: String, point: Vector2, materials: Dictionary) -> void:
	player.skill_manager.combinations.supplies.grant(materials)
