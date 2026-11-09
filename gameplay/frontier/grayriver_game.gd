class_name GrayriverGame
extends CampaignGame
const TOWN := Rect2(-4600,1100,2400,2200)
var hub: FrontierHub
var guidance: FrontierGuidance
var stories: GrayriverStories
var frontier_hud: FrontierHUD
var town_services: TownServices
var loot: GrayriverLoot
var definition: Dictionary
var terrain: GrayriverTerrain
var resuming_journey := false
var _location_clock := 0.0
var _discovery_clock := 0.0
func _ready() -> void:
	rules=preload("res://content/foundation/frontier_rules.tres")
	FrontierControls.load_preferences()
	hub=FrontierHub.new(self)
	guidance=FrontierGuidance.new(self)
	stories=GrayriverStories.new(self)
	loot = GrayriverLoot.new(self)
	town_services=TownServices.new(self)
	definition = GrayriverDefinition.data()
	catalog = ExplorationContentCatalog.new(GrayriverDefinition.build())
	save_slot = 3
	save_section = "grayriver_frontier"
	super._ready()
	presenter = GrayriverPresenter.new(self)
func render_terrain(layout: RunRoomLayout) -> void:
	if region_id != "camp":
		super.render_terrain(layout)
		return
	terrain = GrayriverTerrain.new()
	terrain.game = self
	terrain.layout = layout
	region_root.add_child(terrain)
func _build_camp() -> void:
	_add_interaction("镇中篝火：休整与粗食",Vector2(-3500,2100),Callable(),"mechanism")
	var rest := region_root.get_child(region_root.get_child_count()-1) as ExplorationInteractable
	survival.mount_rest(rest)
	_mount_trainer(town_services.training.work_position,town_services.show_training)
	town_services.ensure_stock()
	_add_interaction("整修铺：交易、拆解与强化",town_services.market.position,town_services.show,"mechanism")
	_add_interaction("镇中工作台：制造与炼制",Vector2(-3100,1800),workshop.show_crafts,"mechanism")
	_add_interaction("艾妲的委托板",Vector2(-2900,2200),_show_quests,"person")
	_add_interaction("手动整备装备",Vector2(-3300,2100),equipment_service.show_equipment,"mechanism")
	var layout := current_data.make_layout()
	for i in range(current_data.encounters.size()): _spawn_enemy(current_data.encounters[i],layout,i)
func _spawn_enemy(spec: ExplorationEncounterData, layout: RefCounted, index: int, rewards: bool = true) -> void:
	var id := "river.enemy." + str(spec.get_meta("persistent_id"))
	if not practice_active and progress.claims.has(id): return
	super._spawn_enemy(spec,layout,index,rewards and progress.choices.get("river.rehearsal", "") != "yes")
	var enemy := active_enemies.back() as Enemy
	enemy.set_meta("frontier_claim",id)
	enemy.set_meta("frontier_group",spec.get_meta("group",region_id))
	if not enemy.actor_context: session.bind_actor(enemy,id,{}, {},enemy.rewards_enabled)
	if not enemy.health_component.is_dead: stories.mount(enemy)
func _on_enemy_died(enemy: Enemy, generation: int) -> void:
	if not GameRuntime.instance.get_region_session().is_current(generation): return
	session.mark_dead(enemy)
	stories.died(enemy)
	if not practice_active: progress.claims[enemy.get_meta("frontier_claim", "river.enemy.unknown")] = true
	super._on_enemy_died(enemy,generation)
	_save_progress()
func is_at_base() -> bool:
	return is_instance_valid(player) and rules.is_base(region_id,player.global_position)
func has_hostiles_near(point: Vector2) -> bool:
	return session.has_hostiles_near("player",point) if session else false

func is_area_cleared(point: Vector2) -> bool:
	if region_id != "camp": return progress.cleared.has(region_id)
	var relevant := false
	for i in range(current_data.encounters.size()):
		if current_data.encounters[i].pos.distance_to(point)>650: continue
		relevant = true
		var id := "river.enemy." + str(current_data.encounters[i].get_meta("persistent_id"))
		if not progress.claims.has(id) and not (GrayriverStories.PEOPLE.has(id) and progress.claims.has(GrayriverStories.PEOPLE[id].claim)): return false
	return relevant
func journey_location() -> Dictionary:
	if not is_instance_valid(player) or region_id.is_empty(): return {}
	return {"region":region_id,"position":[player.position.x,player.position.y]}
func start_location() -> Dictionary:
	var saved := progress.journey
	if saved.is_empty() or not catalog.regions.has(saved.get("region","")) or progress.survival_state.get("hp",100)<=0:
		return {"region":"camp","position":Vector2.INF}
	resuming_journey=true
	return {"region":saved.region,"position":GrayriverDefinition.vector(saved.position)}
func can_practice() -> bool:
	return region_id != "camp" and super.can_practice()
