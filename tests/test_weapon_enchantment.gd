extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var serial := 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=3) -> void:
	for i in range(n): await physics_frame
func packet(source: Node2D,target: Node2D,definition: WeaponEnchantment) -> HitResult:
	serial+=1; target.get_node("HealthComponent").invincible=false
	var skill:=SkillData.new(); skill.weapon_enchantment=definition; skill.enchantment_bonus=definition.bonus_damage; skill.enchantment_buildup=definition.buildup
	skill.tags=["physical","melee"]; skill.tags.append_array(definition.tags)
	return CombatExecutor.report_hit(source,target,1,target.global_position,skill,skill.tags,"enchant.test.%d"%serial)
func coat(context: ActorContext,id: String) -> void:
	context.actions.cancel(); context.actions.stamina.current=100
	context.items.receive_into(context.id+".pocket",id,1)
	check(context.item_actions.begin(id),"Coating could not begin: "+id)
	context.item_actions.advance(1.3)
func request(actor: Player,id: String) -> Action:
	actor.actor_context.martial.learn(id); actor.actor_context.martial.ready_at.clear()
	var action:=Action.new(); action.action_type=Action.ActionType.TECHNIQUE; action.skill_id=id; action.direction=Vector2.RIGHT; action.params["release_enchantment"]=true
	return action
