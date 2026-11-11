class_name ActorContext
extends RefCounted
## Explicit capabilities, injected by a scene composition root. No game reference.
var actor: CharacterBody2D
var id := ""
var rules: RulesetDefinition
var region: RegionContext
var items: InventoryService
var facts: GameplayFacts
var relations: RelationService
var item_actions: Node
var spray: Node
var actions: ActorActionController
var martial:=MartialArts.new()
var magic:=ActorMagicState.new()
var fieldcraft: FieldcraftKnowledge
var awareness: EnemyAwareness
var encounter_group := ""
var body_moveset: WeaponMoveset
var guard_allowed := true
var learning_query: ConditionQuery
var preparation_query: Callable
var cancel_preparation: Callable
var nearby_allies: Callable
var inspect_requested: Callable
var hostile_requested: Callable
var panel_requested: Callable
var reward_eligible := true
var restored_inventory := false
var persistent := true
var loot_eligible := false
func world() -> Node:
	return region.root if region and region.available() else null
func dispose() -> void:
	if cancel_preparation.is_valid(): cancel_preparation.call()
	if actions: actions.cancel("scope_left")
	if item_actions: item_actions.cancel()
	if spray: spray.stop()
	preparation_query=Callable(); cancel_preparation=Callable()
	nearby_allies=Callable()
	inspect_requested=Callable()
	hostile_requested=Callable()
	panel_requested=Callable()
	actor=null
