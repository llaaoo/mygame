extends SceneTree
## Controlled boundaries: no timing thresholds tied to the host CPU.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func reset(actions: ActorActionController) -> void:
 actions.cancel(); actions.stamina.current=100; actions.stamina.delay=0
 actions.context.martial.ready_at.clear()
func weak_catalog(factory: Callable) -> WeakRef: return weakref(factory.call())
func run() -> void:
 var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true)
 var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
 actions.set_physics_process(false)
 actor.position=Vector2(-4200,-2700)
 store.receive("player","river_staff",1); store.receive("player","river_sabre",1)
 var staff:=store.find_owned("player","river_staff")
 store.equip("player",staff)
 var request:=Action.melee(actor); request.direction=Vector2.RIGHT
 var messages: Array[String]=[]; actions.action_refused.connect(func(text: String): messages.append(text))
 for factory in [MartialCatalog.default_catalog,ProvisionCatalog.default_catalog,ProductionCatalog.default_catalog,TrainingCatalog.default_catalog]:
  check(weak_catalog(factory).get_ref()!=null,"Immutable default definitions unloaded between queries")
 check(not SurvivalNeeds.valid({"meal_remaining":100000}) and not SurvivalNeeds.valid({"nutrition":INF}),"Cached definitions weakened timer/numeric save validation")
 # One input is one action; early clicks still expire, not delayed macros.
 reset(actions); var serial:=actions._attack_sequence
 actions.try_action(request); actions.advance(.9)
 check(actions._attack_sequence==serial+1 and actions.mode=="idle","A single press chained another attack")
 reset(actions); actions.try_action(request); serial=actions._attack_sequence
 actions.advance(.1); actions.try_action(request); actions.advance(.8)
 check(actions.mode=="idle" and actions._attack_sequence==serial,"Early windup input executed after expiry")
 # Reproduce the old lost press: 330ms before staff recovery finishes.
 reset(actions); actions.try_action(request); actions.advance(.55); serial=actions._attack_sequence
 var stamina:=actions.stamina.current
 var queued:=Action.melee(actor); queued.direction=Vector2.RIGHT; queued.params={"sample":{"value":1}}
 check(actions.try_action(queued).reason=="buffered" and actions.stamina.current==stamina,"Buffer charged stamina before accepting the next action")
 queued.direction=Vector2.LEFT; queued.params.sample.value=2
 check(actions._buffer.direction==Vector2.RIGHT and actions._buffer.params.sample.value==1,"Queued intent retained a mutable caller request")
 actions.advance(.33)
 check(actions.mode=="attack" and actions._attack_sequence==serial+1 and actions.combo.current_index==1 and actions.facing==Vector2.RIGHT,"Recovery press was lost or resampled")
 actions.advance(1.2)
 check(actions.mode=="idle" and actions._attack_sequence==serial+1,"One buffered press executed more than once")
 # Exact expiry/completion boundary and a larger tick must use event order.
 reset(actions); actions.try_action(request); actions.advance(.53); serial=actions._attack_sequence
 actions.try_action(request); actions.advance(.35)
 check(actions._attack_sequence==serial+1,"Exact-boundary buffered input disappeared")
 actor.actor_context.martial.learn("staff_sweep")
 var technique:=Action.new(); technique.action_type=Action.ActionType.TECHNIQUE; technique.skill_id="staff_sweep"; technique.direction=Vector2.RIGHT
 reset(actions); actions.try_action(technique); actions.advance(.8); serial=actions._attack_sequence
 actions.try_action(request); actions.advance(.58)
 check(actions.mode=="idle" and actions._attack_sequence==serial,"Large tick replayed a buffer that expired before recovery ended")
 # Actual committed phase remains planted; only recovery restores locomotion.
 reset(actions); var mp:=actor.mana_component.mp
 actions.try_action(technique); var profile:=actions.profile
 actions.try_action(Action.move(Vector2.RIGHT,actor)); actions.advance(.1)
 check(actor.velocity.is_zero_approx() and actions.mode=="attack","Rooted technique moved during committed windup")
 actions.advance(profile.windup+profile.active-.1)
 actions.try_action(Action.move(Vector2.RIGHT,actor)); actions.advance(profile.recovery*.25)
 var low:=actor.velocity.length()
 actions.try_action(Action.move(Vector2.RIGHT,actor)); actions.advance(profile.recovery*.25)
 check(low>0 and actor.velocity.length()>low and actor.mana_component.mp==mp,"Recovery stayed frozen, snapped to full speed or spent mana")
 check(is_equal_approx(profile.movement_factor(profile.windup+profile.active),0) and is_equal_approx(profile.movement_factor(profile.windup+profile.active+profile.recovery),1),"Movement endpoints disagree with the authored commitment")
 var invalid:=profile.duplicate(true) as AttackProfile; invalid.recovery_movement_multiplier=INF
 check(not invalid.valid(),"Nonfinite recovery movement accepted")
 # Revalidate buffered shortcuts/costs, and explain the rejection.
 reset(actions); actor.skill_manager.shortcuts.bind_technique("quick_e","staff_sweep")
 technique.skill_source="quick_e"; technique.params={"binding_revision":actor.skill_manager.shortcuts.revision("quick_e")}
 actions.try_action(request); actions.advance(.6); actions.try_action(technique)
 actor.skill_manager.shortcuts.clear("quick_e"); serial=actions._attack_sequence; stamina=actions.stamina.current
 actions.advance(.3)
 check(actions._attack_sequence==serial and actions.stamina.current>=stamina and messages.has("快捷绑定已改变"),"Stale buffered technique spent costs, executed or failed silently")
 reset(actions); messages.clear(); actions._feedback_cooldown=0
 actions.try_action(request); actions.advance(.6); actions.try_action(request); actions.stamina.current=0; actions.stamina.delay=.8
 serial=actions._attack_sequence; actions.advance(.3)
 check(actions._attack_sequence==serial and messages.has("体力不足"),"Buffered resource rejection executed or gave no feedback")
 reset(actions); actions.try_action(request); actions.advance(.6); actions.try_action(request); serial=actions._attack_sequence
 store.equip("player",store.find_owned("player","river_sabre")); actions.advance(.3)
 check(actions.mode=="idle" and actions._attack_sequence==serial,"Changing weapon replayed the old buffered attack")
 # Real persistence still validates values and preserves costs/UIDs.
 game._save_progress(); var read:=SaveManager.instance.read_slot(3)
 check(read.usable() and read.data.extensions.grayriver_frontier.foundation.inventory.next_uid==store.next_uid,"Optimized catalog path lost the real campaign snapshot")
 await fixture.close()
 if failures.is_empty(): print("PASS weapon response: retained immutable definitions, strict validation, manual-only chains, 330ms/exact-boundary buffering, expired/changed/cost rejection, copied intent, committed rooting and smooth recovery, real saved UID state")
 quit(0 if failures.is_empty() else 1)
