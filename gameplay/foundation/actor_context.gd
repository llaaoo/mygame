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
var actions: ActorActionController
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
	if actions: actions.cancel("scope_left")
	inspect_requested=Callable()
	hostile_requested=Callable()
	panel_requested=Callable()
	actor=null
