class_name ExplorationRegionBuilder
extends RefCounted
var game: CampaignGame

func _init(owner_game: CampaignGame) -> void:
	game = owner_game

func _build_camp() -> void:
	_add_interaction("元素实验：路线与配置记录", Vector2(-260, -240), game.trial_recorder.show_page, "note")
	var rest := _add_interaction("篝火：休整与粗食", Vector2(-150, 50), Callable(), "mechanism")
	game.survival.mount_rest(rest)
	_add_interaction("营地整备台：装备与构筑", Vector2(-260, -140), game.equipment_service.show_equipment, "mechanism")
	_add_interaction("查阅探索日志", Vector2(150, -180), game.ui.show_journal)
	_add_interaction("营地训练：分配属性", Vector2(0, -180), game._show_training)
	_add_interaction("施法工作台：加工材料", Vector2(0, 130), game.workshop.show_crafts, "mechanism")
	_add_interaction("测绘员艾妲：营地委托" if game.progress.claims.has("cartographer_rescued") else "营地委托板", Vector2(200, 35), game._show_quests, "person" if game.progress.claims.has("cartographer_rescued") else "note")
	var dummy := load("res://world/object/wooden_crate.tscn").instantiate() as MapObject
	dummy.persistent_id = "camp.training_crate"
	dummy.position = Vector2(250, 180)
	game.region_root.add_child(dummy)
	for region: ExplorationRegionData in game.catalog.regions.values():
		for exit in region.exits:
			if not exit.camp_return_title.is_empty() and exit.claims_satisfied(game.progress) and (not exit.requires_clear or game.progress.cleared.has(region.id)) and (exit.required_action.is_empty() or game.progress.actions.has(exit.required_action)):
				_add_interaction(exit.camp_return_title, exit.camp_return_pos, game.request_travel.bind(region.id, exit.pos), "passage")

func _build_props(layout: RefCounted) -> void:
	for i in range(layout.props.size()):
		var spec: Dictionary = layout.props[i]
		if spec.kind == "chest":
			continue # Discoveries and supplies use fixed grants, not equipment drops.
		var position: Vector2 = spec.position
		var blocked := false
		for item in game.current_data.interaction_points():
			if position.distance_to(item.pos) < 80:
				blocked = true
		if blocked:
			continue
		var path := "res://world/object/wooden_crate.tscn"
		if spec.kind == "barrel":
			path = "res://world/object/oil_barrel.tscn"
		elif spec.kind == "trap":
			path = "res://world/traps/spike_trap.tscn"
		var node := load(path).instantiate() as Node2D
		if node is MapObject:
			node.persistent_id = "%s.prop.%d" % [game.region_id, i]
		node.position = position
		game.region_root.add_child(node)

func _spawn_enemy(spec: ExplorationEncounterData, layout: RefCounted, index: int, rewards: bool = true) -> void:
	var boss := bool(spec.boss)
	var enemy := load("res://entities/boss/fire_lord.tscn" if boss else "res://entities/enemy/enemy.tscn").instantiate() as Enemy
	enemy.name = "Encounter_%d" % index
	enemy.rewards_enabled = rewards
	enemy.physical_loot = game.rules.physical_inventory
	enemy.health_drop_amount = 8
	enemy.mana_drop_amount = 12
	var point: Vector2 = spec.pos
	var clear: bool=layout.is_walkable(point,28) if spec.has_meta("map_source") else layout.is_point_clear(point,28)
	if not clear:
		for candidate in layout.enemy_offsets:
			var occupied := false
			for other in game.active_enemies:
				if candidate.distance_to(other.position) < 65:
					occupied = true
			if not occupied:
				point = candidate
				break
	enemy.position = point
	enemy.set_meta("encounter_group",spec.group)
	enemy.set_meta("encounter_tactics",spec.tactics)
	if not boss:
		enemy.character_definition = spec.character
		enemy.enemy_type = spec.profile.appearance_preset if spec.profile else (2 if game.region_id == "gate" and index == 0 else 0)
		enemy.ai_role = int(spec.profile.role if spec.profile else spec.role) as Enemy.AIRole
		if spec.profile:
			enemy.set_meta("encounter_profile", spec.profile.id)
			enemy.set_meta("encounter_title", spec.profile.title)
	if boss:
		var data := load("res://content/bosses/fire_lord.tres").duplicate(true) as BossData
		data.resists = {"fire": 0.1 if game.progress.choices.get("waterworks_choice", "") == "cooling" else 0.3}
		enemy.boss_data = data
	game.region_root.add_child(enemy)
	var hp := int(spec.hp)
	if boss and game.progress.choices.get("waterworks_choice", "") == "cooling":
		hp = int(hp * 0.75)
	if not enemy.character_definition:
		enemy.max_hp = hp
		enemy.health_component.max_hp = hp
		enemy.health_component.hp = hp
	enemy.detect_range = spec.detect_range
	if not enemy.character_definition:
		enemy.move_speed = float(spec.speed)
		enemy.attack_damage = 9 if not boss else 15
	if not boss and spec.profile:
		if not enemy.character_definition: enemy.attack_damage = spec.profile.melee_damage
		enemy.melee_windup = spec.profile.melee_windup
		enemy.melee_recovery = spec.profile.melee_recovery
		enemy.ranged_windup = spec.profile.ranged_windup
		enemy.attack_cooldown = spec.profile.melee_cooldown
		enemy.attack_range = spec.profile.attack_range
		enemy.ranged_preferred_range = spec.profile.ranged_preferred_range
	enemy.died.connect(game._on_enemy_died.bind(enemy, GameRuntime.instance.get_region_session().generation), CONNECT_ONE_SHOT)
	game.active_enemies.append(enemy)
	if game.session and not game.rules.physical_inventory: game.session.bind_actor(enemy,"actor.%s.%d"%[game.region_id,index])

