extends GutTest

func test_distant_labels_skip_status_projection_and_nearby_labels_refresh() -> void:
	var actor:=Enemy.new();var visitor:=Player.new()
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
	actor.position=Vector2(100,0);view._process(.2)
	assert_true(view._label.visible)
	assert_string_contains(view._label.text,"巡林者")
	assert_string_contains(view._label.text,"MP 50/50")
	assert_string_contains(view._label.text,"观察穿戴与行囊")
	actor.story_truce=true;view._process(.2)
	assert_string_contains(view._label.text,"停战中")
	actor.position=Vector2(2000,0);view._process(.2)
	assert_false(view._label.visible)
	assert_eq(actor.process_mode,Node.PROCESS_MODE_INHERIT)
