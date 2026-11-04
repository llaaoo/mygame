class_name MVPGame
extends Node

var catalog := ExplorationContentCatalog.new()
const SAVE_SLOT := 2
const SECTION := "exploration_mvp"

var progress := ExplorationProgress.new()
var player: Player
var region_root: Node2D
var region_id := ""
var current_data: ExplorationRegionData
var active_enemies: Array[Enemy] = []
var ui: ExpeditionUI
var _switching := false
var _defeated := false
var progress_service: ExplorationProgressService
var presenter: ExplorationPresenter
var builder: ExplorationRegionBuilder
var _save_dirty: bool:
	get: return progress_service._save_dirty if progress_service else false
var persistence_enabled := true
var ready_for_play := false
var quests: Array[ExplorationQuestData] = []
var workshop: CastingWorkshop
var _generator := RunRoomGenerator.new()
var _renderer := PrisonArena.new()

func _ready() -> void:
	progress_service = ExplorationProgressService.new(self)
	presenter = ExplorationPresenter.new(self)
	builder = ExplorationRegionBuilder.new(self)
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	player = $Player
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
	saves.active_slot = SAVE_SLOT
	saves.progress_only = true
	saves.register_section(SECTION, progress)
	saves.progress_reload_requested.connect(reload_progress)
	saves.before_save.connect(_sync_progress)
	progress.deserialize_save_data(saves.read_extension(SAVE_SLOT, SECTION))
	var load_status := saves.last_read.status
	player.skill_manager.combinations.supplies.restore(progress.casting_supplies)
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states(progress.world_states)
	ui = ExpeditionUI.new()
	ui.progress = progress
	ui.journal_provider = journal_text
	add_child(ui)
	progress_service.save_failed.connect(ui.notify)
	progress_service.changed.connect(presenter._update_objective)
	ui.travel_requested.connect(request_travel)
	ui.replay_requested.connect(replay_encounters)
	workshop = CastingWorkshop.new(self)
	ui.materials_requested.connect(workshop.show_materials)
	quests.assign(catalog.chapter.quests)
	player.died.connect(_on_player_died)
	_apply_knowledge()
	_restore_loadout()
	_restore_character()
	_change_region("camp")
	ready_for_play = true
	player.skill_manager.hand_changed.connect(func(_source: String): _queue_save())
	player.skill_manager.slot_changed.connect(func(_slot: int): _queue_save())
	player.skill_manager.combinations.supplies.changed.connect(_queue_save)
	ui.show_panel("余烬监狱 · 探索与组合", "你回到一座被封锁的监狱。火花、震荡和凝神在火、霜、雷阵中产生不同法术；水引和树脂创造新的环境条件。\n\n普通施法保留适配恩赐并获得增益；按住Shift施法可消耗恩赐，换取更强形态，随后失去持续收益。共鸣护盾也需要Shift＋震荡才主动引爆。\n\n左键近战，右键火花，空格闪避，E交互，J日志，M材料，K编组。先读营地的施法材料手册，再去外院学习火阵。", [{"title": "开始探索 / 继续旅程", "callback": ui.close_modal}])

	if load_status == SaveRepository.Status.RECOVERED:
		ui.notify("主存档不可用，已从有效备份恢复进度。")
	elif load_status not in [SaveRepository.Status.VALID, SaveRepository.Status.MISSING]:
		ui.notify("存档无法读取，原文件已保留。当前旅程不会覆盖它；请先恢复存档。")

func get_active_region() -> Node2D:
	return region_root

func request_travel(destination: String) -> void:
	if _switching or not catalog.regions.has(destination):
		return
	_switching = true
	call_deferred("_change_region", destination)

func _clear_temporary() -> void:
	GameRuntime.instance.get_region_session().leave(region_root, player)
	region_root = null
	active_enemies.clear()

