extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames() -> void:
	for i in 4:await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot()
	var hound:=game.session.actor_for_id("river.enemy.camp.depth.ridge_hound.1.v1") as Enemy
	var ally:=game.session.actor_for_id("river.enemy.camp.depth.ridge_hound.2.v1") as Enemy
	var archer:=game.session.actor_for_id("river.enemy.camp.depth.ridge_archer.v1") as Enemy
	var mauler:=game.session.actor_for_id("river.enemy.camp.depth.ridge_mauler.v1") as Enemy
	check(hound!=null and ally!=null and archer!=null and mauler!=null,"Authored territory encounter absent")
	if not hound or not ally or not archer or not mauler:await fixture.close();quit(1);return
	check((hound.get_node("EquipmentVisual") as ActorEquipmentVisual).animator.profile.id==&"hound","Territory beast lost its real visual body")
	var player:=game.player;player.position=Vector2(-4000,800)
	hound.position=player.position+Vector2(200,0);hound._home_position=hound.position
	ally.position=hound.position+Vector2(0,120);ally._home_position=ally.position
	archer.position=player.position+Vector2(700,0);archer._home_position=archer.position
	mauler.position=archer.position+Vector2(-150,0);mauler._home_position=mauler.position
	await frames()
	var awareness:=hound.actor_context.awareness;var other:=ally.actor_context.awareness
	awareness.advance(.1)
	check(awareness.phase=="warning" and hound._get_current_target()==null and other.phase=="quiet","Outer territory warning auto-attacked or globally alarmed")
	player.position-=Vector2(130,0);awareness.advance(.11)
	check(awareness.phase=="quiet" and other.phase=="quiet","Withdrawing before warning failed peaceful exit")
	player.position=hound.position-Vector2(65,0);awareness.advance(.11)
	check(awareness.phase=="search" and other.phase=="search" and awareness.visible_target()==player,"Inner territory/alarm failed visible local squad")
	check(archer.actor_context.awareness.phase=="quiet","Alarm spread across unrelated encounters")
	# A real wall hides future movement; only the last observed point is retained.
	var seen:=player.position;var wall:=StaticBody2D.new();wall.collision_layer=1;wall.collision_mask=0
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(8,150);collider.shape=shape;wall.add_child(collider);wall.position=(hound.position+player.position)*.5
	game.region_root.add_child(wall);await frames()
	player.position+=Vector2(-60,30);awareness.advance(.11)
	check(awareness.visible_target()==null and awareness.last_seen==seen,"Search tracked unseen player's changing position through wall")
	awareness.advance(awareness.rules.search_seconds+.2)
	check(awareness.phase=="quiet" and not awareness.last_seen.is_finite(),"Expired search kept permanent hostility target tracking")
	wall.queue_free();await frames()
	awareness.provoke(player.position);game.session.relations.set_attitude(hound.actor_context.id,"player","friendly")
	check(awareness.visible_target()==null and hound._get_current_target()==null,"Friendly transition left engaged territory attacking")
	game.session.relations.set_attitude(hound.actor_context.id,"player","hostile")
	# Frontline protection depends on actual companion position, bow and remaining arrows.
	player.position=archer.position+Vector2(-500,0);await frames()
	var cover:=game.session.encounters.cover_position(mauler.actor_context,player)
	check(cover.is_finite() and is_equal_approx(cover.distance_to(archer.position),100),"Bulwark did not choose real bow companion's forward screen")
	game.session.inventory.pay(archer.actor_context.id,{"arrow":game.session.inventory.count(archer.actor_context.id,"arrow")})
	check(not game.session.encounters.cover_position(mauler.actor_context,player).is_finite(),"Frontline kept protecting ammunition-less ranged advantage")
	game.session.inventory.receive_into(archer.actor_context.id+".pocket","arrow",1);archer.health_component.is_dead=true
	check(not game.session.encounters.cover_position(mauler.actor_context,player).is_finite(),"Frontline protected a dead companion")
	game.session.encounters.clear();archer.health_component.is_dead=false
	check(not game.session.encounters.cover_position(mauler.actor_context,player).is_finite(),"Region clear retained old tactical roster")
	await fixture.close()
	if failures.is_empty():print("PASS territory: readable outer warning/withdrawal, inner defense, local same-camp alarm, unrelated isolation, real wall/last-seen expiry, friendly transition and actual ammunition/death-dependent frontline cover")
	quit(0 if failures.is_empty() else 1)
