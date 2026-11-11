extends "res://tests/support/input_scene_probe.gd"
## Controlled positions/cover, authored normal AI. Inspection is not a combat/balance test.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const STATUS=preload("res://entities/enemy/enemy_character_status.gd")
const HOUND="river.enemy.camp.depth.ridge_hound.3.v1"
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self);game=await fixture.boot()
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies:foe.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player
 var enemy:=game.session.actor_for_id(HOUND) as Enemy
 check(enemy!=null and enemy.actor_context.awareness!=null,"Authored territorial opponent is missing")
 if not enemy or not enemy.actor_context.awareness:await fixture.close();quit(1);return
 var view: Node2D
 for child in enemy.get_children():
  if child.get_script()==STATUS:view=child
 check(view!=null,"Authored enemy status view is missing")
 if not view:await fixture.close();quit(1);return
 var label:=view.get("_label") as Label
 var observation:=enemy.actor_context.awareness.rules.observation
 actor.position=enemy.position+Vector2(-205,0);actor.get_node("Camera2D").reset_smoothing()
 await frames(8)
 check(enemy.actor_context.awareness.phase=="warning" and enemy._get_current_target()==null,"Controlled approach did not enter the existing noncombat warning")
 check(label.visible and label.text.contains(observation) and not label.text.contains("[F]"),"Counterplay is not readable during warning, or it baits an out-of-range F inspection")
 await key(KEY_F,true);await key(KEY_F,false)
 check(not is_instance_valid(game.ui.modal),"Warning observation unexpectedly opened a remote equipment panel")
 await capture("enemy-warning-counter")
 # Existing F remains short range and must not reveal a live opponent through cover.
 actor.position=enemy.position+Vector2(-60,0);actor.get_node("Camera2D").reset_smoothing()
 var wall:=StaticBody2D.new();wall.collision_layer=1;wall.collision_mask=0
 wall.position=actor.position.lerp(enemy.position,.5)
 var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(12,120)
 collision.shape=shape;wall.add_child(collision);game.region_root.add_child(wall)
 await frames(2)
 # Status presentation intentionally polls at 0.1s. Wait for that observable
 # result instead of asserting after fewer than one polling interval.
 var hide_deadline:=Time.get_ticks_msec()+500
 while label.visible and Time.get_ticks_msec()<hide_deadline:await frames(1)
 check(not enemy.can_see(actor),"Controlled wall did not block actual line of sight")
 check(not label.visible,"Nearby cover failed to hide the status/counter text")
 await key(KEY_F,true);await key(KEY_F,false)
 check(not is_instance_valid(game.ui.modal),"F disclosed the opponent's equipment/status through a wall")
 wall.queue_free();await frames(2)
 var stock:=game.session.inventory.material_amounts("player")
 await key(KEY_F,true);await key(KEY_F,false)
 check(is_instance_valid(game.ui.modal),"Real close-range F failed to open live enemy observation")
 if is_instance_valid(game.ui.modal):
  var texts: Array[String]=[]
  for type in ["Label","RichTextLabel"]:
   for item in game.ui.modal.find_children("*",type,true,false):texts.append(item.text)
  check(texts.any(func(text):return text.contains(observation)),"F observation did not read this encounter's actual rules")
  await capture("enemy-close-observation")
  await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
 actor.position=Vector2(-4000,800);actor.get_node("Camera2D").reset_smoothing()
 check(not paused and game.session.inventory.material_amounts("player")==stock,"Observation paused the world or changed physical resources")
 await fixture.close()
 if failures.is_empty():print("PASS enemy observation input: actual regional counter during normal-AI warning, no remote F panel, cover hides status and rejects F, close F shows the encounter's actual rules without resource changes; controlled positions/cover")
 quit(0 if failures.is_empty() else 1)
