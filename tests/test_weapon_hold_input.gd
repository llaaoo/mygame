extends "res://tests/support/input_scene_probe.gd"
## Actual mouse/key edges, live clocks, normal AI at a safe fixture position.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var starts: Array[Dictionary]=[]
func modifier(code: Key,held: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=held
	Input.parse_input_event(event); Input.flush_buffered_events()
func idle() -> void:
	for i in range(220):
		if game.player.actor_context.actions.mode=="idle": return
		await frames(1)
	check(false,"Physical stroke did not finish")
func ready(id := "") -> void:
	for i in range(750):
		var c:=game.player.actor_context
		if c.actions.stamina.current>=99 and (id.is_empty() or c.martial.reason(id,c).is_empty()): return
		await frames(1)
	check(false,"Natural stamina/cooldown recovery failed")
func seconds(duration: float) -> void:
	var until:=game.player.actor_context.actions.weapon_art.clock+duration
	while game.player.actor_context.actions.weapon_art.clock<until: await frames(1)
func swing(heavy := false) -> void:
	await pointer_button(MOUSE_BUTTON_LEFT,true)
	if heavy: await seconds(.36)
	await pointer_button(MOUSE_BUTTON_LEFT,false)
func power() -> void:
	await swing(); await idle(); await swing(true); await idle()
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; var c:=actor.actor_context; var actions:=c.actions; var store:=game.session.inventory
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	for id in ["river_sabre","river_spear","river_staff","river_bow"]: store.receive("player",id,1)
	store.receive_into("player.pocket","arrow",16); store.receive_into("player.pocket","fire_rag",2)
	for id in MartialArts.IDS: c.martial.learn(id)
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": starts.append(fact.data.duplicate(true)))
	await frames(12); await aim_world(actor.position+Vector2(150,0))
	store.equip("player",store.find_owned("player","river_sabre"))
	var before:=starts.size(); var stamina:=actions.stamina.current
	await pointer_button(MOUSE_BUTTON_LEFT,true); await frames(2)
	check(starts.size()==before and actions.stamina.current==stamina,"Press alone emitted a light hit or spent stamina")
	check(not actions.weapon_hold_view().is_empty() and actions.weapon_hold_view().progress>=0,"Hold feedback was missing")
	await frames(15)
	check(actions.weapon_hold_view().get("charged",false),"Hold did not cross heavy threshold")
	await capture("heavy-ready")
	await pointer_button(MOUSE_BUTTON_LEFT,false)
	check(starts.size()==before+1 and starts.back().charged and actions.combo_snapshot().is_empty(),"Long hold emitted a light or multiple attacks")
	await idle(); await frames(5)
	check(starts.size()==before+1,"Held gesture auto-repeated")
	# A tap entirely between physics ticks must still be exactly one light stroke.
	await ready(); before=starts.size()
	var tap:=InputEventMouseButton.new(); tap.button_index=MOUSE_BUTTON_LEFT; tap.pressed=true
	tap.position=root.get_screen_transform()*root.get_mouse_position(); tap.global_position=tap.position
	Input.parse_input_event(tap); tap=tap.duplicate(); tap.pressed=false; Input.parse_input_event(tap); Input.flush_buffered_events(); await frames(2)
	check(starts.size()==before+1 and not starts.back().charged,"Same-frame tap was swallowed or duplicated")
	await idle(); before=starts.size()
	# Ctrl is an art request, not a fallback heavy or ordinary strike.
	var unmatched_before:=starts.size()
	modifier(KEY_CTRL,true); await swing(); modifier(KEY_CTRL,false)
	check(starts.size()==unmatched_before,"Unmatched Ctrl+LMB fell back to a weapon attack")
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"],["river_bow","bow_aim"]]:
		store.equip("player",store.find_owned("player",pair[0])); await ready(pair[1]); await aim_world(actor.position+Vector2(150,0))
		var arrows:=store.count("player","arrow")
		await power()
		check(not actions.weapon_art_view().is_empty(),"Real tap/hold failed to open power route")
		before=starts.size()
		modifier(KEY_CTRL,true); await swing(); modifier(KEY_CTRL,false)
		check(starts.size()==before+1 and starts.back().weapon_art and not starts.back().charged and actions.profile==MartialArts.definition(pair[1]).profile,"Ctrl tap did not dispatch the light art")
		await idle(); await ready(pair[1]); await power()
		# Begin late, deliberately release after the unreserved route would expire.
		await seconds(.65); modifier(KEY_CTRL,true); await pointer_button(MOUSE_BUTTON_LEFT,true)
		before=starts.size(); var mp:=actor.mana_component.mp
		modifier(KEY_CTRL,false) # Modifier intent must stay latched at press.
		await seconds(.55)
		check(starts.size()==before and actions.weapon_hold_view().get("charged",false),"Art hold auto-fired or lost its snapshot")
		await capture("charged-art-"+MartialArts.definition(pair[1]).weapon_type)
		await pointer_button(MOUSE_BUTTON_LEFT,false)
		var data:=MartialArts.definition(pair[1])
		check(starts.size()==before+1 and starts.back().weapon_art and starts.back().charged and actions.profile.title==data.charged_profile.title,"Bounded held route expired or silently changed form")
		check(actions.profile.windup<data.charged_profile.windup and data.charged_profile.windup>.32,"Charge time was charged twice or mutated shared data")
		await idle()
		check(actor.mana_component.mp==mp and store.count("player","arrow")==arrows-(6 if pair[0]=="river_bow" else 0),"Art variants spent MP or wrong real arrow count")
		print("HOLD_ART ",JSON.stringify({"weapon":pair[0],"art":data.charged_profile.title,"stamina":actions.stamina.current,"arrows":store.count("player","arrow"),"mp":actor.mana_component.mp}))
	# Coat the actual weapon using a real item shortcut, then latch Shift at press.
	store.equip("player",store.find_owned("player","river_sabre")); await ready("blade_breaker")
	actor.skill_manager.shortcuts.bind_item("quick_e","fire_rag")
	await key(KEY_E,true); await key(KEY_E,false); await frames(90)
	var uid:=str(store.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])
	check(store.coating(uid)!=null,"Actual rag shortcut did not prepare a coating")
	await power(); modifier(KEY_CTRL,true); modifier(KEY_SHIFT,true); await pointer_button(MOUSE_BUTTON_LEFT,true)
	modifier(KEY_CTRL,false); modifier(KEY_SHIFT,false); await seconds(.36)
	check(actions.weapon_hold_view().get("release_enchantment",false) and store.coating(uid)!=null,"Modifier/source snapshot changed or hold consumed coating early")
	await pointer_button(MOUSE_BUTTON_LEFT,false)
	check(actions.mode=="attack" and store.coating(uid)!=null,"Accepted element art consumed its layer before swing")
	await idle(); check(store.coating(uid)==null,"Ctrl+Shift held art did not consume the real coating")
	# Right-button defence, UI, expiry, weapon change and control interrupt cancel without ghost release.
	for cause in ["guard","menu","timeout","weapon","interrupt","focus"]:
		await ready(); before=starts.size()
		await pointer_button(MOUSE_BUTTON_LEFT,true); await seconds(.36)
		match cause:
			"guard": await pointer_button(MOUSE_BUTTON_RIGHT,true); await pointer_button(MOUSE_BUTTON_RIGHT,false)
			"menu":
				await key(KEY_I,true); await key(KEY_I,false); await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
			"timeout": await frames(125)
			"weapon": store.equip("player",store.find_owned("player","river_staff")); await frames(2)
			"interrupt": actions.interrupt(.35); await frames(25)
			"focus": actor.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT); await frames(2)
		await pointer_button(MOUSE_BUTTON_LEFT,false); await frames(3)
		check(starts.size()==before and actions.weapon_hold_view().is_empty() and not paused,"Cancelled hold escaped through release: "+cause)
	# Saving a held gesture and restoring does not persist an input opportunity.
	await pointer_button(MOUSE_BUTTON_LEFT,true); await seconds(.36)
	await key(KEY_F5,true); await key(KEY_F5,false); await key(KEY_F9,true); await key(KEY_F9,false)
	before=starts.size(); await pointer_button(MOUSE_BUTTON_LEFT,false); await frames(3)
	check(starts.size()==before and actions.weapon_hold_view().is_empty(),"Restore revived a held mouse gesture")
	# Resized native/headless window uses the same scaled, non-interactive combat HUD.
	root.size=Vector2i(960,540); await frames(5)
	await aim_world(actor.position+Vector2(150,0)); await pointer_button(MOUSE_BUTTON_LEFT,true); await seconds(.36)
	for node in root.find_children("*","",true,false):
		if node is ActorStatusView and node.is_visible_in_tree():
			check(node.art_label.is_visible_in_tree() and node.art_label.get_global_rect().end.y<=root.get_visible_rect().end.y,"Held combat feedback overflowed the small window")
	await capture("small-window-heavy")
	await pointer_button(MOUSE_BUTTON_RIGHT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); await pointer_button(MOUSE_BUTTON_RIGHT,false)
	check(game.active_enemies.all(func(foe): return foe.can_process()),"Probe disabled normal AI")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon hold input: tap vs hold, four light/heavy arts, late-window reservation, modifier snapshot, exact arrows/coating, no auto hits, guard/UI/timeout/weapon/control/focus/save cancellation; normal AI at safe fixture position")
	quit(0 if failures.is_empty() else 1)
