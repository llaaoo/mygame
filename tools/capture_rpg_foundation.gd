extends SceneTree
## Graphical input/runtime probe. No AI or simulation freezing; repositioning and
## food grants below are staged setup, not a campaign balance playthrough.
var game: GrayriverGame
var output:="/tmp/rpg-foundation-live"
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func settle(count:=8) -> void:
 for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func capture(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://grayriver.tscn").instantiate()
 game.persistence_enabled=false
 root.add_child(game); current_scene=game
 await settle(35)
 game.ui.close_modal()
 var origin:=game.player.position
 Input.action_press("move_right")
 await settle(12)
 Input.action_release("move_right")
 await settle(2)
 check(game.player.position.x>origin.x+20,"InputMap movement did not reach shared actor executor")
 var actions:=game.player.actor_context.actions
 var stamina:=actions.stamina.current
 Input.action_press("heavy_attack")
 await settle(2)
 Input.action_release("heavy_attack")
 check(actions.mode=="attack" and actions.stamina.current<stamina,"InputMap heavy attack did not consume stamina")
 await settle(55)
 var enemy:=game.active_enemies[0] as Enemy
 var enemy_origin:=enemy.position
 game.player.position=enemy.position+Vector2(115,0)
 game.player.get_node("Camera2D").reset_smoothing()
 await settle(25)
 check(GameRuntime.instance.is_processing() and enemy.process_mode!=Node.PROCESS_MODE_DISABLED,"Graphical probe disabled live simulation/AI")
 check(enemy.position.distance_to(enemy_origin)>1 or enemy.actor_context.actions.busy() or enemy.attack_preparation.busy(),"Normal enemy AI did not respond to nearby player")
 await capture("live-combat")
 game.player.position=origin
 game.player.get_node("Camera2D").reset_smoothing()
 await capture("actor-hud")
 game.survival.supplies.grant({"ration":2,"clean_water":2})
 game.hub.open("supplies"); game.hub._select("ration")
 await capture("pocket-pack")
 game.ui.close_modal()
 game.queue_free(); current_scene=null
 await settle()
 if failures.is_empty(): print("PASS graphical foundation: actual movement/heavy input, stamina, active simulation and responding AI")
 quit(0 if failures.is_empty() else 1)
