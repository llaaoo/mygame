extends SceneTree
## Controlled domain boundaries; graph/input test separately exercises live simulation.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func finish(actions: ActorActionController) -> void: actions.advance(actions.remaining)
func first(actions: ActorActionController,request: Action) -> void:
	actions.cancel(); actions.stamina.current=100
	check(actions.try_action(request).accepted,"Could not begin controlled first stroke")
	finish(actions)
func run() -> void:
	var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true)
	var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	actor.position=Vector2(-4000,800)
	var request:=Action.melee(actor); request.direction=Vector2.RIGHT
	var facts: Array[Dictionary]=[]
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": facts.append(fact.data))
	store.receive_into("player.pocket","arrow",12)
	for id in ["river_sabre","river_spear","river_staff","river_bow"]:
		store.receive("player",id,1)
		store.equip("player",store.find_owned("player",id))
		var weapon:=store.equipment_definition(str(store.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)]))
		var moves:=weapon.moveset; var serial:=actions._attack_sequence
		actions.cancel()
		for index in range(moves.attacks.size()):
			actions.stamina.current=100
			var arrows:=store.count("player","arrow")
			check(actions.try_action(request).accepted and actions.profile==moves.attacks[index],"Wrong manual stage: %s/%d"%[id,index])
			check(is_equal_approx(actions.stamina.current,100-actions.profile.stamina_cost),"Stroke bypassed its real stamina cost")
			check(facts.back().stroke_index==index and facts.back().stroke_count==moves.attacks.size(),"Committed action facts lost the stage")
			check(store.count("player","arrow")==arrows,"Nocking spent an arrow before release")
			finish(actions)
			check(actions.mode=="idle" and actions._attack_sequence==serial+index+1,"Single press auto-chained or skipped recovery")
			check(store.count("player","arrow")==arrows-(1 if moves.weapon_type=="bow" else 0),"Each shot did not commit exactly one real arrow")
		check(actions.combo_snapshot().is_empty(),"Finisher left a continuation or hidden loop")
		actions.stamina.current=100
		check(actions.try_action(request).accepted and actions.profile==moves.attacks[0],"New chain did not restart at the first stroke")
		actions.cancel()
	# Exact idle deadline, overrun and broad lifecycle resets.
	store.equip("player",store.find_owned("player","river_sabre"))
	first(actions,request); var window:=actions.combo.remaining
	actions.advance(window+.01)
	check(actions.combo_snapshot().is_empty() and actions.next_attack_profile().title=="横斩","Expired window retained a later stroke")
	actions.stamina.current=100; actions.try_action(request)
	actions.advance(actions.remaining+window+.1)
	check(actions.combo_snapshot().is_empty(),"Large physics step extended the chain deadline")
	first(actions,request)
	var guard:=Action.new(); guard.action_type=Action.ActionType.GUARD; guard.params={"held":true}; guard.direction=Vector2.RIGHT
	check(actions.try_action(guard).accepted and actions.combo_snapshot().is_empty(),"Guard preserved an offensive chain")
	first(actions,request)
	var old_legacy:=actions.legacy_request; actions.legacy_request=func(_input: Action): pass
	var cast:=Action.new(); cast.action_type=Action.ActionType.CAST
	actions.try_action(cast); actions.legacy_request=old_legacy
	check(actions.combo_snapshot().is_empty(),"Other action kept a hidden finisher")
	first(actions,request); actor.ui_blocked=true; actions._physics_process(.01); actor.ui_blocked=false
	check(actions.combo_snapshot().is_empty(),"Opening an interface banked a chain")
	first(actions,request); actions.stamina.current=100; actions.try_action(request)
	actions.advance(actions.profile.windup+actions.profile.active+.01)
	actions.try_action(request)
	check(actions.try_action(Action.dodge(Vector2.DOWN,actor)).accepted and actions.combo_snapshot().is_empty() and actions._buffer==null,"Recovery dodge retained the chain or buffered attack")
	actions.advance(.5)
	check(actions.mode=="idle","Dodge replayed a queued attack")
	first(actions,request); actions.stamina.current=0
	check(actions.try_action(request).reason=="stamina" and actions.combo.next_index==1,"Rejected attack advanced or consumed the chain")
	actions.stamina.current=100
	check(actions.try_action(request).accepted and actions.profile.title=="返刃","Retried request skipped the rejected stage")
	actions.interrupt(.2)
	check(actions.combo_snapshot().is_empty(),"Stagger banked a finisher")
	first(actions,request)
	var original:=str(store.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])
	store.receive("player","river_sabre",1); var alternate:=store.find_owned("player","river_sabre")
	store.equip("player",alternate); store.equip("player",original)
	check(actions.combo_snapshot().is_empty(),"Same-frame UID swap and return preserved progress")
	first(actions,request); actions.stamina.current=100
	var heavy:=Action.melee(actor); heavy.action_type=Action.ActionType.HEAVY_ATTACK; heavy.direction=Vector2.RIGHT
	check(actions.try_action(heavy).accepted and actions.profile.title=="横斩" and actions.combo_snapshot().is_empty(),"Standalone heavy silently inherited a later combo stage")
	finish(actions)
	check(actions.next_attack_profile().title=="横斩","Heavy banked a continuation")
	store.equip("player",store.find_owned("player","river_bow"))
	store.pay("player",{"arrow":store.count("player","arrow")})
	store.receive_into("player.pocket","arrow",1); first(actions,request)
	var before_stamina:=actions.stamina.current
	check(actions.combo_snapshot().reason=="口袋缺箭" and actions.try_action(request).reason=="ammunition" and actions.stamina.current==before_stamina and actions.combo.next_index==1,"Missing continuation arrow skipped the stage, charged stamina or promised readiness")
	store.receive_into("player.pocket","arrow",1); actions.stamina.current=100
	check(actions.try_action(request).accepted and actions.profile.title=="续弦快射","Resupplied bow skipped or reset the second shot")
	actions.interrupt(.2)
	check(store.count("player","arrow")==1 and actions.combo_snapshot().is_empty(),"Interrupted quick nock spent its arrow or retained progress")
	# Upgrades retain immutable moveset identity; values remain instance-derived.
	store.receive("player","coin",5); store.receive("player","metal_scrap",2)
	check(store.upgrade_instance("player",alternate).accepted,"Could not upgrade actual spare weapon")
	var base:=ItemCatalog.default_catalog().definition("river_sabre") as EquipmentData
	var base_damage: float=base.stat_modifiers.get("attack_damage",0)
	store.equip("player",alternate); first(actions,request)
	check(actions.next_attack_profile()==base.moveset.attacks[1] and float(base.stat_modifiers.get("attack_damage",0))==base_damage,"Upgraded weapon lost combo identity or mutated base stats")
	var derived:=store.equipment_definition(alternate)
	check(float(derived.stat_modifiers.attack_damage)==base_damage+1,"Upgrade bonus was lost")
	# Shared definition, independent actors, real short second-stroke AI reach.
	var foe:=game.active_enemies[0]; var enemy_actions:=foe.actor_context.actions
	store.receive(foe.actor_context.id,"river_staff",1); store.equip(foe.actor_context.id,store.find_owned(foe.actor_context.id,"river_staff"))
	var own:=Action.melee(foe); own.direction=Vector2.RIGHT
	first(enemy_actions,own)
	check(enemy_actions.next_attack_profile().reach==58 and actions.combo.next_index==1,"Actor chains leaked state or AI preview used stage one")
	var bad:=base.moveset.duplicate(true) as WeaponMoveset; bad.chain_window=NAN
	check(not bad.valid(),"Invalid window accepted")
	bad=base.moveset.duplicate(true); bad.attacks[0].swing_direction=0
	check(not bad.valid(),"Invalid swing direction accepted")
	game._save_progress(); var saved:=SaveManager.instance.read_slot(3)
	check(saved.usable(),"Active transient chain prevented valid persistence")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon combos: four authored manual sequences, real per-stroke costs/arrows, finite finishers, deadline/overrun, guard/cast/UI/dodge/stagger/UID reset, rejected retries, upgraded definitions, independent actors and real saved state")
	quit(0 if failures.is_empty() else 1)
