extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=5) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	var guard: Enemy
	for enemy in game.active_enemies:
		if str(enemy.get_meta("frontier_claim",""))=="river.enemy.camp.forest.3": guard=enemy; break
	check(guard!=null,"Forest guard missing")
	var home:=guard.position
	game.player.position=home+Vector2(-470,0)
	guard.process_mode=Node.PROCESS_MODE_INHERIT
	await frames()
	check(guard._current_state_name()=="Idle","Guard aggroed before the player attacked outside detection")
	CombatExecutor.report_hit(game.player,guard,1,guard.position,null,["physical"],"retaliation-regression")
	await frames()
	check(guard._revenge_target==game.player and guard._current_state_name()=="Chase","A real hit outside detection left the guard idle")
	game.player.position=home+Vector2(-650,0)
	await frames()
	check(guard._revenge_target==null,"Retaliation bypassed the existing home leash")
	await fixture.close()
	if failures.is_empty(): print("PASS enemy retaliation: safe preparation stays safe, incoming hits provoke pursuit, existing leash still applies")
	quit(0 if failures.is_empty() else 1)
