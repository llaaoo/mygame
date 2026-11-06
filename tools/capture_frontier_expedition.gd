extends SceneTree
## Staged graphics fixture, not a natural campaign playthrough.
## godot --path . --script res://tools/capture_frontier_expedition.gd -- --output=/tmp/frontier-captures
var output:=ProjectSettings.globalize_path("user://frontier-captures")
var game: GrayriverGame
func _init() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
 if DirAccess.make_dir_recursive_absolute(output)!=OK:
  push_error("Cannot create capture directory: "+output)
  quit(1)
  return
 call_deferred("run")
func settle(n := 12) -> void:
 for i in range(n): await process_frame
func capture(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 game=load("res://grayriver.tscn").instantiate()
 game.persistence_enabled=false
 root.add_child(game)
 current_scene=game
 await settle(30)
 game.ui.close_modal()
 GameRuntime.instance.set_process(false)
 for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_DISABLED
 game.survival.supplies.grant({"ration":3,"clean_water":2,"charcoal":4,"sap":3})
 game.guidance.pin("river_road_people")
 game.hub.open("quests")
 await capture("quests")
 game.hub.open("equipment")
 game.hub._select("river_coat")
 await capture("equipment")
 game.ui.close_modal()
 game.show_map()
 await capture("map")
 game.ui.close_modal()
 var guard:=game.stories.actors["river.enemy.camp.bridge_keeper"] as Enemy
 game.player.position=guard.position+Vector2(-45,40)
 var camera:=game.player.get_node("Camera2D") as Camera2D
 camera.reset_smoothing()
 game.presenter._update_objective()
 game.stories.inspect(guard)
 await capture("conversation")
 game.ui.close_modal()
 guard.take_damage(1000)
 await settle()
 game.loot.inspect("river.enemy.camp.bridge_keeper")
 await capture("loot")
 game.ui.close_modal()
 game.player.position=Vector2(1120,-2090)
 camera.reset_smoothing()
 await capture("lake")
 root.content_scale_size=Vector2i(960,600)
 root.size=Vector2i(960,600)
 await settle()
 game.hub.open("equipment")
 game.hub._select("river_coat")
 await capture("equipment-small")
 game.hub.open("settings")
 await capture("settings-small")
 game.ui.close_modal()
 var beacon: SpellWorldObject
 for child in game.region_root.get_children():
  if child is SpellWorldObject and child.spec.id=="river.north_beacon": beacon=child
 game.player.position=beacon.position+Vector2(0,60)
 game.field_sites.inspect(beacon)
 await capture("work-small")
 var start:=game.player.field_work.panel.start_button
 var pointer:=start.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=pointer
 Input.parse_input_event(motion)
 await settle(2)
 if not game.player.input_controller._pointer_over_interface(): push_error("Work button did not suppress pointer combat input")
 var click:=InputEventMouseButton.new()
 click.position=pointer
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 Input.parse_input_event(click)
 await settle(2)
 click.pressed=false
 Input.parse_input_event(click)
 await settle(2)
 if not game.player.field_work.is_busy(): push_error("Real mouse click failed to start work")
 game.player.field_work.cancel("visual complete")
 game.player.field_work.close_panel()
 game.queue_free()
 current_scene=null
 await settle(8)
 quit()
