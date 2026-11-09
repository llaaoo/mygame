extends "res://tests/support/input_scene_probe.gd"
## Real input, normal simulation/AI/budgets. Weapon/knowledge and location are fixtures.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var starts: Array[Dictionary]=[]
var steps: Array[Dictionary]=[]
func aim(point: Vector2) -> void:
 await aim_world(point)
func attack() -> void:
 steps.append({"input":"LMB","frame":Engine.get_physics_frames()})
 await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
func wait_phase(phase: float) -> void:
 for i in range(140):
  if game.player.actor_context.actions.elapsed>=phase: return
  await frames(1)
 check(false,"Physical phase did not advance")
func run() -> void:
 var fixture:=Fixture.new(self); game=await fixture.boot()
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; var actions:=actor.actor_context.actions
 var store:=game.session.inventory
 store.receive("player","river_staff",1); store.equip("player",store.find_owned("player","river_staff"))
 actor.actor_context.martial.learn("staff_sweep"); actor.skill_manager.shortcuts.bind_technique("quick_e","staff_sweep")
 actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing(); await frames(12)
 game.session.facts.committed.connect(func(fact: Dictionary):
  if fact.kind=="physical_action_started" and fact.source=="player": starts.append({"frame":Engine.get_physics_frames(),"data":fact.data.duplicate(true)}))
 await aim(actor.position+Vector2(150,0))
 var mp:=actor.mana_component.mp
 await attack()
 check(starts.size()==1 and int(starts[0].frame)-int(steps[0].frame)<=2,"Idle LMB was delayed or dropped")
 await wait_phase(.55)
 await attack()
 check(not actions.buffered_action_label().is_empty(),"330ms recovery press gave no pending feedback")
 await capture("queued-staff-stroke")
 for i in range(100):
  if starts.size()>=2: break
  await frames(1)
 check(starts.size()==2,"Recovery LMB failed to start the next stroke")
 if starts.size()==2:
  var interval:=float(starts[1].frame-starts[0].frame)/Engine.physics_ticks_per_second
  check(interval>=.88-1.0/60 and interval<=.88+2.0/60,"Chain added idle latency or bypassed committed recovery")
  print("RESPONSE_CHAIN ",JSON.stringify({"interval_seconds":interval,"first_frame":starts[0].frame,"second_frame":starts[1].frame,"queued_input_frame":steps[1].frame}))
 for i in range(120):
  if actions.mode=="idle": break
  await frames(1)
 check(starts.size()==2,"Held/released mouse chained an unsolicited third stroke")
 steps.append({"input":"E","frame":Engine.get_physics_frames()})
 await key(KEY_E,true); await key(KEY_E,false)
 check(actions.mode=="attack" and starts.size()==3 and starts.back().data.technique=="staff_sweep","Independent martial key did not start the physical technique")
 await key(KEY_D,true)
 check(actor.velocity.is_zero_approx(),"Rooted technique moved during its windup")
 await wait_phase(.55+.22+.3)
 var recovery_speed:=actor.velocity.length()
 check(actions.mode=="attack" and recovery_speed>actor.move_speed*.25 and recovery_speed<actor.move_speed*.9,"Held movement did not resume smoothly during recovery")
 await capture("moving-during-recovery")
 await key(KEY_D,false)
 for i in range(100):
  if actions.mode=="idle": break
  await frames(1)
 check(starts.size()==3 and actor.mana_component.mp==mp and not paused,"Physical inputs spent mana, replayed an action or paused the world")
 print("RESPONSE_INPUT ",JSON.stringify({"inputs":steps,"starts":starts,"recovery_speed":recovery_speed,"full_speed":actor.move_speed,"mp":actor.mana_component.mp,"stamina":actions.stamina.current,"normal_ai":game.active_enemies.all(func(e): return e.can_process())}))
 await fixture.close()
 if failures.is_empty(): print("PASS weapon response input: prompt LMB, manual buffered staff chain, 350ms pending feedback, separate E technique, committed rooting, smooth live recovery and no extra actions/MP")
 quit(0 if failures.is_empty() else 1)
