extends GutTest
## Pure shared-rule fixture. No world, knowledge grants or gameplay input overrides.
class Body extends CharacterBody2D:
	var actor_context: ActorContext
	var base_move_speed := 300.0
	var melee_damage_multiplier := 1.0
var actor: Body
var mana: ManaComponent
var stats: StatsComponent
var health: HealthComponent
var buffs: BuffManager

func before_each() -> void:
	actor=Body.new();autofree(actor)
	stats=StatsComponent.new();stats.name="StatsComponent";actor.add_child(stats)
	health=HealthComponent.new();health.name="HealthComponent";actor.add_child(health)
	mana=ManaComponent.new();mana.name="ManaComponent";actor.add_child(mana);mana.configure_magic(true,false)
	buffs=BuffManager.new();buffs.name="BuffManager";actor.add_child(buffs)
	var context:=ActorContext.new();actor.actor_context=context
	context.actor=actor;context.id="player";context.rules=RulesetDefinition.new();context.magic=mana.magic_state;context.facts=GameplayFacts.new()
	context.actions=ActorActionController.new();actor.add_child(context.actions);context.actions.context=context
	context.actions.stamina=StaminaComponent.new();actor.add_child(context.actions.stamina)
	ActorCombatModel.rebuild(actor)

func test_locked_capacity_blocks_raw_values_regeneration_potions_and_zero_cost_magic() -> void:
	mana.max_mp=999;mana.mp=999;mana.restore_mp(999,"potion");mana.tick(120)
	assert_eq(mana.max_mp,0);assert_eq(mana.mp,0);assert_false(mana.use_mp(1))
	assert_false(mana.can_cast());assert_true(mana.can_cast(false))
	var plan:=CastPlan.new();plan.action=SkillData.new();plan.actor=actor;plan.cost=0;plan.requires_magic=true
	var transaction:=CastTransaction.new(actor,null,CastTransaction.allocate_id())
	assert_false(transaction.reserve(plan),"A zero-cost magical action still requires awakening")
	transaction.rollback()
	plan.requires_magic=false;transaction=CastTransaction.new(actor,null,CastTransaction.allocate_id())
	assert_true(transaction.reserve(plan),"Pure physical items retain their ordinary zero-MP path")
	transaction.commit()

func test_repeated_primary_and_capacity_rebuilds_do_not_poison_latent_mana_base() -> void:
	stats.modify_stat("intelligence",3)
	for i in range(20):ActorCombatModel.rebuild(actor)
	assert_eq(mana.max_mp,0)
	assert_true(is_zero_approx(float(buffs.attributes._external.get("max_mana",0))),"Locked visible zero must not become a negative intrinsic reward")
	assert_true(mana.magic_state.awaken(actor,"test.rebuild",0,0.0,60).accepted)
	for i in range(20):ActorCombatModel.rebuild(actor)
	assert_eq(mana.max_mp,69);assert_eq(mana.mp,0)

func test_mana_rollback_restores_capacity_before_current_resource_without_notifications() -> void:
	assert_true(mana.magic_state.awaken(actor,"test.rollback",0,0.0,60).accepted)
	mana.mp=50
	var notifications: Array=[]
	mana.mp_changed.connect(func(current: int,maximum: int):notifications.append([current,maximum]))
	mana.begin_transaction()
	mana.max_mp=10
	assert_true(mana.use_mp(3))
	mana.finish_transaction(false)
	assert_eq(mana.max_mp,60)
	assert_eq(mana.mp,50,"Rollback must recover pre-transaction MP after a temporary capacity decrease")
	assert_true(notifications.is_empty(),"A rejected transaction must not publish resource changes")

func test_sacrifice_is_once_flat_after_bonuses_and_never_refills_resources() -> void:
	var bonus:=Buff.new();bonus.status_id="test.magic.capacity";bonus.duration=60
	bonus.stat_modifiers={"max_mana":20.0};bonus.stat_multipliers={"max_hp":.5}
	buffs.apply_buff(bonus)
	ActorCombatModel.rebuild(actor)
	var maximum:=health.max_hp;health.hp=35;actor.actor_context.actions.stamina.current=24
	assert_eq(mana.max_mp,0)
	assert_true(mana.magic_state.awaken(actor,"test.sacrifice").accepted)
	assert_eq(health.max_hp,maximum-10);assert_eq(health.hp,35)
	assert_eq(actor.actor_context.actions.stamina.maximum,90.0);assert_eq(actor.actor_context.actions.stamina.current,24.0)
	assert_eq(mana.max_mp,80);assert_eq(mana.mp,0)
	assert_eq(roundi(buffs.preview_attribute_delta("max_hp")),health.max_hp)
	var next_hp:=roundi(buffs.preview_attribute_delta("max_hp",5.0))
	stats.modify_stat("endurance",1);ActorCombatModel.rebuild(actor)
	assert_eq(health.max_hp,next_hp,"Perk/equipment-adjusted HP preview must include the same one-time flat sacrifice")
	stats.modify_stat("endurance",-1);ActorCombatModel.rebuild(actor)
	var saved:=mana.magic_state.serialize_save_data()
	assert_false(mana.magic_state.awaken(actor,"test.again").accepted)
	assert_eq(mana.magic_state.serialize_save_data(),saved)
	for i in range(10):ActorCombatModel.rebuild(actor)
	assert_eq(health.max_hp,maximum-10);assert_eq(mana.max_mp,80)

func test_ineligible_or_unaffordable_attempts_are_side_effect_free() -> void:
	mana.magic_state.aptitude=false
	var before:=mana.magic_state.serialize_save_data()
	assert_false(mana.magic_state.awaken(actor,"test.denied").accepted)
	assert_eq(mana.magic_state.serialize_save_data(),before)
	mana.magic_state.aptitude=true;before=mana.magic_state.serialize_save_data()
	assert_false(mana.magic_state.awaken(actor,"test.expensive",health.max_hp,10.0,60).accepted)
	assert_eq(mana.magic_state.serialize_save_data(),before)
	assert_eq(mana.max_mp,0)

func test_explicit_magic_requires_complete_valid_v1_and_preserves_unknown_additions() -> void:
	assert_false(ActorMagicState.valid_state({}))
	assert_false(ActorMagicState.valid_state({"schema":1,"awakened":true}))
	var saved:=mana.magic_state.serialize_save_data()
	for field in saved:
		var incomplete:=saved.duplicate(true);incomplete.erase(field)
		assert_false(ActorMagicState.valid_state(incomplete),"Missing core field "+str(field))
	var invalid:=saved.duplicate(true);invalid.stamina_cost=-10.0
	assert_false(ActorMagicState.valid_state(invalid))
	mana.magic_state.deserialize_save_data({})
	assert_eq(mana.magic_state.serialize_save_data(),saved,"Rejected payload must not grant legacy qualification")
	saved["future_optional"]={"receipt":"kept"}
	var copy:=ActorMagicState.new();copy.deserialize_save_data(saved)
	assert_eq(copy.serialize_save_data(),saved)
	var legacy:=ActorMagicState.new()
	assert_true(legacy.awakened and legacy.legacy_exempt)
	assert_eq(legacy.hp_cost,0);assert_eq(legacy.stamina_cost,0.0)
