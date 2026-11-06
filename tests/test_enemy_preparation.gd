extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	GameRuntime.instance.set_process(false)
	var enemy := load("res://entities/enemy/enemy.tscn").instantiate() as Enemy
	game.region_root.add_child(enemy)
	enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	enemy.attack_preparation.set_physics_process(false)
	enemy.position = Vector2(2000, 2000)
	game.player.position = enemy.position + Vector2(40, 0)
	enemy.player = game.player
	enemy.attack_damage = 9
	var hp := game.player.health_component.hp
	enemy._do_melee_attack()
	check(game.player.health_component.hp == hp and enemy.attack_preparation.busy(), "Melee bypassed preparation")
	enemy.attack_preparation.tick(.39)
	check(game.player.health_component.hp == hp, "Melee hit before .4 second warning")
	game.player.position = enemy.position + Vector2(-40, 0)
	enemy.attack_preparation.tick(.02)
	check(game.player.health_component.hp == hp, "Melee retargeted facing instead of missing")
	check(enemy.attack_preparation.busy(), "Melee has no recovery window")
	enemy.attack_preparation.tick(.25)
	check(not enemy.attack_preparation.busy(), "Recovery exceeded .25 seconds")
	enemy.attack_ready = true
	game.player.position = enemy.position + Vector2(40, 0)
	enemy._do_melee_attack()
	enemy.attack_preparation.tick(.4)
	check(game.player.health_component.hp == hp - 9, "Real frontal melee did not use existing damage path")
	enemy.attack_preparation.cancel()
	enemy.attack_ready = true
	enemy._do_melee_attack()
	game.player.position = enemy.position + Vector2(90, 0)
	enemy.attack_preparation.tick(.4)
	check(game.player.health_component.hp == hp - 9, "Melee ignored impact distance")
	enemy.attack_preparation.cancel()
	enemy.ai_role = Enemy.AIRole.RANGED
	game.player.position = enemy.position + Vector2(60, 0)
	enemy.resolve_action(Action.cast("right", Vector2.RIGHT, enemy))
	check(enemy.attack_preparation.kind == "ranged" and is_equal_approx(enemy.attack_preparation.remaining, .45), "Ranged warning missing")
	var pos := enemy.position
	enemy.resolve_action(Action.move(Vector2.UP, enemy))
	check(enemy.position == pos, "Enemy moved while locking cast direction")
	game.player.position = enemy.position + Vector2(0, 60)
	check(enemy.attack_preparation.direction == Vector2.RIGHT, "Ranged warning tracks target")
	enemy.attack_preparation.tick(.45)
	check(not enemy.skill_manager.can_use("right"), "Ranged warning failed to commit through skill manager")
	enemy.attack_preparation.cancel()
	enemy.attack_ready = true
	enemy._do_melee_attack()
	game.player.health_component.is_dead = true
	enemy.attack_preparation.tick(.4)
	check(not enemy.attack_preparation.busy(), "Invalid target did not cancel warning")
	game.player.health_component.is_dead = false
	var boss := load("res://entities/boss/fire_lord.tscn").instantiate() as Boss
	boss.boss_data = load("res://content/bosses/fire_lord.tres")
	game.region_root.add_child(boss)
	boss.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	boss.attack_preparation.set_physics_process(false)
	boss.position = Vector2(2100, 2000)
	boss.player = game.player
	boss._cast_skill("flame_storm")
	check(boss.melee_windup == .5 and boss.attack_preparation.kind == "aoe" and boss.attack_preparation.remaining == .75, "Boss preparation mismatch")
	var point := boss.attack_preparation.point
	game.player.position += Vector2(0, 200)
	check(boss.attack_preparation.point == point, "Boss AOE follows player during warning")
	var boss_buffs := boss.get_node("BuffManager") as BuffManager
	boss_buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"), game.player)
	boss.health_component.hp = 1
	boss._check_phase(1, boss.health_component.max_hp)
	check(is_equal_approx(boss.move_speed, boss.boss_data.move_speed * 1.8 * .3), "Boss rage overwrote frozen speed")
	boss.health_component.is_dead = true
	boss.attack_preparation.tick(.75)
	check(not boss.attack_preparation.busy(), "Dead Boss retained pending attack")
	await fixture.close()
	if errors.is_empty(): print("Enemy preparation passed: real timed hits, locked facing/range, recovery, ranged direction, boss AOE and invalidation")
	quit(0 if errors.is_empty() else 1)