func _change_region(destination: String) -> void:
	_clear_temporary()
	region_id = destination
	progress.visited[destination] = true
	current_data = catalog.regions[destination]
	region_root = Node2D.new()
	region_root.name = "ExplorationRegion"
	GameRuntime.instance.get_region_session().mount(region_root, self)
	var layout := _generator.generate_room(current_data.seed, 0, current_data.room_type)
	current_data.reserve_interaction_space(layout)
	if destination == "camp":
		layout.obstacles.clear()
	_renderer.build(region_root, layout)
	region_root.add_child(preload("res://gameplay/exploration/surface_overlay.gd").new())
	player.global_position = layout.entry_offset
	if destination == "camp":
		_restore_player()
		_build_camp()
	else:
		_build_props(layout)
		if not progress.cleared.has(destination):
			for i in range(current_data.encounters.size()):
				_spawn_enemy(current_data.encounters[i], layout, i)
	for entry in current_data.discoveries:
		_add_discovery(entry)
	for entry in current_data.events:
		_add_interaction(entry.title, entry.pos, _show_world_event.bind(entry), "mechanism")
	for spec in current_data.spell_objects:
		var object := SpellWorldObject.new()
		object.spec = spec
		object.position = spec.pos
		object.completed = progress.claims.has(spec.id)
		object.solved.connect(_on_spell_object_solved)
		object.inspected.connect(presenter.inspect_puzzle)
		region_root.add_child(object)
	for entry in current_data.exits:
		var target := str(entry.target)
		if destination == "camp" and target == "yard":
			_add_interaction(entry.title, entry.pos, func(): request_travel("yard"), "passage")
		else:
			_add_interaction(entry.title, entry.pos, _use_exit.bind(entry), "passage")
	if destination == "camp" and progress.cleared.has("gate"):
		_add_interaction("捷径：重卫关隘", Vector2(0, 280), func(): request_travel("gate"), "passage")
	if destination == "camp" and progress.choices.has("waterworks_choice"):
		_add_interaction("捷径：蓄水机房", Vector2(-300, 280), func(): request_travel("cistern"), "passage")
	if destination == "cistern" and progress.choices.has("waterworks_choice"):
		var shortcut := _add_interaction("检修梯：返回营地", Vector2(0, 300), func(): request_travel("camp"), "passage")
		shortcut.name = "WaterworksShortcut"
	player.mana_component.mp_regen_rate = 5.0 if progress.choices.get("waterworks_choice", "") == "conduit" else 3.0
	_defeated = false
	player.ui_blocked = false
	_switching = false
	_update_objective()
	_save_progress()

func _use_exit(entry: ExplorationExitData) -> void:
	if entry.requires_clear and not active_enemies.is_empty():
		ui.notify("通道封锁：先清除本区域守卫。")
		return
	if not entry.required_action.is_empty() and not progress.actions.has(entry.required_action):
		ui.notify(entry.locked_message)
		return
	if region_id == "boss" and entry.target == "camp" and progress.completed:
		ui.show_panel("监狱封锁已解除", "你击败了火焰领主，完成这次探索。\n\n已掌握的技能、法术组合、发现记录与捷径已保存。可以返回营地探索遗漏支路，或在暂停菜单重置遭遇再试不同组合。", [{"title": "返回营地", "callback": func(): ui.close_modal(); request_travel("camp")}])
		return
	request_travel(entry.target)

func _on_enemy_died(enemy: Enemy, generation: int) -> void:
	if not GameRuntime.instance.get_region_session().is_current(generation):
		return
	active_enemies.erase(enemy)
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
	progress.deaths += 1
	player.skill_manager.combinations.cancel("死亡")
	player.skill_manager.combinations.clear_field()
	_save_progress()
	ui.show_panel("远征中断", "返回营地重新整备。已学知识、已清理区域和发现记录保留；未清理遭遇重新开始。", [{"title": "返回营地", "callback": func(): ui.close_modal(); request_travel("camp")}], true)

func reload_progress() -> void:
	var data := SaveManager.instance.read_extension(SAVE_SLOT, SECTION)
	if not SaveManager.instance.last_read.usable():
		ui.notify("没有可读取的有效存档，当前旅程与原存档已保留。")
		return
	ui.close_modal()
	_clear_temporary()
	progress.deserialize_save_data(data)
	player.skill_manager.combinations.supplies.restore(progress.casting_supplies)
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states(progress.world_states)
	_apply_knowledge()
	_restore_loadout()
	_restore_character()
	request_travel("camp")

func _on_spell_object_solved(spec: SpellPuzzleData) -> void:
	if progress_service.solve_puzzle(spec):
		ui.notify("解开：" + spec.title + " · 材料已收入行囊，按M查看。")

func _queue_save() -> void:
	progress_service._queue_save()

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

func _claim_quest(quest: ExplorationQuestData) -> void:
	presenter._claim_quest(quest)

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

func _spawn_enemy(spec: ExplorationEncounterData, layout: RefCounted, index: int) -> void:
	builder._spawn_enemy(spec, layout, index)

func _add_interaction(title: String, point: Vector2, callback: Callable, kind: String = "note") -> ExplorationInteractable:
	return builder._add_interaction(title, point, callback, kind)

func _add_discovery(entry: ExplorationDiscoveryData) -> void:
	builder._add_discovery(entry)

func _process(delta: float) -> void:
	if progress_service:
		progress_service.tick(delta)
