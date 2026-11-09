extends SceneTree
## Test-only driver: real keyboard/pointer events, normal actors and unmodified budgets.
## Commands are external test instructions; this is not a player-facing combo feature.
var game: GrayriverGame
var output:=OS.get_environment("GRAYRIVER_FIRST30_OUTPUT")
var busy:=true
var last_id:=-1
var active_time:=0.0
var damage_taken:=0
var last_hp:=100
var casts: Array[Dictionary]=[]
var held: Dictionary={}
var last_duel: Dictionary={}
var melee_hits: Array[Dictionary]=[]
var defenses: Array[Dictionary]=[]
var physical_actions: Array[Dictionary]=[]
func _init() -> void:
	if output.is_empty(): output="/tmp/grayriver-first30/live"
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("boot")
func boot() -> void:
	game=load("res://grayriver.tscn").instantiate()
	root.add_child(game); current_scene=game
	for i in range(120):
		await process_frame
		if game.ready_for_play and game.frontier_hud: break
	last_hp=game.player.health_component.hp
	game.player.health_component.health_changed.connect(observe_health)
	game.player.skill_manager.cast_committed.connect(observe_cast)
	game.session.facts.committed.connect(observe_fact)
	GameRuntime.instance.get_combat_executor().defense_resolved.connect(observe_defense)
	write_json("ready.json",snapshot())
	busy=false
func _process(delta: float) -> bool:
	if game and game.ready_for_play and not paused: active_time+=delta
	if busy or not FileAccess.file_exists(output.path_join("request.json")): return false
	var request=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("request.json")))
	if not request is Dictionary or int(request.get("id",-1))==last_id: return false
	last_id=int(request.id); busy=true
	call_deferred("execute",request)
	return false
func observe_health(hp: int,_maximum: int) -> void:
	if hp<last_hp: damage_taken+=last_hp-hp
	last_hp=hp
func observe_defense(target: Node2D,outcome: Dictionary) -> void:
	if target==game.player: defenses.append({"t":active_time,"outcome":outcome.duplicate(),"hp":game.player.health_component.hp,"stamina":game.player.actor_context.actions.stamina.current})
func observe_fact(fact: Dictionary) -> void:
	if fact.kind=="physical_action_started" and fact.source=="player": physical_actions.append({"t":active_time,"data":fact.data.duplicate(true)})
	if fact.kind=="melee_hit" and fact.source=="player": melee_hits.append({"t":active_time,"data":fact.data.duplicate(true)})
func observe_cast(plan: CastPlan) -> void:
	casts.append({"t":active_time,"action":plan.action.get_id(),"result":plan.skill.get_id(),"rule":plan.rule_id,"mp_cost":plan.cost,"charge_power":plan.charge_power,"materials":plan.material_costs.duplicate(),"position":[game.player.position.x,game.player.position.y],"mp_after":game.player.mana_component.mp})
func write_json(name: String,data: Variant) -> void:
	var f:=FileAccess.open(output.path_join(name),FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"  "))
func settle(n:=3) -> void:
	# Software rendering can run several physics catch-up frames before a GUI
	# frame. Wait for both so the next input observes the updated live layout.
	for i in range(n): await physics_frame; await process_frame
func key_event(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event); held[code]=pressed
func tap(code: Key) -> void:
	key_event(code,true); await settle(2); key_event(code,false); await settle(2)
func release_movement() -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_V,KEY_ALT]:
		if held.get(code,false): key_event(code,false)
func aim(point: Vector2) -> void:
	var screen:=root.get_canvas_transform()*point
	if DisplayServer.get_name()!="headless": Input.warp_mouse(screen)
	var motion:=InputEventMouseMotion.new(); motion.position=screen; Input.parse_input_event(motion)
func mouse(button: MouseButton) -> void:
	var event:=InputEventMouseButton.new(); event.position=root.get_mouse_position(); event.button_index=button; event.pressed=true
	Input.parse_input_event(event); await settle(2)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await settle(2)
func walk(point: Vector2,tolerance:=24.0,seconds:=45.0) -> String:
	if paused or game.player.ui_blocked: return "menu_open"
	var elapsed:=0.0
	while game.player.position.distance_to(point)>tolerance:
		if game.player.health_component.is_dead: release_movement(); return "player_dead"
		if elapsed>seconds: release_movement(); return "walk_timeout"
		var direction:=game.session.region.navigation.direction(game.player.position,point)
		if direction.is_zero_approx(): direction=(point-game.player.position).normalized()
		for pair in [[KEY_D,direction.x>.35],[KEY_A,direction.x<-.35],[KEY_S,direction.y>.35],[KEY_W,direction.y<-.35]]:
			if bool(held.get(pair[0],false))!=bool(pair[1]): key_event(pair[0],pair[1])
		await physics_frame; elapsed+=1.0/Engine.physics_ticks_per_second
	release_movement(); await settle(2); return ""