func _process(delta: float) -> void:
	super._process(delta)
	if not ready_for_play or _switching or get_tree().paused or player.health_component.is_dead: return
	_location_clock += delta
	_discovery_clock += delta
	if _location_clock>=10:
		_location_clock=0
		_queue_save()
	if _discovery_clock>=.5:
		_discovery_clock=0
		_update_objective()
		if region_id == "camp":
			var cell:=Vector2i(floori(player.position.x/512),floori(player.position.y/512))
			for x in range(-1,2):
				for y in range(-1,2):progress.claims["fog.%d.%d"%[cell.x+x,cell.y+y]]=true
			for point in definition.landmarks:
				if player.position.distance_to(GrayriverDefinition.vector(point.pos))<420 and not progress.claims.has("place."+point.id):
					progress.claims["place."+point.id]=true
					ui.notify("发现："+point.title+" · G地图，J记录")
					_queue_save()
	if progress.claims.has("quest.river_warden") and not progress.completed:
		progress.completed=true
		_save_progress()
		ui.notify("旧监狱封锁已解除。镇中巡河悬赏仍在等待烽堡、遗钟与泵站的调查结果。")
	if progress.claims.has("quest.river_demo_finale") and not progress.claims.has("demo.ending_seen"):
		progress.claim("demo.ending_seen", "灰河谷：水声重归", "巡河调查完成。仍可返回遗迹收集遗漏物资与处理支线。", [], [])
		_save_progress()
		var outcome := "清水重新流向东岸，泵站外的取水处与柴灶已经启用。" if progress.claims.has("demo.water_restored") else "压力被封存在井下，维护竖井已成为通往东岸的捷径。"
		ui.show_panel("灰河谷 / 巡河终章", outcome+"\n\n已踏足地点 %d · 已交付委托 %d · 倒下次数 %d\n\n你可以继续探索，或在系统菜单保存并退出。" % [progress.visited.size(), quests.filter(func(q: ExplorationQuestData): return progress.claims.has("quest."+q.id)).size(), progress.deaths], [{"title":"继续在河谷行路", "callback":ui.close_modal}])
func show_map() -> void:
	var root:=VBoxContainer.new()
	root.add_child(FrontierWidgets.label("滚轮缩放 · 中键/右键拖动 · 左键放置路标 · 暗处为未探索地区",13,true))
	var map:=GrayriverMap.new()
	map.game=self
	root.add_child(map)
	var row:=HBoxContainer.new()
	row.add_child(FrontierWidgets.button("定位当前位置",map.center_player))
	row.add_child(FrontierWidgets.button("清除路标",func(): progress.waypoint.clear(); _queue_save(); map.queue_redraw()))
	root.add_child(row)
	ui.show_view("行路图",root,"map")

func discovered_places() -> String:
	var text:=""
	for point in definition.landmarks:
		if progress.claims.has("place."+point.id): text+=point.title+" · "+point.description+"\n"
	return text

func _bootstrap() -> void:
	await super._bootstrap()
	session.equipment_page=hub.open.bind("equipment","")
	session.supply_page=hub.open.bind("supplies","")
	if inventory_screen:
		inventory_screen.navigation_request=_inventory_navigation
		inventory_screen.page_request=open_interface
		inventory_screen.configure_request=configure_inventory_action
	player.skill_pool_ui.navigation_request=open_interface
	ui.navigation_request=open_interface
	session.sync_extra=stories.sync
	if player.inventory_panel: player.inventory_panel.page_request=hub.handle_shortcut.bind(KEY_I)
	ui.pause_provider = show_valley_pause
	ui.map_provider = show_map
	ui.menu_action=hub.open.bind("actions","")
	ui.journal_action=func(): hub.open(hub.journal_page)
	ui.shortcut_action=hub.handle_shortcut
	session.facts.committed.connect(_service_feedback)
	frontier_hud=FrontierHUD.new()
	frontier_hud.game=self
	add_child(frontier_hud)
func configure_inventory_action(action: SkillData) -> void:
	if ui.modal_locked or player.health_component.is_dead: return
	GameUIStyle.close_gameplay_views(player)
	player.skill_pool_ui.open_for(action)

func open_interface(page: String) -> void:
	if not ready_for_play or ui.modal_locked or player.health_component.is_dead: return
	if is_instance_valid(ui.modal) and not ui.modal.get_meta("frontier_page","").is_empty(): hub.remember_context()
	GameUIStyle.close_gameplay_views(player)
	match page:
		"inventory": inventory_screen.resume()
		"equipment","supplies": inventory_screen.open(page)
		"loadout": player.skill_pool_ui.open()
		"map": show_map()
		_: hub.open(page,"",true)

func _inventory_navigation(key: int) -> void:
	match key:
		KEY_TAB: hub.open("actions")
		KEY_J: hub.open("quests")
		KEY_K: player.skill_pool_ui.open()
		KEY_G: show_map()
		KEY_M: player.material_wheel.open()
