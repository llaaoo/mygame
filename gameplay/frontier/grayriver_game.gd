class_name GrayriverGame
extends MVPGame
const TOWN := Rect2(-4600,1100,2400,2200)
var definition: Dictionary
var terrain: GrayriverTerrain
var _location_clock := 0.0
var _discovery_clock := 0.0
func _ready() -> void:
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
	_add_interaction("镇中训练：分配属性",Vector2(-3300,2350),_show_training,"person")
	_add_interaction("施法工作台：加工已学配方",Vector2(-3100,1800),workshop.show_crafts,"mechanism")
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
func _on_enemy_died(enemy: Enemy, generation: int) -> void:
	if not GameRuntime.instance.get_region_session().is_current(generation): return
	if not practice_active: progress.claims[enemy.get_meta("frontier_claim", "river.enemy.unknown")] = true
	super._on_enemy_died(enemy,generation)
	_save_progress()
func is_at_base() -> bool:
	return region_id == "camp" and is_instance_valid(player) and TOWN.has_point(player.global_position)
func has_hostiles_near(point: Vector2) -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.health_component.is_dead and enemy.global_position.distance_to(point)<500: return true
	return false
func is_area_cleared(point: Vector2) -> bool:
	if region_id != "camp": return progress.cleared.has(region_id)
	var relevant := false
	for i in range(current_data.encounters.size()):
		if current_data.encounters[i].pos.distance_to(point)>650: continue
		relevant = true
		if not progress.claims.has("river.enemy." + str(current_data.encounters[i].get_meta("persistent_id"))): return false
	return relevant
func journey_location() -> Dictionary:
	if not is_instance_valid(player) or region_id.is_empty(): return {}
	return {"region":region_id,"position":[player.position.x,player.position.y]}
func start_location() -> Dictionary:
	var saved := progress.journey
	if saved.is_empty() or not catalog.regions.has(saved.get("region","")) or progress.survival_state.get("hp",100)<=0:
		return {"region":"camp","position":Vector2.INF}
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
		ui.notify("灰河谷通路已恢复。你仍可探索遗漏地点、处理委托或回访设施。")
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G and ready_for_play:
		if ui.modal_locked: return
		if is_instance_valid(ui.modal): ui.close_modal()
		else: show_map()
		get_viewport().set_input_as_handled()
func show_map() -> void:
	ui.show_panel("灰河谷行路图","",[{"title":"继续探索","callback":ui.close_modal}])
	var scroll:=ui._modal_panel.find_child("BodyScroll",true,false) as ScrollContainer
	var body:=scroll.get_child(0)
	scroll.remove_child(body)
	body.queue_free()
	var map:=GrayriverMap.new()
	map.game=self
	scroll.add_child(map)

func discovered_places() -> String:
	var text:=""
	for point in definition.landmarks:
		if progress.claims.has("place."+point.id): text+=point.title+" · "+point.description+"\n"
	return text

func _bootstrap() -> void:
	await super._bootstrap()
	ui.pause_provider = show_valley_pause
func show_valley_pause() -> void:
	ui.show_panel("灰河谷 · 暂停","野外连续行走，遗迹沿实际入口往返。G只记录亲自到过的地点。\n\n撤回镇中需现场站定3秒，移动、攻击、施法或受伤打断；不治疗、不补货。F5保存当前地点与进度，F9读取。已击败敌人和永久成果保留。",[{"title":"继续旅程","callback":ui.close_modal},{"title":"查看行路图","callback":show_map},{"title":"现场撤回河谷镇","disabled":is_at_base(),"callback":retreat.begin},{"title":"重试遗迹（无击杀奖励）","disabled":not can_practice(),"callback":progress_service.practice_encounters},{"title":"重置河谷遭遇（无击杀奖励）","callback":replay_encounters}])
func replay_encounters() -> void:
	if trial_recorder.active: trial_recorder.finish("重置河谷遭遇")
	ui.close_modal()
	for id in progress.claims.keys():
		if str(id).begins_with("river.enemy."): progress.claims.erase(id)
	progress.cleared.clear()
	progress.choices["river.rehearsal"] = "yes"
	request_travel("camp")