func click(label: String) -> String:
	var button: Button
	for node in root.find_children("*","Button",true,false):
		if node is Button and (node.text==label or node.text.begins_with(label+"\n")) and node.is_visible_in_tree(): button=node; break
	if not button: return "missing_button: "+label
	if button.disabled: return "disabled_button: "+label
	button.grab_focus(); await settle(3)
	var ancestor:=button.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle(3)
	var point:=button.get_global_rect().get_center()
	if not root.get_visible_rect().has_point(point): return "button_outside_viewport"
	if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new(); motion.position=point; Input.parse_input_event(motion)
	await settle(2)
	var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); await settle(2)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await settle(4)
	return ""
func label_click(label: String) -> String:
	var target: Control
	for node in root.find_children("*","Label",true,false):
		if node.text==label and node.is_visible_in_tree(): target=node; break
	if not target: return "missing_label: "+label
	var parent:=target.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent=parent.get_parent()
	await settle(3)
	var point:=target.get_global_rect().get_center()
	if not root.get_visible_rect().has_point(point): return "label_outside_viewport"
	if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	Input.parse_input_event(motion); Input.flush_buffered_events(); await settle(3)
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events(); await settle(3)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await settle(3)
	return ""
func click_point(point: Vector2) -> void:
	if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	Input.parse_input_event(motion); Input.flush_buffered_events(); await settle(3)
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events(); await settle(3)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await settle(3)
func wheel_choice(key: String,payload: String,uid: String) -> String:
	await tap(KEY_M); await tap(OS.find_keycode_from_string(key))
	var wheel:=game.player.material_wheel
	if not wheel.visible: return "wheel_not_open"
	var index:=-1
	for i in range(wheel.entries.size()):
		if wheel.entries[i].choice.get("payload","")==payload or payload=="auto" and wheel.entries[i].choice.get("mode","")=="auto": index=i; break
	if index<0: return "wheel_payload_missing"
	var point:=wheel._ring.position+Vector2(180,180)+Vector2.from_angle(-PI/2+(index%8)*TAU/8)*125
	var motion:=InputEventMouseMotion.new(); motion.position=point; Input.parse_input_event(motion); await settle(2)
	if not uid.is_empty():
		for attempt in range(10):
			if wheel.entries[index].choice.get("uid","")==uid: break
			await mouse(MOUSE_BUTTON_WHEEL_DOWN)
	var sequence:=game.player.actor_context.actions._attack_sequence
	await click_point(point)
	if game.player.actor_context.actions._attack_sequence!=sequence: return "wheel_attack_leak"
	return "" if not wheel.visible else "wheel_not_confirmed"
func inventory_command(request: Dictionary) -> String:
	var screen:=game.inventory_screen
	if not screen.visible: await tap(KEY_I)
	await settle(8)
	var uid:=game.session.inventory.find_owned("player",str(request.item))
	if uid.is_empty(): return "owned_item_missing"
	var tile:=screen._grid.get_node_or_null("Item_"+uid.replace(".","_")) as Control
	if not tile: return "inventory_tile_missing"
	(screen._grid.get_parent() as ScrollContainer).ensure_control_visible(tile); await settle(3)
	await click_point(tile.get_global_rect().get_center())
	if screen.selected!=uid: return "inventory_selection_moved"
	if request.has("quantity"):
		await click_point(screen._quantity.get_line_edit().get_global_rect().get_center())
		var all:=InputEventKey.new(); all.keycode=KEY_A; all.physical_keycode=KEY_A; all.ctrl_pressed=true; all.pressed=true
		Input.parse_input_event(all); all=all.duplicate(); all.pressed=false; Input.parse_input_event(all); Input.flush_buffered_events(); await settle(2)
		for digit in str(request.quantity):
			var typed:=InputEventKey.new(); typed.keycode=KEY_0+int(digit); typed.physical_keycode=typed.keycode; typed.unicode=digit.unicode_at(0); typed.pressed=true
			Input.parse_input_event(typed); typed=typed.duplicate(); typed.pressed=false; Input.parse_input_event(typed); Input.flush_buffered_events(); await settle(2)
		await tap(KEY_ENTER); await settle(4)
		if int(screen._quantity.value)!=int(request.quantity): return "quantity_not_committed: "+str(screen._quantity.value)
	var error:=await click(str(request.get("action","")))
	if screen.visible and request.get("close",true) and error.is_empty(): error=await click("关闭")
	return error
