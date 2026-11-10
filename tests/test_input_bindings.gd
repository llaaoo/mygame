extends SceneTree
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func event(code: Key) -> InputEventKey:
	var key:=InputEventKey.new(); key.keycode=code; key.physical_keycode=code
	return key
func has_key(action: String,code: Key) -> bool:
	return InputMap.action_has_event(action,event(code))
func run() -> void:
	# Preferences must load even before any Player has registered its extra slots.
	var config:=ConfigFile.new()
	config.set_value("bindings","skill",{"mouse":MOUSE_BUTTON_RIGHT})
	config.set_value("bindings","interact",{"key":KEY_E})
	config.set_value("bindings","guard",{"key":KEY_V})
	config.set_value("bindings","skill_5",{"key":KEY_H})
	config.set_value("bindings","skill_6",{"key":KEY_Y})
	check(config.save(InputBindings.PATH)==OK,"Could not stage isolated binding preferences")
	InputBindings.install()
	for action in InputBindings.KEYS:
		check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),"Missing default input: "+action)
	for pair in [["skill_5",KEY_H],["skill_6",KEY_Y]]:
		var key:=event(pair[1]); key.pressed=true
		Input.parse_input_event(key); Input.flush_buffered_events(); await process_frame
		check(Input.is_action_pressed(pair[0]),"First boot skipped saved input for "+pair[0])
		key=key.duplicate(); key.pressed=false; Input.parse_input_event(key); await process_frame
	check(InputMap.action_get_events("skill")[0] is InputEventKey and InputMap.action_get_events("guard")[0] is InputEventMouseButton,"Old mouse casting / V guard defeated layout")
	check(has_key("interact",KEY_F),"Legacy E interaction defeated F default")
	var reserved:=InputEventMouseButton.new(); reserved.button_index=MOUSE_BUTTON_LEFT
	check(not InputBindings.assign("skill_1",reserved).accepted,"Rebinding allowed a skill to steal left mouse")
	check(not InputBindings.assign("skill_1",event(KEY_CTRL)).accepted,"Plain Ctrl was not reserved for art cycling")
	check(not InputBindings.assign("skill_1",event(KEY_K)).accepted,"Remap stole a global menu shortcut")
	check(not InputBindings.assign("skill_1",event(KEY_M)).accepted and not InputBindings.assign("skill_1",event(KEY_G)).accepted,"Remap stole map/selector menu keys")
	check(not InputBindings.assign("skill_1",event(KEY_F)).accepted,"Remap duplicated world interaction")
	var before:=InputMap.action_get_events("skill_5").size()
	InputBindings.install()
	check(InputMap.action_get_events("skill_5").size()==before,"Repeated scene entries duplicated input events")
	# v2 saved defaults migrate; valid customized E and swapped keys survive together.
	config=ConfigFile.new(); config.set_value("layout","version",2)
	config.set_value("bindings","loot_all",{"key":KEY_E})
	config.set_value("bindings","skill_1",{"key":KEY_1})
	config.set_value("bindings","skill_5",{"key":KEY_E})
	config.set_value("bindings","skill_2",{"key":KEY_3})
	config.set_value("bindings","skill_3",{"key":KEY_2})
	config.save(InputBindings.PATH); InputBindings.loaded=false; InputBindings.install()
	check(has_key("loot_all",KEY_T) and has_key("skill_1",KEY_1) and not has_key("skill_1",KEY_E) and has_key("skill_5",KEY_E),"Migration lost custom E or retained a conflicting default")
	check(has_key("skill_2",KEY_3) and has_key("skill_3",KEY_2),"Saved key swap depends on config entry order")
	check(InputBindings.assign("loot_all",event(KEY_E)).accepted,"World and loot contexts cannot intentionally share a key")
	check(InputBindings.reset_defaults().accepted,"Reset could not persist defaults")
	InputBindings.loaded=false; InputBindings.install()
	check(has_key("cast_e",KEY_E) and not has_key("skill_1",KEY_E) and has_key("skill_1",KEY_1) and has_key("loot_all",KEY_T),"Reset/restart did not separate E and 1")
	check(has_key("quick_item_1",KEY_7) and not has_key("quick_item_1",KEY_Z) and has_key("quick_item_2",KEY_8) and not has_key("quick_item_2",KEY_X),"Numbered shortcuts still carry implicit aliases")
	# The previous v3 E/1 alias is replaced by independent default sources.
	config=ConfigFile.new(); config.set_value("layout","version",3)
	config.set_value("bindings","skill_1",{"key":KEY_E}); config.save(InputBindings.PATH)
	InputBindings.loaded=false; InputBindings.install()
	check(has_key("cast_e",KEY_E) and has_key("skill_1",KEY_1) and not has_key("skill_1",KEY_E),"v3 saved alias overrode independent E/1 defaults")
	# v6 default Ctrl-heavy becomes a mouse gesture; intentional custom keys survive.
	config=ConfigFile.new(); config.set_value("layout","version",6)
	config.set_value("bindings","heavy_attack",{"mouse":MOUSE_BUTTON_LEFT,"ctrl":true})
	config.set_value("bindings","weapon_art",{"key":KEY_V}); config.save(InputBindings.PATH)
	InputBindings.loaded=false; InputBindings.install()
	var art:=InputEventMouseButton.new(); art.button_index=MOUSE_BUTTON_LEFT; art.ctrl_pressed=true
	check(InputMap.action_get_events("heavy_attack").is_empty() and InputMap.action_has_event("weapon_art",art),"v6 default Ctrl-heavy defeated new mouse arts")
	check(not InputBindings.assign("cast_e",art,false).accepted,"Shortcut stole the reserved mouse art gesture")
	config.set_value("bindings","heavy_attack",{"key":KEY_H}); config.set_value("bindings","weapon_art",{"key":KEY_Z}); config.save(InputBindings.PATH)
	InputBindings.loaded=false; InputBindings.install()
	check(has_key("heavy_attack",KEY_H) and not has_key("weapon_art",KEY_Z) and InputMap.action_has_event("weapon_art",art),"Migration failed to retire the direct art key or preserve custom heavy")
	# A failed preference write must leave the usable runtime map intact.
	config=ConfigFile.new(); config.set_value("layout","version",5)
	config.set_value("bindings","skill_4",{"key":KEY_V}); config.save(InputBindings.PATH)
	InputBindings.loaded=false; InputBindings.install()
	check(has_key("skill_4",KEY_V) and InputMap.action_get_events("weapon_art")[0] is InputEventMouseButton,"New shared art stole an older V binding instead of retaining Ctrl+LMB")
	InputBindings.reset_defaults()
	DirAccess.make_dir_absolute(InputBindings.PATH+".tmp")
	check(not InputBindings.assign("skill_5",event(KEY_H)).accepted and has_key("skill_5",KEY_5),"Failed disk write changed runtime binding")
	DirAccess.remove_absolute(InputBindings.PATH+".tmp")
	if failures.is_empty(): print("PASS input bindings: migration, independent Q/E/R and number shortcuts, key swaps, context conflicts, reset and failed-write consistency")
	quit(0 if failures.is_empty() else 1)