func show_valley_pause() -> void:
	ui.show_panel("灰河谷 · 系统菜单","世界持续运行，打开界面仍可能受伤。野外连续行走，遗迹沿实际入口往返。G只记录亲自到过的地点。\n\n撤回镇中需现场站定3秒，移动、攻击、施法或受伤打断；不治疗、不补货。F5保存当前地点与进度，F9读取。已击败敌人和永久成果保留。",[{"title":"继续旅程","callback":ui.close_modal},{"title":"重新开始灰河谷","callback":confirm_new_journey},{"title":"查看行路图","callback":show_map},{"title":"现场撤回河谷镇","disabled":is_at_base(),"callback":retreat.begin},{"title":"重试遗迹（无击杀奖励）","disabled":not can_practice(),"callback":progress_service.practice_encounters},{"title":"重置河谷遭遇（无击杀奖励）","callback":replay_encounters},{"title":"旧监狱验证场（独立存档）","callback":open_prototype}])
func replay_encounters() -> void:
	if trial_recorder.active: trial_recorder.finish("重置河谷遭遇")
	ui.close_modal()
	for id in progress.claims.keys():
		if str(id).begins_with("river.enemy."): progress.claims.erase(id)
	progress.cleared.clear()
	progress.choices["river.rehearsal"] = "yes"
	request_travel("camp")

func knowledge_changed() -> void:
	if not is_instance_valid(player): return
	var supplies:=player.skill_manager.combinations.supplies
	supplies.restrict_crafting=true
	supplies.known_recipes.clear()
	for region: ExplorationRegionData in catalog.regions.values():
		for note in region.discoveries:
			if progress.claims.has(note.id):
				for id in note.get_meta("crafting_recipes",[]):supplies.known_recipes[id]=true

func open_prototype() -> void:
	_save_progress()
	ui.close_modal()
	get_tree().change_scene_to_file("res://mvp.tscn")

func _change_region(destination: String, arrival: Vector2 = Vector2.INF) -> void:
	for id in GrayriverStories.PEOPLE:
		if progress.claims.has(id):
			var person: Dictionary=GrayriverStories.PEOPLE[id]
			progress.claim(person.claim,person.title,"先前旅程已以战斗结束这段纠纷。",[],[])
	super._change_region(destination,arrival)
	# New optional encounters remain available in regions cleared by older saves.
	if destination != "camp" and progress.cleared.has(destination):
		var layout := current_data.make_layout()
		current_data.reserve_interaction_space(layout)
		for i in range(current_data.encounters.size()):
			if current_data.encounters[i].optional_encounter: _spawn_enemy(current_data.encounters[i],layout,i)
	loot.mount_region()
	var scenery:=FrontierScenery.new()
	scenery.game=self
	region_root.add_child(scenery)

func _show_quests() -> void:
	hub.open("quests")

func _on_spell_object_solved(spec: SpellPuzzleData) -> void:
	super._on_spell_object_solved(spec)
	builder.mount_available_stations()
	for child in region_root.get_children():
		if child is FrontierScenery: child.queue_redraw()

func _clear_temporary() -> void:
	stories.sync()
	stories.actors.clear()
	super._clear_temporary()

func inspect_actor(actor: Enemy) -> void:
	loot.inspect_actor(actor)

func record_actor_loot(actor: CharacterBody2D) -> void:
	loot.record_enemy(actor)

func _mount_trainer(point: Vector2,request: Callable) -> void:
	var id:=town_services.training.actor_id
	var configure_actor:=func(actor: CharacterBody2D):
		var npc:=actor as ServiceNPC
		npc.schedule=town_services.training.schedule
		npc.locations={"work":point,"rest":town_services.training.rest_position}
		npc.hour_query=session.hour_query; npc.service_request=request; npc.notify=session.notify; npc.lookup_actor=session.actor_for_id
		npc.set_meta("frontier_claim",id)
	var npc:=session.mount_actor(load("res://gameplay/foundation/service_npc.tscn"),id,point,configure_actor)
	if npc: session.relations.memberships[id]="civilian"

func _service_feedback(fact: Dictionary) -> void:
	if fact.kind!="production_completed": return
	var definition:=session.production.catalog.definition(str(fact.data.get("id","")))
	if not definition: return
	var title:=player.skill_manager.combinations.supplies.title(definition.recipe.output_id)
	var text:="店家已制成%s ×%d · 返回整修铺购买。"%[title,definition.recipe.output_count]
	progress_service.record_service_result("service.production."+definition.id,"整修铺完工："+title,WorldTime.instance.stamp()+"\n"+text+"货品属于店家；价格和余量以实际库存为准。")
	ui.queue_notice(text)

func grant_material_reward(source_id: String, title: String, point: Vector2, materials: Dictionary) -> void:
	loot.grant_cache(source_id, title, point, materials)