func screen(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func runtime_scripts() -> Array:
	var paths: Dictionary={}
	var nodes: Array[Node]=[game]
	while not nodes.is_empty():
		var node: Node=nodes.pop_back()
		var script:=node.get_script() as Script
		if script and not script.resource_path.begins_with("res://addons/"): paths[script.resource_path]=true
		for child in node.get_children(): nodes.append(child)
	var result:=paths.keys(); result.sort(); return result
func snapshot() -> Dictionary:
	if not game or not game.ready_for_play: return {"ready":false}
	var actor:=game.player
	var enemies: Array[Dictionary]=[]
	for enemy in game.active_enemies:
		if not is_instance_valid(enemy): continue
		enemies.append({"id":str(enemy.get_meta("frontier_claim","")),"title":str(enemy.get_meta("encounter_title",enemy.enemy_name)),"position":[enemy.position.x,enemy.position.y],"distance":enemy.position.distance_to(actor.position),"hp":enemy.health_component.hp,"mp":enemy.mana_component.mp if enemy.mana_component else 0,"detect":enemy.detect_range,"state":enemy._current_state_name(),"mode":enemy.actor_context.actions.mode,"processing":enemy.can_process()})
	enemies.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance<b.distance)
	var texts: Array[String]=[]
	var buttons: Array[String]=[]
	if is_instance_valid(game.ui.modal):
		for node in game.ui.modal.find_children("*","Control",true,false):
			if not node.is_visible_in_tree(): continue
			if node is Label or node is RichTextLabel: texts.append(node.text)
			if node is Button: buttons.append(node.text)
	var fields: Array[Dictionary]=[]
	for field in actor.skill_manager.combinations.live_fields(): fields.append({"type":field.field_type,"charges":field.charges,"remaining":field.remaining,"position":[field.position.x,field.position.y]})
	var slots: Array[String]=[]
	for i in range(6):
		var inst:=actor.skill_manager.get_slot(i); slots.append(inst.data.get_id() if inst else "")
	return {"spell_affinity":actor.skill_manager.spell_forms.affinity,"effective_forms":form_snapshot(),"active_seconds":active_time,"wall_usec":Time.get_ticks_usec(),"paused":paused,"simulation":GameRuntime.instance.is_processing(),"shortcuts":actor.skill_manager.shortcuts.snapshot(),"wheel":{"visible":actor.material_wheel.visible,"source":actor.material_wheel.source},"player":{"ui_blocked":actor.ui_blocked,"attacks":actor.actor_context.actions._attack_sequence,"position":[actor.position.x,actor.position.y],"hp":actor.health_component.hp,"mp":actor.mana_component.mp,"damage_taken":damage_taken,"stamina":actor.actor_context.actions.stamina.current,"mode":actor.actor_context.actions.mode,"dead":actor.health_component.is_dead,"base":game.is_at_base(),"guarding":actor.actor_context.actions.guarding,"charge_source":actor.casting._charging_source,"channel_source":actor.casting._channeling_source},"materials":actor.skill_manager.combinations.supplies.amounts,"items":game.session.inventory.entries("player.pocket"),"gear":game.session.inventory.entries("player.gear"),"pack":game.session.inventory.entries("player.pack"),"runtime_scripts":runtime_scripts(),"claims":game.progress.claims.keys(),"loot_records":game.progress.loot_records.duplicate(true),"known_actions":actor.skill_manager.known_actions,"selected":actor.skill_manager.combinations.supplies.selected,"fields":fields,"slots":slots,"hands":{"q":actor.skill_manager.left_hand.data.get_id() if actor.skill_manager.left_hand else "","r":actor.skill_manager.right_hand.data.get_id() if actor.skill_manager.right_hand else ""},"tracker":game.frontier_hud.tracker.text,"objective":game.ui.objective.text,"notice":game.ui.message.text,"modal_texts":texts,"buttons":buttons,"enemies":enemies,"casts":casts,"melee_hits":melee_hits,"defenses":defenses,"physical_actions":physical_actions,"campaign_clock":game.session.inventory.clock_seconds,"date":WorldTime.instance.stamp(),"martial":actor.actor_context.martial.snapshot(),"save_path":ProjectSettings.globalize_path("user://save_3.sav"),"display":DisplayServer.get_name()}
