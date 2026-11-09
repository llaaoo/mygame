extends "res://tests/support/input_scene_probe.gd"
## Real scene transitions and key/mouse events. Sandbox kit/positions are explicitly controlled, AI stays normal.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func animation_capture(name: String) -> void:
	await capture(name)
	if DisplayServer.get_name()!="headless": print("ANIMATION_CAPTURE ",name," ",Time.get_ticks_msec())
func wait_scene(kind: String) -> Node:
	for i in range(300):
		var scene:=current_scene
		if kind=="gallery" and scene is AnimationGallery: return scene
		if kind=="sandbox" and scene is AnimationSandbox and scene.demo_ready: return scene
		if kind=="game" and scene is GrayriverGame and not scene is AnimationSandbox and scene.ready_for_play: return scene
		await frames(1)
	check(false,"Scene did not become ready: "+kind); return current_scene
func seconds(duration: float) -> void:
	var until:=game.player.actor_context.actions.weapon_art.clock+duration
	while game.player.actor_context.actions.weapon_art.clock<until: await frames(1)
func idle() -> void:
	for i in range(180):
		if game.player.actor_context.actions.mode=="idle": return
		await frames(1)
	check(false,"Actual physical action failed to finish")
func modifier(code: Key,held: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=held
	Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var original_arrows:=game.session.inventory.count("player","arrow")
	var original_gear:=game.session.inventory.equipped("player").duplicate()
	await key(KEY_TAB,true); await key(KEY_TAB,false)
	await click("操作设置"); await click("动画与素材演示"); await click("打开动画试验室")
	var gallery:=await wait_scene("gallery") as AnimationGallery
	var saved_hash:=FileAccess.get_sha256("user://save_3.sav")
	check(not saved_hash.is_empty() and gallery.rigs.size()==3,"In-game entry did not save the journey/open three preview rigs")
	game=null
	await frames(8)
	await click("东"); await click("自动播放")
	await click("移动"); await click("东"); await frames(5)
	print("GALLERY_CONTROLS ",JSON.stringify({"direction":gallery.direction,"autoplay":gallery.autoplay,"state":gallery.state}))
	check(gallery.direction==6 and not gallery.autoplay and gallery.state=="walk","Actual gallery controls did not change direction/action/playback")
	var slider:=gallery.scrub; var point:=slider.get_global_rect().position+Vector2(slider.size.x*.7,slider.size.y*.5)
	await point_click(point); await frames(3)
	print("GALLERY_SCRUB ",JSON.stringify({"progress":gallery.progress,"directions":gallery.rigs.map(func(rig): return rig.current.get("direction",-1))}))
	check(gallery.progress>.5 and gallery.rigs.all(func(rig): return rig.current.get("direction",-1)==6),"Actual scrub/direction failed to reach native sprite players")
	await animation_capture("animation-gallery")
	await click("死亡"); await click("南")
	await point_click(slider.get_global_rect().position+Vector2(slider.size.x*.99,slider.size.y*.5)); await frames(3)
	check(gallery.rigs.all(func(rig): return rig.current.get("state","")=="death"),"Actual death preview did not reach all native rigs")
	await animation_capture("animation-gallery-death")
	root.size=Vector2i(960,540); await frames(6); await animation_capture("animation-gallery-small")
	await click("02 武器与连招实战")
	game=await wait_scene("sandbox") as AnimationSandbox
	check(game.demo_mode=="combat" and SaveManager.instance.repository is AnimationSandbox.MemoryRepository and game.active_enemies.all(func(enemy): return enemy.can_process()),"Demo failed to isolate its save repository or disabled AI")
	root.size=Vector2i(1152,648); await frames(10)
	var actor:=game.player; var actions:=actor.actor_context.actions; var rig: ActorAnimationController=(actor.get_node("EquipmentVisual") as ActorEquipmentVisual).animator
	await aim_world(actor.position+Vector2(150,0))
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); await frames(1)
	check(actions.mode=="attack" and rig.current.get("state","")=="slash","Actual short click did not animate the accepted physical slash")
	await animation_capture("animation-combat-strike")
	await idle(); await pointer_button(MOUSE_BUTTON_LEFT,true); await seconds(.36)
	check(rig.current.get("state","")=="charge","Actual hold gave no charge pose")
	await aim_world(actor.position+Vector2(-150,0)); await frames(1)
	check(rig.current.get("direction",-1)==2 and actions.weapon_hold_view().get("charged",false),"Mouse motion did not turn the held pose without releasing it")
	await aim_world(actor.position+Vector2(150,0)); await frames(1)
	await animation_capture("animation-combat-charge")
	await pointer_button(MOUSE_BUTTON_LEFT,false); await frames(1)
	check(rig.current.get("state","")=="slash_heavy","Heavy input failed to select its authored heavy pose")
	await idle(); modifier(KEY_CTRL,true); await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); modifier(KEY_CTRL,false)
	await frames(1)
	check(actions.mode=="attack" and actions.technique_status().contains("破势斩"),"Mouse art did not use the actual learned combo route")
	await animation_capture("animation-combat-art"); await idle()
	await click("长矛"); await aim_world(actor.position+Vector2(150,0)); await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); await frames(1)
	check(rig.current.get("state","")=="thrust" and actions.profile.motion=="thrust","Changing the actual weapon did not change the animation semantic")
	await idle(); await key(KEY_F5,true); await key(KEY_F5,false); await key(KEY_F9,true); await key(KEY_F9,false)
	check(FileAccess.get_sha256("user://save_3.sav")==saved_hash and rig.current.get("state","")=="idle","Demo save/restore touched the formal slot or retained an action")
	await key(KEY_O,true); await key(KEY_O,false); await animation_capture("animation-paper-doll"); await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	await click("开始对练（正常AI）"); await seconds(.3)
	check(game.active_enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.story_truce and enemy.position.distance_to(actor.position)<220 and enemy.can_process()),"Duel button did not bring a normal hostile AI into the scene")
	await animation_capture("animation-combat-ai")
	await click("素材浏览"); gallery=await wait_scene("gallery") as AnimationGallery
	await click("03 施法与取消实战"); game=await wait_scene("sandbox") as AnimationSandbox
	actor=game.player; rig=(actor.get_node("EquipmentVisual") as ActorEquipmentVisual).animator
	var casts: Array[String]=[]
	actor.skill_manager.cast_committed.connect(func(plan: CastPlan): casts.append(plan.skill.get_id()))
	var store:=game.session.inventory; var stones:=store.count("player","fire_stone"); var mana:=actor.mana_component.mp
	await aim_world(actor.position+Vector2(150,0)); await key(KEY_Q,true); await key(KEY_Q,false)
	check(rig.current.get("state","")=="cast" and not actor.skill_manager.combinations.pending.is_empty(),"Real timed rune preparation did not animate")
	await animation_capture("animation-cast-preparation")
	await seconds(1)
	check(actor.skill_manager.combinations.fields.any(func(field): return is_instance_valid(field) and field.field_type=="fire") and store.count("player","fire_stone")==stones-1,"Demo rune did not use the real material transaction")
	await key(KEY_E,true); await key(KEY_E,false); await seconds(.4)
	check(actor.mana_component.mp<mana and casts.has("fireball"),"Real rune/ignite combination did not commit")
	print("DEMO_CASTS ",JSON.stringify(casts))
	await animation_capture("animation-cast-release")
	check(FileAccess.get_sha256("user://save_3.sav")==saved_hash,"Preview/sandbox rewrote the formal saved journey")
	await click("返回正式旅程"); game=await wait_scene("game") as GrayriverGame
	game.ui.close_modal(); await frames(4)
	check(not SaveManager.instance.repository is AnimationSandbox.MemoryRepository and game.session.inventory.count("player","arrow")==original_arrows and game.session.inventory.equipped("player")==original_gear,"Returning from demo leaked kit, repository or equipment into the formal journey")
	game.queue_free(); current_scene=null; await frames(8)
	if failures.is_empty(): print("PASS animation demo input: in-game saved entry, native gallery direction/action/scrub and small window, real light/hold/art/weapon switch, normal AI, in-memory F5/F9, real fire-stone combo and formal-journey UID/kit preservation; controlled demo starting kit/location")
	quit(0 if failures.is_empty() else 1)