func _add_interaction(title: String, point: Vector2, callback: Callable, kind: String = "note") -> ExplorationInteractable:
	var node := ExplorationInteractable.new()
	node.world_art=game.rules.world_interaction_art
	node.marker_art=not game.current_data.map_scene or game.current_data.open_field
	node.title = title
	node.kind = kind
	node.position = point
	node.callback = callback
	game.region_root.add_child(node)
	return node

func _add_discovery(entry: ExplorationDiscoveryData) -> void:
	if entry.hide_when_claimed and game.progress.claims.has(entry.id) and not game.equipment_service.has_pending_rewards(entry):
		return
	var label := str(entry.title)
	if game.progress.claims.has(entry.id):
		label += "（已记录）"
	var node := _add_interaction(label, entry.pos, Callable(), entry.kind)
	node.callback = game.presenter.inspect_discovery.bind(entry, node)

func build_element_objects() -> void:
	if not game.world_storage: game.world_storage=WorldStorageService.new(game)
	for spec in game.current_data.storage: game.world_storage.mount(spec)
	for spec in game.current_data.amenities:
		var callback: Callable=game.workshop.show_crafts if spec.service=="craft" else game.equipment_service.show_equipment
		if spec.service=="mediation":callback=game.map_service_request.bind(spec.service) if game.map_service_request.is_valid() else Callable()
		var node:=_add_interaction(spec.title,spec.pos,callback,"mechanism")
		node.set_meta("map_amenity",spec.id)
		if spec.service=="rest": game.survival.mount_rest(node)
	for spec in game.current_data.delivery_sites: game.deliveries.mount(spec)
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	for facility in game.current_data.facilities: game.alchemy.mount(facility)
	mount_available_stations()
	for patch in game.current_data.surface_patches:
		if not patch.disabled_by_claim.is_empty() and game.progress.claims.has(patch.disabled_by_claim): continue
		surfaces.apply_area(game.region_root.to_global(patch.pos), patch.radius, [], "authored:" + game.region_id, patch.state, patch.duration)
	for prop in game.current_data.fixed_props:
		var node := prop.scene.instantiate() as MapObject
		node.persistent_id = prop.id
		node.position = prop.pos
		game.region_root.add_child(node)
	for spec in game.current_data.valves:
		var valve := SurfaceValve.new()
		valve.spec = spec
		valve.position = spec.pos
		valve.mode = str(game.progress.choices.get(spec.id, "off"))
		if valve.mode not in ["off", "a", "b"]: valve.mode = "off"
		valve.state_changed.connect(func(mode: String):
			game.progress.choices[spec.id] = mode
			game._queue_save()
			game.ui.notify("水路已切换。只补充清洁水，冰、毒、电与火的变化保留；旧水自然消退。"))
		game.region_root.add_child(valve)

func mount_available_stations() -> void:
	for station in game.current_data.survival_stations:
		var available := true
		for id in station.required_claims:
			if not game.progress.claims.has(id): available = false
		if not available: continue
		var mounted := false
		for node in game.region_root.get_children():
			if node.has_meta("survival_station") and node.get_meta("survival_station") == station: mounted = true
		if not mounted: game.survival.mount(station)
