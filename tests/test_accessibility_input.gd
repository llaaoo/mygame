extends "res://tests/support/input_scene_probe.gd"
## Actual settings controls, live world and persistent menu bindings; no gamepad scope.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; actor.position=Vector2(-4000,800)
	actor.get_node("Camera2D").reset_smoothing(); await frames(4)
	var camera:=actor.get_node("Camera2D"); var zoom: Vector2=camera.zoom
	var store:=game.session.inventory; var stock:=store.material_amounts("player")
	var original:=float(PresentationPreferences.value("text_scale"))
	var clock:=store.clock_seconds
	await key(KEY_TAB,true); await key(KEY_TAB,false)
	await click("操作设置"); await click("画面、动效与声音")
	var picker:=game.ui.modal.find_child("TextScale",true,false) as HBoxContainer
	check(picker!=null,"Text size control missing")
	if not picker: await fixture.close(); quit(1); return
	await click("125%")
	check(is_equal_approx(float(PresentationPreferences.value("text_scale")),1.25),"Actual font-size picker did not save 125%")
	if not is_equal_approx(float(PresentationPreferences.value("text_scale")),1.25):
		print("Font value=",PresentationPreferences.value("text_scale"))
		await fixture.close();quit(1);return
	var labels:=game.ui.modal.find_children("*","Label",true,false)
	check(labels.any(func(label):return label.has_meta("ui_base_font_size") and label.get_theme_font_size("font_size")==roundi(int(label.get_meta("ui_base_font_size"))*1.25)),"Existing view did not update styled fonts immediately")
	check(camera.zoom==zoom and store.material_amounts("player")==stock and not paused,"Font settings changed world zoom/resources or paused simulation")
	var disk_before:=FileAccess.get_file_as_string(PresentationPreferences.PATH)
	var theme_before:=root.theme
	DirAccess.make_dir_absolute(PresentationPreferences.PATH+".tmp")
	check(not GameUIStyle.set_text_scale(1.1,root) and root.theme==theme_before and is_equal_approx(float(PresentationPreferences.value("text_scale")),1.25),"Failed font preference write changed theme or runtime setting")
	check(FileAccess.get_file_as_string(PresentationPreferences.PATH)==disk_before,"Failed preference write damaged prior saved bytes")
	DirAccess.remove_absolute(PresentationPreferences.PATH+".tmp")
	await capture("readable-fonts-125")
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	check(is_instance_valid(game.ui.modal),"System reading panel did not open")
	if not is_instance_valid(game.ui.modal):await fixture.close();quit(1);return
	var reading:=game.ui.modal.find_children("*","RichTextLabel",true,false)
	check(not reading.is_empty() and reading.all(func(label):return label.get_theme_font_size("normal_font_size")==19),"Main reading/dialogue text ignored font scale")
	check(game.frontier_hud.tracker.get_theme_font_size("font_size")==18,"Persistent HUD text ignored font scale")
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	await key(KEY_TAB,true);await key(KEY_TAB,false);await click("操作设置")
	await click("施法与快捷操作")
	await click("地图："+InputBindings.label("menu_map"))
	await key(KEY_U,true); await key(KEY_U,false)
	check(InputBindings.label("menu_map")=="U","Actual mapping control did not bind the map menu")
	check(game.presenter.journal_text().contains("U地图"),"Journal instructions retained the retired map key")
	var map_route:=game.ui.modal.find_child("Route_map",true,false) as Button
	check(map_route!=null and map_route.tooltip_text.begins_with("U"),"Navigation tooltip retained the retired map key")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	await key(KEY_U,true); await key(KEY_U,false)
	check(is_instance_valid(game.ui.modal) and game.ui.modal.find_children("*","Control",true,false).any(func(node):return node is GrayriverMap),"Rebound map input did not open actual map")
	await key(KEY_U,true); await key(KEY_U,false)
	check(not is_instance_valid(game.ui.modal),"Rebound map input did not close actual map")
	await key(KEY_M,true); await key(KEY_M,false)
	check(not is_instance_valid(game.ui.modal) and not actor.ui_blocked,"Old map key still opened a menu after rebinding")
	InputBindings.loaded=false; InputBindings.install()
	check(InputBindings.menu_key(InputBindings._key(KEY_U))==KEY_M,"Saved menu mapping did not survive reinstall")
	check(store.clock_seconds>clock and game.active_enemies.all(func(enemy):return enemy.can_process()),"Accessibility controls stopped normal AI/world time")
	GameUIStyle.set_text_scale(original,root); InputBindings.reset_defaults()
	await fixture.close()
	if failures.is_empty(): print("PASS accessibility input: actual 125% text picker, live existing text, same world zoom/resources, actual menu remap/open/close, retired key and persisted InputMap with normal AI")
	quit(0 if failures.is_empty() else 1)
