extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n:=3) -> void:
	for i in n:await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true)
	var actor:=game.player;var store:=game.session.inventory
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	actor.health_component.invincible=true # Isolate finite-ammo contract from eight concurrent projectile arrivals.
	actor.position=Vector2(-4000,800)
	var enemies: Dictionary={}
	for foe in game.active_enemies:
		if foe.actor_context.id.begins_with("river.enemy.camp.fieldcraft.") and foe.character_definition and foe.character_definition.id in ["river_hound","river_crawler","river_archer","river_mauler"]:enemies[foe.character_definition.id]=foe
	check(enemies.size()==4,"Missing authored enemy archetype")
	if enemies.size()!=4:quit(1);return
	for foe: Enemy in enemies.values():
		foe.position=actor.position+Vector2(50,0)
		foe.process_mode=Node.PROCESS_MODE_INHERIT;foe.set_process(false)
		foe.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
		foe.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
		foe.actor_context.actions.cancel();foe.actor_context.actions.stamina.current=100
	await frames()
	var hound:=enemies.river_hound as Enemy;var crawler:=enemies.river_crawler as Enemy
	for beast in [hound,crawler]:
		var actions: ActorActionController=beast.actor_context.actions
		check(store.equipped(beast.actor_context.id).is_empty() and not actions.can_guard() and actions.next_attack_profile().reach>56,"Natural attacks invented gear or humanoid guard")
		var brain:=EnemyCharacterBrain.new(beast);var selected:=brain.choose(actor)
		check(selected.size()==1 and selected[0].action_type==Action.ActionType.MELEE,"Natural enemy cannot choose its body attack")
		if not selected.is_empty():
			check(actions.try_action(selected[0]).accepted,"Natural physical action refused")
			var first: String=actions.profile.title
			actions.advance(actions.remaining+.001)
			check(actions.next_attack_profile().title!=first,"Natural body chain did not progress")
			actions.cancel()
	check(hound.actor_context.actions.next_attack_profile().angle_degrees<crawler.actor_context.actions.next_attack_profile().angle_degrees and hound.move_speed>crawler.move_speed,"Beasts lack spacing/movement distinction")
	check(crawler.actor_context.actions.next_attack_profile().guard_pressure>1.5 and crawler.actor_context.actions.next_attack_profile().recovery>.7,"Crawler lacks committed guard pressure/recovery opening")
	# Actual finite arrows are spent at release, not planning; depletion produces retreat.
	var archer:=enemies.river_archer as Enemy;var arrow_id:=archer.actor_context.id
	for foe: Enemy in enemies.values():foe.position=actor.position+Vector2(600,300)
	archer.position=actor.position+Vector2(250,0);await frames()
	var bow:=archer.actor_context.actions
	var remaining:=store.count(arrow_id,"arrow")
	check(remaining==8,"Archer authored budget missing")
	for i in remaining:
		var brain:=EnemyCharacterBrain.new(archer);var selected:=brain.choose(actor)
		check(selected.size()==1 and selected[0].action_type==Action.ActionType.MELEE,"Finite-armed archer refused its clear firing lane")
		if selected.is_empty():break
		check(bow.try_action(selected[0]).accepted,"Actual arrow action refused")
		var before:=store.count(arrow_id,"arrow")
		check(before==remaining-i,"Planning consumed an extra arrow")
		bow.advance(bow.profile.windup+.01)
		check(store.count(arrow_id,"arrow")==before-1,"Release did not spend exactly one arrow")
		bow.advance(bow.remaining+.1);bow.cancel();bow.stamina.current=bow.stamina.maximum
	var empty:=EnemyCharacterBrain.new(archer).choose(actor)
	check(empty.size()==1 and empty[0].action_type==Action.ActionType.MOVE and empty[0].direction.dot(archer.position.direction_to(actor.position))<0 and store.count(arrow_id,"arrow")==0,"Empty archer minted ammunition or attempted bow melee")
	game.player.position=archer.position;archer.health_component.invincible=false;archer.take_damage(1000);await frames()
	check(not game.progress.loot_records[arrow_id].materials.has("arrow") and game.progress.loot_records[arrow_id].equipment.has("river_bow"),"Archer death replenished spent arrows or lost real bow")
	# Real maul can be recovered and keeps its attack/technique family for the player.
	var mauler:=enemies.river_mauler as Enemy;var maul_id:=mauler.actor_context.id
	game.player.position=mauler.position;mauler.health_component.invincible=false;mauler.take_damage(1000);await frames()
	check(game.loot.take(maul_id,"equipment","river_maul")==1,"Real maul absent from corpse")
	var uid:=store.find_owned("player","river_maul");check(store.equip("player",uid).accepted,"Recovered maul could not be equipped")
	check(actor.actor_context.actions.attack_moveset().weapon_type=="staff" and actor.actor_context.actions.next_attack_profile().guard_pressure>=1.5,"Player did not inherit actual maul combat rules")
	game.player.position=Vector2(-3500,2100);game._save_progress()
	await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true)
	check(game.session.inventory.item(uid)!=null and game.session.inventory.count(arrow_id,"arrow")==0,"Cold reentry replaced weapon UID or restocked ammunition")
	await fixture.close()
	if failures.is_empty():print("PASS enemy diversity: four authored archetypes, natural chains without fake gear, narrow pursuit/wide guard pressure, real finite arrow release/depletion/death, shared recovered maul and persistent UID")
	quit(0 if failures.is_empty() else 1)