func move_input(direction: Vector2) -> void:
	for pair in [[KEY_D,direction.x>.35],[KEY_A,direction.x<-.35],[KEY_S,direction.y>.35],[KEY_W,direction.y<-.35]]:
		if bool(held.get(pair[0],false))!=bool(pair[1]): key_event(pair[0],pair[1])
func duel(style: String,enemy_id: String) -> String:
	var foe: Enemy
	for enemy in game.active_enemies:
		if str(enemy.get_meta("frontier_claim",""))==enemy_id: foe=enemy; break
	if not foe: return "target_missing"
	if paused or game.player.ui_blocked: return "menu_open"
	var before:=snapshot()
	var start:=active_time
	var damage_before:=damage_taken
	var next_attack:=0.0
	var next_technique:=0.0
	if style=="coat":
		await tap(KEY_E); await create_timer(1.35).timeout
		var weapon_uid: String=game.session.inventory.equipped("player").get(str(EquipmentData.SlotType.RIGHT_HAND),"")
		if not game.session.inventory.coating(weapon_uid): return "coating_not_committed"
	if style in ["throw","spray"]:
		var distance_needed:=280.0 if style=="throw" else 95.0
		while is_instance_valid(foe) and not game.player.health_component.is_dead and game.player.position.distance_to(foe.position)>distance_needed:
			if active_time-start>30: release_movement(); return "approach_timeout"
			move_input((foe.position-game.player.position).normalized()); await physics_frame
		release_movement(); aim(foe.global_position)
		var key: Key=KEY_Q if style=="throw" else KEY_1
		key_event(key,true)
		var release_at:=active_time+.65
		while active_time<release_at:
			aim(foe.global_position); await physics_frame
		key_event(key,false)
		# A released throw still has its actual stand-still preparation/recovery.
		# Do not cancel it with movement or a cast and count that as a paid tactic.
		while game.player.actor_context.actions.busy() and not game.player.health_component.is_dead and active_time-start<30: await physics_frame
		if style=="throw" and game.session.inventory.count("player","oil_bottle")==int(before.materials.get("oil_bottle",0)): return "throw_not_committed"
		if style=="spray":
			var bottle:=game.session.inventory.item(str(game.player.skill_manager.shortcuts.selection("slot_0").get("uid","")))
			if bottle and bottle.properties.doses==3: return "spray_not_committed"
	if style=="combo":
		await tap(KEY_5)
		await create_timer(1.0).timeout
		if game.player.skill_manager.combinations.live_fields().is_empty(): return "field_not_created"
	while is_instance_valid(foe) and not foe.health_component.is_dead and not game.player.health_component.is_dead:
		if active_time-start>60: release_movement(); return "combat_timeout"
		aim(foe.global_position)
		var fields:=game.player.skill_manager.combinations.live_fields()
		var use_field:=style=="combo" and not fields.is_empty()
		var distance:=game.player.global_position.distance_to(foe.global_position)
		if use_field: release_movement()
		else: move_input((foe.position-game.player.position).normalized() if distance>42 else Vector2.ZERO)
		if style in ["throw","spray"] and next_attack==0 and distance<110 and not game.player.actor_context.actions.busy():
			release_movement(); await tap(KEY_R); next_attack=active_time+.4
		if style=="martial" and active_time>=next_technique and distance<65 and not game.player.actor_context.actions.busy():
			await tap(KEY_E); next_technique=active_time+6.1; next_attack=active_time+.9
		if active_time>=next_attack and (use_field or distance<65) and not game.player.actor_context.actions.busy():
			if use_field: await tap(KEY_6)
			else: await mouse(MOUSE_BUTTON_LEFT)
			next_attack=active_time+(.25 if use_field else .65)
		await physics_frame
	release_movement()
	var end:=active_time
	last_duel={"style":style,"target":enemy_id,"seconds":end-start,"wall_seconds":float(Time.get_ticks_usec()-int(before.wall_usec))/1000000,"damage_taken":damage_taken-damage_before,"before":before,"after":snapshot(),"killed":not game.player.health_component.is_dead and (not is_instance_valid(foe) or foe.health_component.is_dead)}
	write_json("duel_"+style+".json",last_duel)
	await tap(KEY_ESCAPE)
	return "player_dead" if game.player.health_component.is_dead else ""
