extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot(true)
	var actor:=game.player
	actor.position=Vector2(-3500,2000)
	var ctx:=actor.actor_context
	var store:=ctx.items
	var use:=ctx.item_actions as ItemActionController
	use.set_physics_process(false); ctx.actions.set_physics_process(false)
	store.receive("player","river_sabre",1)
	store.equip("player",store.find_owned("player","river_sabre"))
	var weapon:=str(store.equipped("player").get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	check(not weapon.is_empty(),"Starter weapon missing")
	store.receive("player","poison_rag",3); store.receive("player","fire_rag",1)
	var before:=store.count("player","poison_rag")
	var mp:=actor.mana_component.mp
	var stamina:=ctx.actions.stamina.current
	check(use.begin("poison_rag"),"Weapon coating refused")
	use.advance(.6); check(store.count("player","poison_rag")==before and not store.coating(weapon),"Interrupted preparation spent a rag")
	ctx.actions.interrupt(.2)
	use.advance(1)
	check(not use.busy() and store.count("player","poison_rag")==before,"Stagger failed to interrupt coating")
	ctx.actions.cancel()
	check(use.begin("poison_rag"),"Coating could not restart")
	use.advance(1.2)
	check(store.count("player","poison_rag")==before-1 and store.coating(weapon)!=null,"Successful coating did not consume exactly one rag")
	check(actor.mana_component.mp==mp and ctx.actions.stamina.current==stamina,"Coating charged mana or stamina")
	var melee_target:=game.active_enemies[0]
	melee_target.position=actor.position+Vector2(45,0); melee_target.health_component.invincible=false
	var melee_buffs:=melee_target.get_node("BuffManager") as BuffManager
	melee_buffs.clear_all()
	var attack:=Action.melee(actor); attack.direction=Vector2.RIGHT
	check(ctx.actions.try_action(attack).accepted,"Coated weapon attack refused")
	ctx.actions.advance(ctx.actions.profile.windup); ctx.actions.contact(melee_target)
	check(melee_buffs.has_buff("poison") and melee_buffs.capture_status("poison").buff.tick_damage==3,"Real weapon contact lost its UID coating payload")
	ctx.actions.cancel()
	check(use.begin("fire_rag"),"Replacing coating refused"); use.advance(1.2)
	check(store.coating(weapon).id=="fire_rag" and store.item(weapon).properties.coating.size()==2,"Coatings accumulated instead of replacing")
	var expires: float=store.item(weapon).properties.coating.expires_at
	check(store.unequip("player",EquipmentData.SlotType.RIGHT_HAND).accepted,"Coated weapon could not be packed")
	check(store.coating(weapon)!=null and store.equip("player",weapon).accepted,"Coating did not follow weapon UID across swap")
	var snapshot:=game.session.snapshot()
	check(CampaignSession.valid_snapshot(snapshot) and store.valid_definitions(snapshot.inventory),"Stateful inventory snapshot invalid")
	var copy:=InventoryService.new()
	copy.rules=game.session.rules; copy.definitions=store.definitions.duplicate(); copy.restore(snapshot.inventory); copy.clock_seconds=snapshot.clock_seconds
	check(copy.item(weapon).properties==store.item(weapon).properties and copy.coating(weapon)!=null,"Snapshot lost weapon coating identity or lifetime")
	store.clock_seconds=expires+.1
	check(not store.coating(weapon),"Stored weapon coating never expired")
	store.receive("player","venom_bottle",4)
	before=store.count("player","venom_bottle")
	check(use.begin("venom_bottle",true,Vector2.RIGHT),"Throw aim refused")
	var cancel_event:=InputEventMouseButton.new(); cancel_event.button_index=MOUSE_BUTTON_RIGHT; cancel_event.pressed=true
	use._input(cancel_event)
	check(not use.busy() and store.count("player","venom_bottle")==before,"Cancelling aim consumed the bottle")
	check(use.begin("venom_bottle",false,Vector2.RIGHT),"Throw preparation refused")
	use.projectile_factory=func(): return null
	stamina=ctx.actions.stamina.current
	use.advance(.5)
	check(store.count("player","venom_bottle")==before and ctx.actions.stamina.current==stamina,"Rejected projectile lost its bottle or stamina")
	use.projectile_factory=Callable()
	var target:=game.active_enemies[0]
	target.position=actor.position+Vector2(150,0); target.process_mode=Node.PROCESS_MODE_INHERIT
	target.set_physics_process(false); target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.actor_context.actions.set_physics_process(false)
	target.health_component.invincible=false
	var buffs:=target.get_node("BuffManager") as BuffManager
	buffs.clear_all(); await frames()
	check(use.begin("venom_bottle",false,Vector2.RIGHT),"Live throw refused")
	use.advance(.5)
	check(store.count("player","venom_bottle")==before-1 and is_equal_approx(ctx.actions.stamina.current,stamina-8) and ctx.actions.mode=="recovery","Launching did not charge one bottle and stamina with recovery")
	check(not buffs.has_buff("poison"),"Throw teleported its effect before flight")
	for i in range(40): await physics_frame
	check(buffs.has_buff("poison"),"Thrown bottle failed to hit an actual actor during flight")
	ctx.actions.cancel()
	var wall:=StaticBody2D.new(); wall.collision_layer=1; wall.position=actor.position+Vector2(115,0)
	var collision:=CollisionShape2D.new(); var rect:=RectangleShape2D.new(); rect.size=Vector2(16,140); collision.shape=rect; wall.add_child(collision); game.region_root.add_child(wall)
	buffs.clear_all(); target.health_component.invincible=false; await frames()
	before=store.count("player","venom_bottle")
	check(use.begin("venom_bottle",false,Vector2.RIGHT),"Wall interception throw refused"); use.advance(.5)
	for i in range(40): await physics_frame
	check(not buffs.has_buff("poison") and store.count("player","venom_bottle")==before-1,"Bottle passed through a wall, splashed through it, or refunded after obstruction")
	wall.queue_free(); ctx.actions.cancel(); await frames()
	before=store.count("player","venom_bottle")
	check(use.begin("venom_bottle",false,Vector2.UP),"Miss test refused"); use.advance(.5)
	for i in range(50): await physics_frame
	check(store.count("player","venom_bottle")==before-1,"A missed bottle was refunded")
	ctx.actions.cancel()
	# The exact remaining UID moves to the corpse, then to the looter.
	var enemy_id:=str(target.get_meta("frontier_claim"))
	var enemy_weapon:=str(store.equipped(enemy_id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	store.set_properties(enemy_weapon,{"coating":{"id":"poison_rag","expires_at":store.clock_seconds+60}})
	store.receive(enemy_id,"venom_sprayer",2)
	var partial:=store.ready_uid(enemy_id,"venom_sprayer")
	store.spend_instance(enemy_id,partial,"doses",2)
	actor.position=target.position; target.take_damage(10000); await frames()
	var rows:=game.loot.instance_entries(enemy_id)
	check(rows.any(func(row): return row.uid==partial and "1剂" in row.subtitle),"Corpse hid partial bottle state")
	check(game.loot.take(enemy_id,"materials","venom_sprayer",partial)==1 and store.item(partial).properties.doses==1 and store.locate(partial).begins_with("player."),"Looting changed the chosen bottle or refilled it")
	check(store.item(enemy_weapon).properties.coating.id=="poison_rag","Death replaced the actual coated weapon")
	check(game.session.bind_belt(0,"venom_bottle","throw") and game.session.snapshot().belt[0].method=="throw","Item binding did not persist")
	var repo:=SaveRepository.new()
	for version in range(1,6): check(repo.migrate({"version":version,"player":{}}).version==6,"Old save did not migrate")
	check(use.begin("poison_rag"),"Save test coating refused"); use.advance(1.2)
	var saved_coating:=store.item(weapon).properties.duplicate(true)
	var saved_clock:=store.clock_seconds
	check(use.begin("venom_bottle",true,Vector2.RIGHT),"Save test aim refused")
	game._save_progress()
	await fixture.close()
	game=await fixture.boot(true)
	store=game.session.inventory
	check(store.item(weapon)!=null and store.item(weapon).properties==saved_coating,"Actual game reload lost or renewed the coated weapon")
	check(store.item(partial)!=null and store.item(partial).properties.doses==1,"Actual game reload replaced or refilled the chosen partial bottle")
	check(store.clock_seconds>=saved_clock and game.session.belt[0].id=="venom_bottle" and game.session.belt[0].method=="throw","Actual game reload lost the lifetime clock or item binding")
	check(not game.player.actor_context.item_actions.busy() and not game.player.actor_context.spray.active and game.player.skill_manager.combinations.supplies.selected.is_empty(),"Actual game reload resumed a transient action or prepared source")
	await fixture.close()
	if failures.is_empty(): print("PASS item actions: interruptible UID coatings, clocks, snapshots, aimed physical throws, rollback, actual partial loot and saved bindings")
	quit(0 if failures.is_empty() else 1)
