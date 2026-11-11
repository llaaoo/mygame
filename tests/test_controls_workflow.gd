extends "res://tests/support/input_scene_probe.gd"
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
## Controlled UI fixture, real keyboard/mouse events, normal AI and simulation.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var casts:=0
func run() -> void:
	root.size=Vector2i(960,600)
	var fixture:=Fixture.new(self)
	game=await fixture.boot()
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player
	var manager:=actor.skill_manager
	var supplies:=game.survival.supplies
	manager.equip_source("quick_e",manager.pool.get_skill("ignite"))
	manager.equip_slot(0,manager.pool.get_skill("ignite"))
	manager.cast_committed.connect(func(_plan): casts+=1)
	var mana:=actor.mana_component.mp
	await key(KEY_E,true); await key(KEY_E,false); await frames(90)
	check(casts==1 and actor.mana_component.mp==mana-4,"E did not cast its independent shortcut")
	await key(KEY_1,true); await key(KEY_1,false); await frames(90)
	check(casts==2 and actor.mana_component.mp==mana-8,"1 did not cast its independent shortcut")
	var sequence:=actor.actor_context.actions._attack_sequence
	await click("Tab  远征菜单")
	check(not paused and game.player.ui_blocked and game.hub.page=="actions","Mouse footer did not open preparation menu")
	await capture("preparation-menu")
	await point_click(game.hub._search.get_global_rect().get_center())
	await key(KEY_E,true,101); await key(KEY_E,false)
	check(casts==2 and game.hub._search.text=="e","Typing E in a menu cast a spell or failed text entry")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	await click("Tab  远征菜单")
	await click("快捷栏编组"); await click("打开快捷栏编组")
	check(actor.skill_pool_ui.visible and not paused and game.player.ui_blocked,"Mouse preparation menu failed to open K loadout")
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
		check(not paused and game.player.ui_blocked and is_instance_valid(game.ui.modal),"Clicking nearby station failed to open crafting")
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
	await key(KEY_7,true); await key(KEY_7,false)
	check(actor.field_work.is_busy(),"7 did not begin interruptible belt use")
	await create_timer(SurvivalCatalog.FOODS.ration.seconds+.25).timeout
	check(supplies.count("ration")==food-1,"7 did not consume exactly one meal")
	await key(KEY_7,true); await key(KEY_7,false)
	check(actor.field_work.is_busy(),"Second 7 input did not use same belt slot")
	actor.field_work.cancel("test"); actor.field_work.close_panel()
	check(supplies.count("ration")==food-1,"Cancelling food use consumed food")
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
	await click("快捷槽 5：5"); await key(KEY_H,true); await key(KEY_H,false)
	check(InputMap.action_has_event("skill_5",InputBindings.decode({"key":KEY_H})),"Real binding editor did not save new key: "+InputBindings.labels("skill_5"))
	await click("恢复默认键位")
	check(InputMap.action_has_event("skill_5",InputBindings.decode({"key":KEY_5})) and InputMap.action_has_event("cast_e",InputBindings.decode({"key":KEY_E})),"Mouse reset did not restore gameplay defaults")
	check(game.progress.claims==claims and game.session.inventory.snapshot()==inventory,"Reset controls changed world progress or inventory")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	await fixture.close()
	if failures.is_empty(): print("PASS controls workflow: independent E/1 exactly once, mouse menus/loadout/workbench/belt, remap/reset, text ownership, material payment and stale range rejection; normal AI")
	quit(0 if failures.is_empty() else 1)
