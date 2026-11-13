class_name GrayriverLootCorpse
extends ExplorationInteractable
var loot_id: String
var service: GrayriverLoot
var gear: ActorEquipmentVisual
var fresh_death := false

func _ready() -> void:
	kind = "loot"
	callback = func(): service.inspect(loot_id)
	super._ready()
	gear = ActorEquipmentVisual.new()
	gear.position = Vector2(0, 4)
	if not loot_id.begins_with("cache."):
		var record: Dictionary=service.game.progress.loot_records[loot_id]
		gear.animator=(load("res://gameplay/presentation/actors/actor_animation_rig.tscn") as PackedScene).instantiate()
		gear.animator.profile=ActorAnimationCatalog.default_catalog().definition(StringName(str(record.get("visual_profile","puny_body"))))
		var direction:=Vector2.DOWN
		var raw: Variant=record.get("visual_facing",[])
		if raw is Array and raw.size()==2 and (raw[0] is int or raw[0] is float) and (raw[1] is int or raw[1] is float):
			var candidate:=Vector2(float(raw[0]),float(raw[1]))
			if candidate.is_finite() and not candidate.is_zero_approx(): direction=candidate.normalized()
		gear.animator.preview={"state":"death","phase":"whole","direction":direction,"token":"corpse:"+loot_id}
		if not fresh_death: gear.animator.preview["progress"]=1.0
		gear.add_child(gear.animator)
	add_child(gear)
	refresh()

func refresh() -> void:
	var record: Dictionary = service.game.progress.loot_records[loot_id]
	var empty: bool = record.equipment.is_empty() and record.materials.is_empty()
	var anatomical:=not service.game.session.inventory.entries(loot_id+".anatomy").is_empty()
	if loot_id.begins_with("cache."):
		visible = not empty
		if empty: remove_from_group("interactable")
	set_title(record.title + (" · 待专业处理" if empty and anatomical else " · 已搜空" if empty else " · 搜刮"))
	gear.items.clear()
	gear.inventory_store=service.game.session.inventory
	gear.display_uids.clear()
	var sources:=gear.inventory_store.actor_containers(loot_id); sources.append(loot_id+".gear")
	for source in sources:
		for row in gear.inventory_store.entries(source):
			gear.display_uids.append(row.uid)
			var definition:=gear.inventory_store.equipment_definition(str(row.uid))
			if definition: gear.items.append(definition)
	gear.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 5), 23, Color(0,0,0,.25))
	if loot_id.begins_with("cache."):
		draw_rect(Rect2(-18,-10,36,28), Color("493f2d"))
		draw_rect(Rect2(-18,-10,36,28), Color("b69c67"), false, 2)
		var store:=service.game.session.inventory
		var entries:=store.entries(loot_id+".pack")
		if not entries.is_empty():
			var definition:=store.definitions.get(str(entries[0].definition)) as ItemData
			var icon:=InterfaceIcons.item(definition)
			if icon: draw_texture_rect(icon,Rect2(-14,-14,28,28),false)
		if _near: draw_arc(Vector2.ZERO,27,0,TAU,32,Color("d5b66c"),1,true)
		return
	if not gear or not gear.animator:
		draw_line(Vector2(-14,4),Vector2(10,4),Color("56544b"),12)
		draw_circle(Vector2(-20,4),7,Color("8c8170"))
	if _near: draw_arc(Vector2.ZERO,27,0,TAU,32,Color("d5b66c"),1,true)
