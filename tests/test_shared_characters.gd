extends SceneTree
const Fixture := preload("res://tests/support/grayriver_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message);push_error(message)
func frames(n:=4) -> void:
	for i in range(n): await process_frame
func actor(definition: ActorCharacterData,world: Node) -> Enemy:
	var enemy := load("res://entities/enemy/enemy.tscn").instantiate() as Enemy
	enemy.character_definition=definition
	enemy.rewards_enabled=false
	world.add_child(enemy)
	enemy.process_mode=Node.PROCESS_MODE_DISABLED
	return enemy
func run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot()
	var player := game.player
	check(preload("res://tests/support/awakened_actor_fixture.gd").awaken(player),"Shared body comparison needs the same explicit innate qualification")
	var peer := actor(player.character_definition,game.region_root)
	var peer_magic:=peer.mana_component.magic_state
	check(peer_magic.awakened==player.actor_context.magic.awakened and peer_magic.hp_cost==player.actor_context.magic.hp_cost and peer_magic.stamina_cost==player.actor_context.magic.stamina_cost,"Shared body fixture started with different magic qualification or permanent costs")
	check(peer.stats_component.primary_values()==player.stats_component.primary_values(),"Same definition changed primaries by controller")
	check(peer.health_component.max_hp==player.health_component.max_hp and peer.mana_component.max_mp==player.mana_component.max_mp and peer.attack_damage==player.combat_component.attack_damage and peer.move_speed==player.move_speed,"Same body definition produces different derived attributes")
	var bolt:=load("res://gameplay/abilities/data/ignite_data.tres") as SkillData
	check(peer.skill_manager.executor.resolve_damage(bolt,CastContext.simple(peer,Vector2.RIGHT,bolt))==player.skill_manager.executor.resolve_damage(bolt,CastContext.simple(player,Vector2.RIGHT,bolt)),"Same stats produce different magic damage")
	var gear:=load("res://content/exploration/equipment/cadence_gloves.tres") as EquipmentData
	game.session.inventory.register_definition(gear)
	game.session.inventory.receive("player",gear.id,1)
	(player.get_node("EquipmentManager") as EquipmentManager).equip(gear)
	(peer.get_node("EquipmentManager") as EquipmentManager).equip(gear)
	var damage_gear:=EquipmentData.new()
	damage_gear.id="parity_fire_ring"
	damage_gear.slot_type=EquipmentData.SlotType.RING
	damage_gear.combat_modifiers={"damage.fire":.5}
	game.session.inventory.register_definition(damage_gear)
	game.session.inventory.receive("player",damage_gear.id,1)
	for body in [player,peer]: (body.get_node("EquipmentManager") as EquipmentManager).equip(damage_gear)
	var player_damage:=player.skill_manager.executor.resolve_damage(bolt,CastContext.simple(player,Vector2.RIGHT,bolt))
	check(player_damage>bolt.damage+int(player.stats_component.magic_damage*bolt.damage_scaling) and peer.skill_manager.executor.resolve_damage(bolt,CastContext.simple(peer,Vector2.RIGHT,bolt))==player_damage,"Equipment spell damage is restricted to player controllers")
	var strength := Buff.new();strength.buff_id="parity_strength";strength.stat_modifiers={"strength":3,"endurance":2};strength.duration=5
	for body in [player,peer]: (body.get_node("BuffManager") as BuffManager).apply_buff(strength)
	check(peer.attack_damage==player.combat_component.attack_damage and peer.health_component.max_hp==player.health_component.max_hp,"Equipment/primary Buff does not use common rebuild")
	for body in [player,peer]: (body.get_node("BuffManager") as BuffManager).remove_buff(strength)
	check(peer.attack_damage==player.combat_component.attack_damage and peer.health_component.max_hp==100,"Expiry did not restore common bases")
	for body in [player,peer]:
		body.stats_component.modify_stat("endurance",-2)
		body.stats_component.modify_stat("intelligence",-2)
	check(peer.health_component.hp==player.health_component.hp and peer.health_component.hp<=peer.health_component.max_hp and peer.mana_component.mp==player.mana_component.mp and peer.mana_component.mp<=peer.mana_component.max_mp,"Direct attribute change left NPC resources above their caps")
	for body in [player,peer]:
		body.stats_component.modify_stat("endurance",2)
		body.stats_component.modify_stat("intelligence",2)
	var definition:=load("res://content/characters/river_caster.tres") as ActorCharacterData
	check(definition.validation_errors().is_empty(),"Caster definition invalid")
	var bad:=definition.duplicate(true) as ActorCharacterData
	bad.skills.append(load("res://gameplay/abilities/data/fireball_data.tres"))
	check(not bad.validation_errors().is_empty(),"Combination result accepted as base action")
	var mage:=actor(definition,game.region_root)
	await frames()
	mage.position=Vector2(-1100,1000);player.position=Vector2(-900,1000)
	mage.player=player
	mage.ai_role=Enemy.AIRole.RANGED
	mage.ranged_preferred_range=220
	mage.mana_component.mp_regen_rate=0
	(mage.get_node("EquipmentManager") as EquipmentManager).equip(load("res://content/exploration/equipment/covenant_ring.tres"))
	var sm:=mage.skill_manager;var c:=sm.combinations
	var counts: Dictionary={}
	sm.cast_committed.connect(func(plan): counts[plan.action.get_id()]=int(counts.get(plan.action.get_id(),0))+1)
	# No field is fabricated by a rejected action or AI query.
	mage.mana_component.mp=0
	var decision:=mage.character_brain.choose(player)
	check(decision.size()==1 and decision[0].action_type==Action.ActionType.MOVE and c.live_fields().is_empty(),"Out-of-mana mage fabricated preparation instead of approaching")
	mage.mana_component.mp=mage.mana_component.max_mp
	mage.character_brain.tick(1)
	decision=mage.character_brain.choose(player)
	check(decision.size()==1 and decision[0].action_type==Action.ActionType.CAST and sm.get_instance(decision[0].skill_source).data.get_id()=="fire_sigil","AI cannot choose real base preparation")
	check(sm.effective_mana_cost(bolt,mage,12)==player.skill_manager.effective_mana_cost(bolt,player,12),"Same gear uses different spell cost policy")
	mage.ai_role=Enemy.AIRole.HYBRID
	mage.character_brain.tick(1)
	var hybrid:=mage.character_brain.choose(player)
	check(hybrid.size()==1 and hybrid[0].action_type==Action.ActionType.CAST,"Hybrid actor ignores its known spells")
	mage.ai_role=Enemy.AIRole.RANGED
	var initial:=mage.mana_component.mp
	check(sm.use_source(decision[0].skill_source,mage,decision[0].cast_context),"Mage cannot start ordinary sigil")
	c.tick(.1)
	check(c.live_fields().is_empty() and mage.mana_component.mp==initial,"Sigil charged or appeared before preparation finished")
	mage.take_damage(1);c.tick(.1)
	check(c.pending.is_empty() and c.live_fields().is_empty() and mage.mana_component.mp==initial,"Interrupted NPC preparation leaked resources or field")
	c.tick(1)
	var source:=mage.character_brain.find_source("fire_sigil")
	check(sm.use_source(source,mage,CastContext.simple(mage,Vector2.RIGHT,sm.get_instance(source).data)),"Retry sigil refused")
	c.tick(1)
	check(c.live_fields().size()==1 and c.field.charges==2 and mage.mana_component.mp<initial,"Paid sigil did not create real conditions")
	var focus_source:=mage.character_brain.find_source("focus")
	check(sm.use_source(focus_source,mage,CastContext.simple(mage,Vector2.RIGHT,sm.get_instance(focus_source).data)),"NPC cannot use focus in its own field")
	c.tick(1)
	var boon: Dictionary=(mage.get_node("BuffManager") as BuffManager).capture_status("ember_focus")
	var original:=load("res://gameplay/abilities/data/ember_focus_result.tres") as SkillData
	check(not boon.is_empty() and is_equal_approx(float(boon.remaining),original.buff_duration*.75),"NPC ignored equipped boon-duration cost")
	peer.position=mage.position+Vector2(30,0)
	var surfaces:=GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	surfaces.force_set_surface(SurfaceManager.cell_at(peer.position),"wet",5)
	mage._resolve_melee_hit(peer)
	check((peer.get_node("BuffManager") as BuffManager).has_buff("burning") and surfaces.surface_at(peer.position).state=="steam","NPC boon melee lost its elemental hit or ground reaction")
	var ignite:=mage.character_brain.find_source("ignite")
	var plan:=c.preview(sm.get_instance(ignite).data,mage)
	check(plan.rule_id=="fire_sigil_fireball","NPC preview skipped world combination")
	var previous:=mage.mana_component.mp
	check(sm.use_source(ignite,mage,CastContext.simple(mage,Vector2.LEFT,sm.get_instance(ignite).data)),"NPC base spark refused")
	c.tick(1)
	check(mage.mana_component.mp==previous-plan.cost and c.field.charges==0,"NPC combo cost/charge differs from prepared transaction")
	check(counts=={"fire_sigil":1,"focus":1,"ignite":1},"Preview or AI decision executed extra actions")
	# A low-health target can prompt an explicit release, through the same transaction.
	c.reset_session()
	(mage.get_node("BuffManager") as BuffManager).remove_status("ember_focus")
	mage.mana_component.mp=mage.mana_component.max_mp
	player.health_component.hp=35
	check(sm.use_source(source,mage,CastContext.simple(mage,Vector2.LEFT,sm.get_instance(source).data)),"Release setup rejected")
	c.tick(1)
	check(sm.use_source(focus_source,mage,CastContext.simple(mage,Vector2.LEFT,sm.get_instance(focus_source).data)),"Release boon setup rejected")
	c.tick(1)
	boon=(mage.get_node("BuffManager") as BuffManager).capture_status("ember_focus")
	mage.character_brain.tick(1)
	decision=mage.character_brain.choose(player)
	check(decision.size()==1 and decision[0].cast_context and decision[0].cast_context.empower,"AI did not explicitly select a valid boon release")
	if decision.size()==1 and decision[0].cast_context:
		# This resource fixture aims away from the player; live aiming is checked graphically.
		decision[0].cast_context.direction=Vector2.LEFT
		previous=mage.mana_component.mp
		plan=c.preview(sm.get_instance(ignite).data,mage,true)
		check(sm.use_source(ignite,mage,decision[0].cast_context),"AI release refused")
		c.tick(1)
		var retained: Dictionary=(mage.get_node("BuffManager") as BuffManager).capture_status("ember_focus")
		check(not retained.is_empty() and retained.instance==boon.instance and is_equal_approx(float(retained.remaining),float(boon.remaining)*.5) and mage.mana_component.mp==previous-plan.cost,"NPC partial release refreshed its boon or used different payment")
	# Removing the field changes the result instead of granting a free fireball.
	c.clear_field();c.tick(3)
	check(c.preview(sm.get_instance(ignite).data,mage).rule_id.is_empty(),"Missing field did not restore basic spark")
	check(not sm.knows_action(load("res://gameplay/abilities/data/storm_sigil_data.tres")),"NPC secretly knows all player skills")
	var result:=sm.pool.get_skill("fireball")
	sm.equip_hand("left",result)
	check(sm.left_hand==null,"NPC directly equipped a combination result")
	c.tick(5)
	mage.mana_component.mp=mage.mana_component.max_mp
	# Material insufficiency uses the shared failure path and changes no MP.
	c.supplies.configure("focus","ward_powder")
	c.supplies.amounts["ward_powder"]=0
	previous=mage.mana_component.mp
	var focus:=mage.character_brain.find_source("focus")
	check(not sm.use_source(focus,mage,CastContext.simple(mage,Vector2.RIGHT,sm.get_instance(focus).data)) and mage.mana_component.mp==previous,"NPC bypassed finite materials")
	check(definition.materials.ward_powder==1,"NPC mutated its shared definition inventory")
	c.supplies.clear_selection()
	c.tick(10)
	mage.mana_component.mp=mage.mana_component.max_mp
	var track:=CastContext.targeted(mage,peer,sm.get_instance(source).data)
	track.requires_live_target=true
	check(sm.use_source(source,mage,track),"Tracked preparation rejected valid target")
	previous=mage.mana_component.mp
	peer.health_component.tick(.6)
	peer.take_damage(1000)
	check(peer.health_component.is_dead,"Tracked-target fixture did not defeat its target")
	await frames()
	c.tick(1)
	check(c.pending.is_empty() and c.live_fields().is_empty() and mage.mana_component.mp==previous,"Dead target allowed a ghost preparation or payment")
	mage.queue_free();await frames()
	await fixture.close()
	# A combat world with no player still applies the same elemental contact rules.
	var world:=Node2D.new()
	root.add_child(world)
	current_scene=world
	world.add_child(GameRuntime.new())
	var body:=load("res://content/characters/explorer.tres") as ActorCharacterData
	var first:=actor(body,world)
	var second:=actor(body,world)
	await frames()
	CombatExecutor.report_hit(first,second,1,second.global_position,bolt)
	check((second.get_node("BuffManager") as BuffManager).has_buff("burning"),"NPC-only world requires a Player to apply elemental statuses")
	world.queue_free();current_scene=null;await frames(6)
	if errors.is_empty(): print("Shared character checks passed: identical bodies, equipment/Buff parity, finite mana/materials, real AI preparation/interrupt/retry, paid charge consumption and no direct result equip")
	quit(0 if errors.is_empty() else 1)
