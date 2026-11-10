extends GutTest

func test_legacy_knowledge_fallback_respects_category() -> void:
	var progress:=ExplorationProgress.new()
	progress.actions["spark"]=true;progress.spell_rules["fireball"]=true
	var query:=ConditionQuery.new();query.progress=progress
	assert_true(query.knows("spark",WorldCondition.Knowledge.ACTION))
	assert_false(query.knows("spark",WorldCondition.Knowledge.COMBINATION))
	assert_true(query.knows("fireball",WorldCondition.Knowledge.COMBINATION))
	assert_false(query.knows("fireball",WorldCondition.Knowledge.ACTION))

func test_injected_knowledge_owner_receives_actual_actor_and_category() -> void:
	var query:=ConditionQuery.new();query.actor_id="resident"
	query.knowledge_query=func(actor: String,key: String,kind: int) -> bool:
		return actor=="resident" and key=="skinning" and kind==WorldCondition.Knowledge.FIELDCRAFT
	assert_true(query.knows("skinning",WorldCondition.Knowledge.FIELDCRAFT))
	query.actor_id="player"
	assert_false(query.knows("skinning",WorldCondition.Knowledge.FIELDCRAFT),"One actor's knowledge cannot leak into another actor")

func test_unmet_claims_do_not_report_completion() -> void:
	var progress:=ExplorationProgress.new();progress.claims["visited"]=true
	var query:=ConditionQuery.new();query.progress=progress
	assert_true(query.claims_satisfied(PackedStringArray(["visited"])))
	assert_false(query.claims_satisfied(PackedStringArray(["visited","reported"])))
	assert_false(query.claims_reason(PackedStringArray(["reported"])).is_empty())
