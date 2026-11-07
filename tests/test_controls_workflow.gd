extends SceneTree
## Controlled UI fixture, real keyboard/mouse events, normal AI and simulation.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var casts:=0
var game: GrayriverGame
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func key(code: Key,held: bool,unicode_value:=0) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=held; event.unicode=unicode_value
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
func point_click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	root.push_input(motion,true); Input.flush_buffered_events(); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	root.push_input(event,true); Input.flush_buffered_events(); await frames()
	event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames()
func click(text: String) -> void:
	var found: Button
	for node in root.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and (node.text==text or node.text.begins_with(text+"\n")): found=node; break
	check(found!=null,"Missing visible button: "+text)
	if not found: return
	var ancestor:=found.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(found)
		ancestor=ancestor.get_parent()
	await frames()
	await point_click(found.get_global_rect().get_center())
func capture(name: String) -> void:
	var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(960,600)
	var fixture:=Fixture.new(self)
	game=await fixture.boot()
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player
	var manager:=actor.skill_manager
	var supplies:=game.survival.supplies
	manager.equip_slot(0,manager.pool.get_skill("ignite"))
	manager.cast_committed.connect(func(_plan): casts+=1)
	var mana:=actor.mana_component.mp
	await key(KEY_E,true); await key(KEY_E,false); await frames(90)
	check(casts==1 and actor.mana_component.mp==mana-4,"E did not cast once from slot 1")
	await key(KEY_1,true); await key(KEY_1,false); await frames(90)
	check(casts==2 and actor.mana_component.mp==mana-8,"1 alias did not cast the same slot once")
	var sequence:=actor.actor_context.actions._attack_sequence
	await click("Tab  远征菜单")
	check(paused and game.hub.page=="actions","Mouse footer did not open preparation menu")
	await capture("preparation-menu")
	await point_click(game.hub._search.get_global_rect().get_center())
	await key(KEY_E,true,101); await key(KEY_E,false)
	check(casts==2 and game.hub._search.text=="e","Typing E in a menu cast a spell or failed text entry")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	await click("Tab  远征菜单")
	await click("技能编组"); await click("打开技能编组")
	check(actor.skill_pool_ui.visible and paused,"Mouse preparation menu failed to open K loadout")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not paused and not actor.ui_blocked,"Loadout close did not return to gameplay")
	# Real nearby station, no new remote crafting authority. Fixture supplies are explicit.
	var bench: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.callback==game.workshop.show_crafts: bench=node; break
	check(bench!=null,"Town workbench missing")
	if bench:
		actor.position=bench.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(18)
		check(game.frontier_hud.interact.is_visible_in_tree(),"Nearby mouse interaction hidden")
		await point_click(game.frontier_hud.interact.get_global_rect().get_center())
		check(paused and is_instance_valid(game.ui.modal),"Clicking nearby station failed to open crafting")
		game.ui.close_modal()
		var recipe:=supplies.crafting_recipes["fire_stone"] as CraftingRecipe
		supplies.known_recipes["fire_stone"]=true; supplies.grant(recipe.inputs)
		var before:=supplies.count("fire_stone")
		var raw: Dictionary={}
		for id in recipe.inputs: raw[id]=supplies.count(id)
		await click("Tab  远征菜单"); await click("制作配方"); await click("使用附近工作台")
		await click("加工："+supplies.title("fire_stone"))
		check(supplies.count("fire_stone")==before+recipe.output_count,"Mouse crafting did not produce actual fire stone")
		for id in recipe.inputs: check(supplies.count(id)==raw[id]-recipe.inputs[id],"Mouse crafting charged incorrect material: "+id)
		await capture("mouse-workbench")
		game.ui.close_modal()
		actor.position+=Vector2(250,0); await frames()
		check(not actor.input_controller.request_interaction(bench) and not paused,"Stale mouse target opened a distant station")
	supplies.grant({"ration":3})
	var food:=supplies.count("ration")
	await key(KEY_Z,true); await key(KEY_Z,false)
	check(actor.field_work.is_busy(),"Z did not begin interruptible belt use")
	await create_timer(SurvivalCatalog.FOODS.ration.seconds+.25).timeout
	check(supplies.count("ration")==food-1,"Z did not consume exactly one meal")
	await key(KEY_7,true); await key(KEY_7,false)
	check(actor.field_work.is_busy(),"7 alias did not use same belt slot")
	actor.field_work.cancel("test"); actor.field_work.close_panel()
	check(supplies.count("ration")==food-1,"Cancelling alias use consumed food")
	await frames(14)
	await point_click(game.frontier_hud.belt[0].get_global_rect().get_center())
	check(actor.field_work.is_busy(),"Mouse belt did not begin same survival action")
	actor.field_work.cancel("test"); actor.field_work.close_panel()
	check(actor.actor_context.actions._attack_sequence==sequence,"Mouse menu, interaction or belt click leaked a melee attack")
	await frames(14)
	await capture("world-controls")
	var claims:=game.progress.claims.duplicate(true)
	var inventory:=game.session.inventory.snapshot()
	await click("Tab  远征菜单"); await click("操作设置")
	await click("基础动作 5：5"); await key(KEY_H,true); await key(KEY_H,false)
	check(InputMap.action_has_event("skill_5",InputBindings.decode({"key":KEY_H})),"Real binding editor did not save new key: "+InputBindings.labels("skill_5"))
	await click("恢复默认键位")
	check(InputMap.action_has_event("skill_5",InputBindings.decode({"key":KEY_5})) and InputMap.action_has_event("skill_1",InputBindings.decode({"key":KEY_E})),"Mouse reset did not restore gameplay defaults")
	check(game.progress.claims==claims and game.session.inventory.snapshot()==inventory,"Reset controls changed world progress or inventory")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	await fixture.close()
	if failures.is_empty(): print("PASS controls workflow: E/1 exactly once, mouse menus/loadout/workbench/belt, remap/reset, text ownership, material payment and stale range rejection; normal AI")
	quit(0 if failures.is_empty() else 1)
