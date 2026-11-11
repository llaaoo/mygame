extends GutTest

class SightEnemy extends Enemy:
	var sight_available := true
	func can_see(_target: Node2D) -> bool: return sight_available

class ObservedActions extends ActorActionController:
	var snapshot_queries := 0
	func presentation_snapshot() -> Dictionary:
		snapshot_queries+=1
		return super.presentation_snapshot()

func test_distant_labels_skip_status_projection_and_nearby_labels_refresh() -> void:
	var actor:=SightEnemy.new();var visitor:=Player.new()
	autofree(actor);autofree(visitor)
	actor.player=visitor;actor.position=Vector2(2000,0)
	var view:=preload("res://entities/enemy/enemy_character_status.gd").new()
	view.actor=actor;actor.add_child(view);view._ready()
	# No SkillManager/Mana/Buff dependencies exist yet. A hidden label must not
	# query any of them, even though this actor's simulation remains enabled.
	view._process(.2)
	assert_false(view._label.visible)
	assert_eq(view._label.text,"")
	assert_eq(actor.process_mode,Node.PROCESS_MODE_INHERIT)
	var manager:=SkillManager.new();manager.name="SkillManager";actor.add_child(manager);actor.skill_manager=manager
	manager.combinations=ConditionalCastController.new();manager.add_child(manager.combinations)
	var mana:=ManaComponent.new();actor.add_child(mana);actor.mana_component=mana
	var buffs:=BuffManager.new();buffs.name="BuffManager";actor.add_child(buffs)
	actor.enemy_name="巡林者";actor.physical_loot=true
	actor.position=Vector2(50,0);view._process(.2)
	assert_true(view._label.visible)
	assert_string_contains(view._label.text,"巡林者")
	assert_string_contains(view._label.text,"MP 50/50")
	assert_string_contains(view._label.text,"观察穿戴与行囊")
	actor.story_truce=true;view._process(.2)
	assert_string_contains(view._label.text,"停战中")
	actor.position=Vector2(2000,0);view._process(.2)
	assert_false(view._label.visible)
	assert_eq(actor.process_mode,Node.PROCESS_MODE_INHERIT)

func test_warning_exposes_actual_territory_counter_without_baiting_close_interaction() -> void:
	var actor:=SightEnemy.new();var visitor:=Player.new()
	autofree(actor);autofree(visitor)
	actor.player=visitor;actor.position=Vector2(205,0);actor.enemy_name="猎犬";actor.physical_loot=true
	actor.character_definition=ActorCharacterData.new()
	actor.actor_context=ActorContext.new();actor.actor_context.actor=actor
	var rules:=EncounterTactics.new();rules.observation="绕侧避开锁向扑咬，再还击。"
	actor.actor_context.awareness=EnemyAwareness.new(actor.actor_context,rules,EncounterCoordinator.new())
	actor.actor_context.awareness.phase="warning"
	var manager:=SkillManager.new();manager.name="SkillManager";actor.add_child(manager);actor.skill_manager=manager
	manager.combinations=ConditionalCastController.new();manager.add_child(manager.combinations)
	var mana:=ManaComponent.new();actor.add_child(mana);actor.mana_component=mana
	var buffs:=BuffManager.new();buffs.name="BuffManager";actor.add_child(buffs)
	var view:=preload("res://entities/enemy/enemy_character_status.gd").new();view.actor=actor;actor.add_child(view);view._ready()
	view._process(.2)
	assert_true(view._label.visible)
	assert_string_contains(view._label.text,rules.observation)
	assert_false(view._label.text.contains("[F]"),"Outside normal interaction range, the warning must not invite unsafe close inspection")
	var shown: String=view._label.text
	actor.sight_available=false;actor.actor_context.awareness.phase="engaged";view._process(.2)
	assert_false(view._label.visible,"Counter/status information must not show through cover")
	assert_eq(view._label.text,shown,"Hidden labels should not project new behind-cover status")
	actor.sight_available=true;view._process(.2)
	assert_false(view._label.text.contains(rules.observation),"Warning-only advice must not persist as extra combat text")

func test_physical_labels_follow_executor_phase_and_hide_territory_repetition() -> void:
	var actor:=SightEnemy.new();var visitor:=Player.new()
	autofree(actor);autofree(visitor)
	actor.player=visitor;actor.position=Vector2(90,0);actor.enemy_name="守林兵"
	actor.actor_context=ActorContext.new();actor.actor_context.actor=actor
	var physical:=ObservedActions.new();actor.add_child(physical);actor.actor_context.actions=physical
	physical.profile=AttackProfile.new();physical.mode="attack";physical.elapsed=0
	var rules:=EncounterTactics.new()
	actor.actor_context.awareness=EnemyAwareness.new(actor.actor_context,rules,EncounterCoordinator.new())
	actor.actor_context.awareness.phase="engaged"
	var manager:=SkillManager.new();manager.name="SkillManager";actor.add_child(manager);actor.skill_manager=manager
	manager.combinations=ConditionalCastController.new();manager.add_child(manager.combinations)
	var mana:=ManaComponent.new();actor.add_child(mana);actor.mana_component=mana
	var buffs:=BuffManager.new();buffs.name="BuffManager";actor.add_child(buffs)
	var view:=preload("res://entities/enemy/enemy_character_status.gd").new();view.actor=actor;actor.add_child(view);view._ready()
	view._process(.2)
	assert_string_contains(view._label.text,"近击起手")
	assert_false(view._label.text.contains(actor.actor_context.awareness.caption()),"A committed physical action should take priority over repeated territory text")
	physical.profile.guard_pressure=2;view._process(.2)
	assert_string_contains(view._label.text,"重击起手")
	physical.profile.projectile_speed=500;view._process(.2)
	assert_string_contains(view._label.text,"远射起手")
	physical.elapsed=physical.profile.windup+physical.profile.active*.5;view._process(.2)
	assert_string_contains(view._label.text,"远射释放")
	physical.profile.projectile_speed=0;view._process(.2)
	assert_string_contains(view._label.text,"挥击中")
	physical.elapsed=physical.profile.windup+physical.profile.active+physical.profile.recovery*.5;view._process(.2)
	assert_string_contains(view._label.text,"收招 · 寻机还击")
	var queries:=physical.snapshot_queries
	actor.sight_available=false;view._process(.2)
	assert_false(view._label.visible)
	assert_eq(physical.snapshot_queries,queries,"Covered opponents must not query or publish new physical phases")
	actor.sight_available=true;actor.position=Vector2(300,0);view._process(.2)
	assert_false(view._label.visible)
	assert_eq(physical.snapshot_queries,queries,"Distant opponents must not query physical phases")
	actor.position=Vector2(90,0);physical.mode="idle";view._process(.2)
	assert_false(view._label.text.contains("收招"),"An ended attack must not advertise a stale counter opening")
	assert_string_contains(view._label.text,actor.actor_context.awareness.caption())