func reset_target(target: Enemy) -> void:
	(target.get_node("BuffManager") as BuffManager).clear_all()
	target.health_component.hp=target.health_component.max_hp; target.health_component.invincible=false
	target.actor_context.actions.cancel(); target.actor_context.actions.stability.current=100; target.actor_context.actions.stability.grace=0
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot(true)
	var actor:=game.player
	var context:=actor.actor_context
	var actions:=context.actions
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var target:=game.active_enemies[0]
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_process(false); target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var base:=Vector2(-4000,800); actor.position=base; target.position=base+Vector2(200,0)
	var buffs:=target.get_node("BuffManager") as BuffManager
	var fire:=WeaponEnchantment.definition("flame")
	var poison:=WeaponEnchantment.definition("venom")
	var result:=packet(actor,target,fire)
	check(result.elemental_damage==ActorCombatModel.incoming_damage(target,6) and not buffs.has_buff("burning") and float(buffs.buildup.snapshot().flame.value)==50,"First fire hit did not split elemental damage and partial buildup")
	result=packet(actor,target,fire)
	check(result.buildup_triggered and buffs.has_buff("burning") and buffs.buildup.snapshot().is_empty(),"Two qualified hits did not trigger/reset burning buildup")
	var hp:=target.health_component.hp
	buffs.tick(1.0)
	check(hp-target.health_component.hp==ActorCombatModel.incoming_damage(target,5+int(actor.stats_component.magic_damage*.3)),"Buildup DOT recursively added weapon bonus damage")
	var remaining:=float(buffs.capture_status("burning").remaining)
	packet(actor,target,fire)
	check(is_equal_approx(float(buffs.capture_status("burning").remaining),remaining),"Ordinary coating refreshed an active status")
	reset_target(target); packet(actor,target,fire); buffs.tick(4)
	check(is_equal_approx(float(buffs.buildup.snapshot().flame.value),30),"Partial buildup did not decay after its delay")
	var stock:=context.items
	stock.receive(target.actor_context.id,"river_shield",1); stock.equip(target.actor_context.id,stock.find_owned(target.actor_context.id,"river_shield"))
	reset_target(target)
	var guard:=Action.new(); guard.action_type=Action.ActionType.GUARD; guard.params["held"]=true; guard.direction=Vector2.LEFT
	target.actor_context.actions.stamina.current=100; target.actor_context.actions.try_action(guard)
	result=packet(actor,target,poison)
	check(result.blocked and result.elemental_damage==0 and buffs.buildup.snapshot().is_empty(),"Shielded hit leaked bonus damage or buildup")
	target.actor_context.actions.cancel(); target.add_to_group("fire_immune")
	result=packet(actor,target,fire)
	check(result.damage_dealt>0 and result.elemental_damage==0 and buffs.buildup.snapshot().is_empty(),"Element immunity removed physical damage or accepted fire buildup")
	target.remove_from_group("fire_immune")
	# Actual weapons and coatings; no MP, no implicit replacement on source failure.
	for id in ["river_staff","river_bow","river_spear","river_sabre"]: stock.receive("player",id,1)
	stock.equip("player",stock.find_owned("player","river_staff"))
	var uid:=str(stock.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])
	var enhanced:=request(actor,"staff_sweep")
	check(not actions.try_action(enhanced).accepted,"Enhanced technique conjured an absent coating")
	coat(context,"fire_rag"); var original:=stock.coating_state(uid)
	var mp:=actor.mana_component.mp
	check(actions.try_action(enhanced).accepted,"Enhanced sweep refused")
	actions.interrupt(.2)
	check(stock.coating_state(uid)==original,"Interrupted windup consumed the real coating")
	actions.cancel(); actions.stamina.current=100; context.martial.ready_at.clear()
	check(actions.try_action(enhanced).accepted,"Second enhanced sweep refused")
	var changed:=original.duplicate(); changed.id="poison_rag"; var props:=stock.item(uid).properties.duplicate(true); props.coating=changed; stock.set_properties(uid,props)
	actions.advance(.6)
	check(actions.mode=="idle" and stock.coating_state(uid)==changed,"Stale release consumed/replaced a different coating")
	# All melee shapes consume either actual chemistry; wave retains its own snapshot.
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"]]:
		for rag in ["fire_rag","poison_rag"]:
			actions.cancel(); stock.equip("player",stock.find_owned("player",pair[0])); coat(context,rag)
			uid=str(stock.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])
			enhanced=request(actor,pair[1]); check(actions.try_action(enhanced).accepted,"Melee release refused: "+pair[1])
			actions.advance(actions.profile.windup+.001)
			var waves:=game.region_root.get_children().filter(func(node): return node is EnchantmentWave and not node.is_queued_for_deletion())
			check(stock.coating(uid)==null and waves.size()==1 and actor.mana_component.mp==mp,"Melee release did not consume one coating/create one front without MP")
			for wave: EnchantmentWave in waves: wave.queue_free()
			await frames()
	# Contact and travelling front share attempt identity even after a new action.
	actions.cancel(); stock.equip("player",stock.find_owned("player","river_staff")); coat(context,"fire_rag")
	reset_target(target); target.position=base+Vector2(40,0); await frames()
	enhanced=request(actor,"staff_sweep"); actions.try_action(enhanced); actions.advance(.56)
	var waves:=game.region_root.get_children().filter(func(node): return node is EnchantmentWave and not node.is_queued_for_deletion())
	check(not waves.is_empty(),"Deduplication sample has no wave")
	if not waves.is_empty():
		var wave:=waves[0] as EnchantmentWave; wave.set_physics_process(false)
		hp=target.health_component.hp; actions.cancel(); wave._physics_process(.6)
		check(target.health_component.hp==hp,"Same release hit the near target twice after cancellation")
	await frames()
	# A travelling front respects real walls and elemental immunity, then exposes
	# an unprotected distant target using the same status/damage entry point.
	reset_target(target); target.position=base+Vector2(190,0)
	var wall:=StaticBody2D.new(); wall.collision_layer=1; wall.position=base+Vector2(100,0)
	var collider:=CollisionShape2D.new(); var box:=RectangleShape2D.new(); box.size=Vector2(10,160)
	collider.shape=box; wall.add_child(collider); game.region_root.add_child(wall); await frames()
	var oil_cell:=SurfaceManager.cell_at(target.position); SurfaceManager.instance.force_set_surface(oil_cell,"oiled",20)
	hp=target.health_component.hp
	var front:=EnchantmentWave.new(); front.context=context; front.enchantment=fire; front.technique=MartialArts.definition("staff_sweep"); front.family="wall.front"
	game.region_root.add_child(front); front.global_position=base; front.set_physics_process(false); front._physics_process(.7)
	check(target.health_component.hp==hp and buffs.buildup.snapshot().is_empty() and SurfaceManager.instance.get_surface(oil_cell).state=="oiled","Front damaged/exposed/ignited through a wall")
	check(front._outline.size()==25 and front._outline[12].x<100,"Rendered front crossed a blocking wall")
	wall.queue_free(); await frames(); target.add_to_group("fire_immune")
	front=EnchantmentWave.new(); front.context=context; front.enchantment=fire; front.technique=MartialArts.definition("staff_sweep"); front.family="immune.front"
	game.region_root.add_child(front); front.global_position=base; front.set_physics_process(false); front._physics_process(.7)
	check(target.health_component.hp==hp and buffs.buildup.snapshot().is_empty(),"Pure fire front damaged a fire-immune target")
	target.remove_from_group("fire_immune"); SurfaceManager.instance.force_set_surface(oil_cell,"dry",0)
	target.actor_context.actions.stamina.current=100; target.actor_context.actions.try_action(guard)
	buffs.apply_buff(poison.status,actor)
	actor.position=base+Vector2(400,0)
	front=EnchantmentWave.new(); front.context=context; front.enchantment=fire; front.technique=MartialArts.definition("staff_sweep"); front.family="guard.front"
	game.region_root.add_child(front); front.global_position=base; front.set_physics_process(false); front._physics_process(.7)
	check(target.health_component.hp==hp and buffs.buildup.snapshot().is_empty() and buffs.has_buff("poison"),"Moving caster or blocked elemental reaction bypassed the shield")
	buffs.remove_status("poison")
	actor.position=base; target.actor_context.actions.cancel()
	front=EnchantmentWave.new(); front.context=context; front.enchantment=poison; front.technique=MartialArts.definition("staff_sweep"); front.family="toxin.front"
	game.region_root.add_child(front); front.global_position=base; front.set_physics_process(false); front._physics_process(.7)
	check(target.health_component.hp<hp and buffs.has_buff("poison"),"Distant poison front failed to damage and reach threshold")
	await frames()
	# Arrow and enchantment are one inventory boundary. Failed release pays neither.
	actions.cancel(); stock.equip("player",stock.find_owned("player","river_bow")); coat(context,"poison_rag")
	uid=str(stock.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])
	stock.receive_into("player.pocket","arrow",1)
	enhanced=request(actor,"bow_aim"); check(actions.try_action(enhanced).accepted,"Enchanted arrow windup refused")
	var ammo:=stock.ready_uid("player","arrow"); stock.spend_instance("player",ammo,"quantity",stock.item(ammo).quantity)
	actions.advance(.9)
	check(actions.mode=="idle" and stock.coating(uid)!=null,"Missing arrow consumed enchantment or silently fired")
	actions.cancel(); actions.stamina.current=100; context.martial.ready_at.clear(); stock.receive_into("player.pocket","arrow",1)
	check(actions.try_action(enhanced).accepted,"Enchanted arrow retry refused")
	actions.advance(.86)
	var arrows:=game.region_root.get_children().filter(func(node): return node is WeaponArrow)
	check(stock.coating(uid)==null and stock.count("player","arrow")==0 and arrows.size()==1,"Successful arrow release did not commit ammo/coating together")
	if not arrows.is_empty():
		var arrow:=arrows[0] as WeaponArrow; arrow.set_physics_process(false)
		reset_target(target); target.position=base+Vector2(200,0); await frames()
		coat(context,"fire_rag")
		arrow._physics_process(.4)
		check(buffs.has_buff("poison") and stock.coating(uid).id=="fire_rag","A new coating rewrote an already-released arrow's chemistry")
		var impact_fronts:=game.region_root.get_children().filter(func(node): return node is EnchantmentWave and not node.is_queued_for_deletion())
		hp=target.health_component.hp
		for wave: EnchantmentWave in impact_fronts: wave.set_physics_process(false); wave._physics_process(.3)
		check(not impact_fronts.is_empty() and target.health_component.hp==hp,"Arrow impact did not expand or double-hit its primary target")
	await frames()
	# Partial buildup and the same coated UID survive real campaign save/reentry.
	actions.cancel(); coat(context,"fire_rag"); reset_target(target); packet(actor,target,fire)
	var saved:=buffs.buildup.snapshot(); var state:=stock.coating_state(uid); var target_id:=target.actor_context.id
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	target=game.session.actor_for_id(target_id) as Enemy
	var loaded: Dictionary=(target.get_node("BuffManager") as BuffManager).buildup.snapshot() if target else {}
	print("Enchantment reentry: "+JSON.stringify({"saved":saved,"loaded":loaded,"coating_saved":state,"coating_loaded":game.session.inventory.coating_state(uid)}))
	check(game.session.inventory.coating_state(uid)==state and loaded.has("flame") and is_equal_approx(float(loaded.flame.value),float(saved.flame.value)) and float(loaded.flame.delay)<=float(saved.flame.delay),"Save/reentry renewed/replaced coating or erased partial exposure")
	var copy:=StatusBuildup.new(); copy.restore(saved,8)
	check(copy.snapshot().is_empty(),"Away-time restore did not decay exposure")
	var bad:=game.session.snapshot(); bad.actors[target_id].buildup={"flame":{"value":INF,"delay":1}}
	check(not CampaignSession.valid_snapshot(bad),"Invalid buildup entered persistent state")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon enchantment: split damage, threshold/decay/immunity/DOT, six melee combinations, source interruption, deduplication, atomic arrows and actual persistent partial buildup")
	quit(0 if failures.is_empty() else 1)
