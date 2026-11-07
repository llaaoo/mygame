class_name GrayriverLootCorpse
extends ExplorationInteractable
var loot_id: String
var service: GrayriverLoot
var gear: ActorEquipmentVisual

func _ready() -> void:
	kind = "loot"
	callback = func(): service.inspect(loot_id)
	super._ready()
	gear = ActorEquipmentVisual.new()
	gear.position = Vector2(0, 4)
	gear.rotation = -PI / 2
	add_child(gear)
	refresh()

func refresh() -> void:
	var record: Dictionary = service.game.progress.loot_records[loot_id]
	var empty: bool = record.equipment.is_empty() and record.materials.is_empty()
	set_title(record.title + (" · 已搜空" if empty else " · 搜刮"))
	gear.items.clear()
	gear.inventory_store=service.game.session.inventory
	gear.display_uids.clear()
	var sources:=gear.inventory_store.actor_containers(loot_id); sources.append(loot_id+".gear")
	for source in sources:
		for row in gear.inventory_store.entries(source): gear.display_uids.append(row.uid)
	for id in record.equipment:
		if service.game.catalog.equipment.has(id): gear.items.append(service.game.catalog.equipment[id])
	gear.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 5), 23, Color(0,0,0,.25))
	draw_line(Vector2(-14,4),Vector2(10,4),Color("56544b"),12)
	draw_circle(Vector2(-20,4),7,Color("8c8170"))
	if _near: draw_arc(Vector2.ZERO,27,0,TAU,32,Color("d5b66c"),1,true)
