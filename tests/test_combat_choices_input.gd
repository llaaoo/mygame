extends "res://tests/support/input_scene_probe.gd"
## Normal simulation/AI; shop location, full bags and known spells are fixtures.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; var store:=game.session.inventory
	store.receive("player","river_staff",1)
	var worn:=store.find_owned("player","river_staff")
	store.equip("player",worn)
	actor.actor_context.martial.learn("staff_sweep")
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing()
	await frames(10); await key(KEY_F,true); await key(KEY_F,false)
	var staff_title: String=store.definitions.river_staff.display_name
	await click(staff_title+" ×1 · 8币")
	check(game.town_services._screen.detail.find_children("*","Label",true,false).any(func(label): return label.text.contains("仍在身上")),"Worn equipment was invisible or lacked a sale explanation")
	await capture("shop-worn-item")
	await click("卸下这件装备")
	await click("出售一件 · 8币")
	check(store.locate(worn)==TownServices.MERCHANT+".pack" and store.count("player","coin")==8,"Real unequip/sell did not transfer the selected UID and actual payment")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	# Configure the two route slots through actual K-page buttons.
	await key(KEY_K,true); await key(KEY_K,false)
	await click("武技"); await click("压阵横扫 · 已学")
	await click("移除此招")
	check(actor.actor_context.martial.route_slots("staff:light/heavy").size()==1,"K-page removal failed")
	await click("装备到连招槽2")
	check(actor.actor_context.martial.route_slots("staff:light/heavy")==["staff_sweep/power_followup","staff_sweep/power"],"K-page equipment did not retain exactly the two chosen arts")
	await capture("two-art-loadout")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	store.pay("player",{"coin":store.count("player","coin")})
	store.receive("player","river_spear",1)
	var sale:=store.find_owned("player","river_spear")
	store.receive_into("player.pack","river_sabre",100)
	store.receive_into("player.pocket","river_shield",100)
	check(store.space("player.pack","coin")==0 and store.space("player.pocket","coin")==0,"Full-bag fixture still had a payment slot")
	var funds:=store.count(TownServices.MERCHANT,"coin")
	await key(KEY_F,true); await key(KEY_F,false)
	await click(str(store.definitions.river_spear.display_name)+" ×1 · 8币")
	await capture("shop-full-bag-sale")
	await click("出售一件 · 8币")
	check(store.locate(sale)==TownServices.MERCHANT+".pack" and store.count("player","coin")==8 and store.count(TownServices.MERCHANT,"coin")==funds-8,"Actual full-bag sale failed, substituted a UID or minted coins")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	# Free controlled test stock, then lose a real material while holding the wheel.
	store.pay("player",{"river_shield":store.count("player","river_shield")})
	store.receive_into("player.pocket","frost_salt",1)
	game.progress.actions["water_call"]=true; game._apply_knowledge()
	actor.skill_manager.equip_source("quick_e",actor.skill_manager.pool.get_skill("water_call"),{"payload":"","modifier":"","uid":""})
	await pointer_button(MOUSE_BUTTON_MIDDLE,true)
	await key(KEY_E,true); await key(KEY_E,false)
	var wheel:=actor.material_wheel
	var index:=-1
	for i in range(wheel.entries.size()):
		if wheel.entries[i].get("choice",{}).get("modifier","")=="frost_salt": index=i
	check(index>=0,"Available real material missing from live wheel")
	if index>=0:
		var point:=wheel._ring.position+Vector2(180,180)+Vector2.from_angle(-PI/2+(index%8)*TAU/8)*125
		var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
		root.push_input(motion,true); await frames(2)
		check(wheel.hovered==index%8,"Real pointer did not hover the material sector")
		var selection:=actor.skill_manager.shortcuts.selection("quick_e")
		store.pay("player",{"frost_salt":1})
		await create_timer(.3).timeout
		check(wheel.entries[index].is_empty() and wheel.hovered==-1,"Lost readiness remapped a held pointer to another form")
		await capture("wheel-lost-material")
		await pointer_button(MOUSE_BUTTON_MIDDLE,false)
		check(not wheel.visible and actor.skill_manager.shortcuts.selection("quick_e")==selection,"Releasing a stale sector silently changed the slot")
	else: await pointer_button(MOUSE_BUTTON_MIDDLE,false)
	root.size=Vector2i(960,600); await frames(5)
	await key(KEY_F,true); await key(KEY_F,false)
	var detail:=game.town_services._screen.detail
	check(detail.size.x<=(detail.get_parent() as ScrollContainer).size.x,"Shop detail buttons pushed text beyond the visible column")
	for label in detail.find_children("*","Label",true,false):
		if label.is_visible_in_tree(): check(label.size.x<=detail.size.x+1,"Shop label escaped its detail column")
	print("SHOP_LAYOUT ",JSON.stringify({"detail_width":detail.size.x,"host_width":(detail.get_parent() as ScrollContainer).size.x,"labels":detail.find_children("*","Label",true,false).map(func(label): return {"text":label.text.left(12),"width":label.size.x,"wrap":label.autowrap_mode})}))
	await capture("shop-small-window")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not paused,"Live shop/wheel paused the world")
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	check(game.session.inventory.locate(worn)==TownServices.MERCHANT+".pack" and game.session.inventory.locate(sale)==TownServices.MERCHANT+".pack" and game.session.inventory.count("player","coin")==8,"Save/re-entry duplicated sales, payment or item identity")
	check(game.player.actor_context.martial.route_slots("staff:light/heavy")==["staff_sweep/power_followup","staff_sweep/power"],"Save/re-entry lost the configured art order")
	await fixture.close()
	if failures.is_empty(): print("PASS combat choices input: F shop worn/unequip/sell, actual full-bag payment/UID conservation, held wheel material loss without substitution, live normal simulation and real save/re-entry; controlled stock/location")
	quit(0 if failures.is_empty() else 1)
