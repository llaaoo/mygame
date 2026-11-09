extends "res://tests/support/input_scene_probe.gd"
## Real inputs and live simulation; lab kit/knowledge/site positions are explicitly staged.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func wait_work() -> void:
	for i in range(500):
		if not game.player.field_work.is_busy(): return
		await frames(1)
	check(false,"Actual field work did not finish")
func visual_capture(name: String) -> void:
	await capture(name)
	if DisplayServer.get_name()!="headless": print("PRESENTATION_CAPTURE ",name," ",Time.get_ticks_msec())
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var original_gear:=game.session.inventory.equipped("player").duplicate()
	var original_herbs:=game.session.inventory.count("player","herb")
	var original_motion: bool=PresentationPreferences.value("reduced_motion")
	await key(KEY_TAB,true); await key(KEY_TAB,false); await click("操作设置"); await click("画面、动效与声音")
	var elapsed:=game.session.inventory.clock_seconds; await frames(18)
	check(not paused and game.player.ui_blocked and game.session.inventory.clock_seconds>elapsed,"Presentation settings paused the world")
	await visual_capture("presentation-settings")
	await click("打开整体表现试验场")
	var lab: PresentationLab
	for i in range(300):
		if current_scene is PresentationLab and current_scene.demo_ready and current_scene.sites.size()==4: lab=current_scene; break
		await frames(1)
	check(lab!=null,"In-game presentation lab failed to mount real sites")
	if not lab: quit(1); return
	game=lab
	var formal_hash:=FileAccess.get_sha256("user://save_3.sav")
	check(SaveManager.instance.repository is AnimationSandbox.MemoryRepository and game.active_enemies.all(func(enemy): return enemy.can_process()),"Lab isolation or normal AI failed")
	check(lab.sites.water.presentation.has_body_art() and lab.sites.water.presentation.profile.visual_scene!=null,"Real well did not use the registered native art resource")
	await click("日景对照"); await frames(8); await visual_capture("presentation-day")
	var hour:=WorldTime.instance.get_hour()
	await click("夜景对照"); await frames(8); await visual_capture("presentation-night")
	check(lab.presentation.environment.preview_hour==23 and absf(WorldTime.instance.get_hour()-hour)<.1,"Cosmetic day/night preview advanced authoritative world time")
	await click("恢复真实时刻")
	if PresentationPreferences.value("reduced_motion"): await click("减少动态效果")
	await click("减少动态效果"); await frames(4)
	check(PresentationPreferences.value("reduced_motion") and lab.presentation.camera_feedback.camera.offset.is_zero_approx(),"Real motion toggle did not disable cosmetic camera feedback")
	await click("靠近采集点"); await frames(6)
	var herbs:=game.session.inventory.count("player","herb")
	await key(KEY_F,true); await key(KEY_F,false)
	check(game.player.field_work.panel.visible,"F did not inspect the actual harvest point")
	await point_click(game.player.field_work.panel.start_button.get_global_rect().get_center())
	check(game.player.field_work.is_busy(),"Real start button failed to begin harvest")
	await frames(2)
	var rig: ActorAnimationController=(game.player.get_node("EquipmentVisual") as ActorEquipmentVisual).animator
	check(rig.current.get("state")=="work_gather","Real harvest did not animate the actor's non-combat work")
	await visual_capture("presentation-harvest-work"); await wait_work(); await frames(12)
	check(game.session.inventory.count("player","herb")>herbs and lab.sites.forage.presentation.snapshot.state=="depleted","Harvest visual did not follow the paid live resource result")
	await visual_capture("presentation-harvest-depleted")
	await click("减少动态效果"); await click("靠近机关"); await frames(6)
	var sap:=game.session.inventory.count("player","sap"); var charcoal:=game.session.inventory.count("player","charcoal")
	await key(KEY_F,true); await key(KEY_F,false)
	check(game.player.field_work.panel.visible,"F did not inspect the actual mechanism")
	await point_click(game.player.field_work.panel.start_button.get_global_rect().get_center())
	check(game.player.field_work.is_busy(),"Actual mechanism work was refused")
	await frames(2); check(rig.current.get("state")=="work_craft","Real mechanism work did not animate the actor's hands")
	await visual_capture("presentation-mechanism-work")
	await wait_work(); await frames(9)
	check(lab.sites.puzzle.completed and lab.sites.puzzle.presentation.snapshot.state=="complete" and game.session.inventory.count("player","sap")==sap-2 and game.session.inventory.count("player","charcoal")==charcoal-1,"Mechanism pose or real material transaction failed")
	check(lab.presentation.audio.played>0,"Committed world/UI events did not reach native audio playback")
	await visual_capture("presentation-mechanism-complete")
	var after_herbs:=game.session.inventory.count("player","herb")
	await key(KEY_F5,true); await key(KEY_F5,false); await key(KEY_F9,true); await key(KEY_F9,false); await frames(15)
	check(lab.sites.forage.presentation.snapshot.state=="depleted" and lab.sites.puzzle.presentation.snapshot.state=="complete" and game.session.inventory.count("player","herb")==after_herbs,"Save/reentry replayed harvest or lost terminal visual state")
	check(FileAccess.get_sha256("user://save_3.sav")==formal_hash,"Whole-game lab modified the formal journey")
	root.size=Vector2i(960,600); await frames(6); await click("表现设置"); await visual_capture("presentation-small-window")
	check(not paused and game.player.ui_blocked,"Small-window presentation preferences stopped simulation")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	PresentationPreferences.set_option("reduced_motion",original_motion)
	await click("返回正式旅程")
	for i in range(300):
		if current_scene is GrayriverGame and not current_scene is AnimationSandbox and current_scene.ready_for_play: game=current_scene; break
		await frames(1)
	check(not SaveManager.instance.repository is AnimationSandbox.MemoryRepository and game.session.inventory.equipped("player")==original_gear and game.session.inventory.count("player","herb")==original_herbs and not game.progress.claims.has("valley.bridge_beams"),"Lab materials/knowledge/equipment leaked into the formal journey")
	game.ui.close_modal(); game.queue_free(); current_scene=null; await frames(6)
	if failures.is_empty(): print("PASS presentation input: real settings and non-pausing world, cosmetic daylight, staged existing sites with actual F/mouse timed harvest and paid puzzle, native sensory cues, reduced motion, small window, F5/F9 terminal states and formal-journey isolation; normal AI")
	quit(0 if failures.is_empty() else 1)