func defense_sample(enemy_id: String,observe_death: bool) -> String:
	var foe: Enemy
	for enemy in game.active_enemies:
		if str(enemy.get_meta("frontier_claim",""))==enemy_id: foe=enemy; break
	if not foe: return "target_missing"
	var start:=active_time
	while game.player.position.distance_to(foe.position)>48:
		if active_time-start>20 or game.player.health_component.is_dead: release_movement(); return "approach_failed"
		move_input((foe.position-game.player.position).normalized()); await physics_frame
	release_movement(); aim(foe.global_position)
	var before:=defenses.size()
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_RIGHT; press.position=root.get_mouse_position(); press.pressed=true
	Input.parse_input_event(press)
	while defenses.size()==before and not game.player.health_component.is_dead and active_time-start<25: await physics_frame
	if defenses.size()>before: await screen("defense-feedback")
	press=press.duplicate(); press.pressed=false; Input.parse_input_event(press)
	if observe_death:
		while not game.player.health_component.is_dead and not game.is_at_base() and active_time-start<60: await physics_frame
	return "" if defenses.size()>before else "no_defense_outcome"
func execute(request: Dictionary) -> void:
	var error:=""
	var op:=str(request.get("op","state"))
	match op:
		"key": await tap(OS.find_keycode_from_string(str(request.key)))
		"hold_key", "release_key":
			key_event(OS.find_keycode_from_string(str(request.key)),op=="hold_key"); await settle(2)
		"hold_mouse", "release_mouse":
			var event:=InputEventMouseButton.new(); event.position=root.get_mouse_position(); event.button_index=MOUSE_BUTTON_RIGHT if request.get("button","right")=="right" else MOUSE_BUTTON_LEFT; event.pressed=op=="hold_mouse"
			Input.parse_input_event(event); await settle(3)
		"point_click": await click_point(Vector2(request.point[0],request.point[1]))
		"wheel": error=await wheel_choice(str(request.get("key","5")),str(request.payload),str(request.get("uid","")))
		"inventory": error=await inventory_command(request)
		"technique_inspect": error=await inspect_technique(str(request.technique))
		"click": error=await click(str(request.label))
		"label_click": error=await label_click(str(request.label))
		"walk_loot":
			var record: Dictionary=game.progress.loot_records.get(str(request.get("target","river.enemy.camp.forest.3")),{})
			if record.is_empty(): error="corpse_missing"
			else: error=await walk(Vector2(record.position[0],record.position[1]),45)
		"walk": error=await walk(Vector2(request.point[0],request.point[1]),float(request.get("tolerance",24)),float(request.get("seconds",45)))
		"defense": error=await defense_sample(str(request.get("target","river.enemy.camp.forest.3")),bool(request.get("death",false)))
		"duel": error=await duel(str(request.get("style","basic")),str(request.get("target","river.enemy.camp.forest.3")))
		"aim": aim(Vector2(request.point[0],request.point[1])); await settle(2)
		"mouse": await mouse(MOUSE_BUTTON_RIGHT if request.get("button","left")=="right" else MOUSE_BUTTON_LEFT)
		"wait": await create_timer(float(request.get("seconds",1)),true).timeout
		"save":
			await tap(KEY_F5)
			var source:=ProjectSettings.globalize_path("user://save_3.sav")
			if not FileAccess.file_exists(source): error="save_missing"
			else: DirAccess.copy_absolute(source,output.path_join(str(request.get("label","checkpoint"))+".sav"))
		"capture": pass
		"quit": pass
		_: error="unknown_op" if op!="state" else ""
	var result:=snapshot(); result["id"]=request.id; result["error"]=error
	if not last_duel.is_empty(): result["duel"]=last_duel
	if request.has("capture"): await screen(str(request.capture))
	write_json("result.json",result)
	write_json("step_%04d.json"%int(request.id),{"request":request,"state":result})
	print("FIRST30 ",request.id," ",op," ",error," pos=",game.player.position," hp=",game.player.health_component.hp)
	busy=false
	if op=="quit":
		release_movement(); game.ui.close_modal(); game.queue_free(); current_scene=null
		for i in range(6): await process_frame
		quit()

func inspect_technique(id: String) -> String:
	var data:=MartialArts.definition(id)
	if not data or not game.player.actor_context.martial.learned.has(id): return "technique_not_learned"
	await tap(KEY_K); await settle(6)
	var error:=await click("武技")
	if not error.is_empty(): return error
	return await click(data.title+" · 已学")

func form_snapshot() -> Dictionary:
	var forms: Dictionary={}
	for source in QuickslotLoadout.SOURCES:
		if game.player.skill_manager.get_instance(source): forms[source]=game.player.skill_manager.selection_for_source(source)
	return forms
