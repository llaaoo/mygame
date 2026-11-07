class_name ActorItemUse
extends Node
var context: ActorContext
var item_id := ""
var remaining := 0.0
var origin := Vector2.ZERO
var hp := 0
var generation := 0
var operation_id := 0
func _ready() -> void:
	operation_id=context.actions.operation_id
	origin=context.actor.position
	hp=context.actor.get_node("HealthComponent").hp
	generation=context.region.generation
	remaining=SurvivalCatalog.FOODS[item_id].seconds
func _physics_process(delta: float) -> void:
	if not is_instance_valid(context.actor) or not context.region.available(generation): queue_free(); return
	if context.actor.position.distance_to(origin)>12 or context.actor.get_node("HealthComponent").hp<hp or context.actions.operation_id!=operation_id or context.actions.busy() and context.actions.mode!="item": queue_free(); return
	remaining-=delta
	if remaining>0: return
	if context.items.pay(context.id,{item_id:1},true):
		context.actions.needs.consume(item_id)
		var buffs:=context.actor.get_node_or_null("BuffManager") as BuffManager
		if buffs and item_id in ["ration","broth"]: buffs.apply_buff(load("res://content/status/%s.tres"%("meal_fortitude" if item_id=="ration" else "broth_fortitude")))
		if buffs and item_id=="tea": buffs.remove_status("poison")
		if buffs and item_id=="dirty_water": buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
		NeedsRecovery.apply(context.actor,context.actions.needs)
		context.facts.publish("item_used",context.id,{"item":item_id})
	queue_free()
