class_name ActorEquipmentVisual
extends Node2D
## Draw the actual equipped resources. Loot uses this same renderer.
var items: Array[EquipmentData] = []
var manager: EquipmentManager
var inventory_store: InventoryService
var display_uids: Array[String]=[]
var _walk_phase := 0.0

static func install(actor: Node2D) -> ActorEquipmentVisual:
	var existing := actor.get_node_or_null("EquipmentVisual") as ActorEquipmentVisual
	if existing: return existing
	var visual := ActorEquipmentVisual.new()
	visual.name = "EquipmentVisual"
	visual.z_index = 4
	visual.manager = actor.get_node("EquipmentManager") as EquipmentManager
	# The old atlas baked swords and shields into the body. Hide that layer so
	# unowned equipment is never depicted as if it could be recovered.
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite: sprite.self_modulate = Color(1,1,1,0)
	actor.add_child(visual)
	visual.manager.loadout_changed.connect(visual.refresh)
	visual.refresh()
	return visual

func refresh() -> void:
	if manager: items = manager.get_all_equipped()
	queue_redraw()

func _process(delta: float) -> void:
	if not manager:
		if inventory_store: queue_redraw()
		return
	var actor := get_parent() as Node2D
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite: modulate = sprite.modulate
	if "velocity" in actor and actor.velocity.length_squared() > 1:
		_walk_phase += delta * 10
	else: _walk_phase = 0
	queue_redraw()

func _draw() -> void:
	if manager:
		var wearer:=get_parent()
		var context:=wearer.get("actor_context") as ActorContext if "actor_context" in wearer else null
		if context and context.rules.physical_inventory and context.items.is_attached(context.id + ".pack"):
			draw_rect(Rect2(-17,-12,9,23),Color("665238"))
			draw_line(Vector2(-13,-10),Vector2(-13,10),Color("b39964"),2)
		draw_set_transform(Vector2(0,sin(_walk_phase)))
		var shirt := Color("546f79") if get_parent().is_in_group("player") else Color("75685a")
		draw_circle(Vector2(0,16),15,Color(0,0,0,.22))
		draw_rect(Rect2(-9,5,7,17),Color("333e43"))
		draw_rect(Rect2(2,5,7,17),Color("333e43"))
		draw_rect(Rect2(-11,-13,22,23),Color("202a30"))
		draw_rect(Rect2(-9,-11,18,20),shirt)
		draw_rect(Rect2(-16,-7,6,13),shirt)
		draw_rect(Rect2(10,-7,6,13),shirt)
		draw_rect(Rect2(-16,3,6,6),Color("bd997a"))
		draw_rect(Rect2(10,3,6,6),Color("bd997a"))
		draw_rect(Rect2(-7,-27,14,15),Color("bd997a"))
		draw_rect(Rect2(-8,-29,16,6),Color("393633"))
		draw_rect(Rect2(-5,-21,3,2),Color("26282b"))
		draw_rect(Rect2(3,-21,3,2),Color("26282b"))
	for item in items:
		var c := item.world_color
		var store:=manager.inventory_store if manager else inventory_store
		if store and item.slot_type==EquipmentData.SlotType.RIGHT_HAND:
			var uids: Array=store.equipped(manager.actor_id).values() if manager else display_uids
			for uid in uids:
				var instance:=store.item(uid)
				if not instance or instance.definition_id!=item.id: continue
				var coating:=store.coating(uid)
				if coating: c=c.lerp(coating.payload.color,.8)
				break
		match item.world_shape:
			"blade":
				draw_line(Vector2(13, 6), Vector2(26, -17), Color("151c22"), 6)
				draw_line(Vector2(13, 6), Vector2(26, -17), c, 3)
				draw_line(Vector2(10, 0), Vector2(21, 5), Color("a88343"), 3)
			"spear":
				draw_line(Vector2(15, 19), Vector2(20, -23), Color("654d35"), 3)
				draw_colored_polygon(PackedVector2Array([Vector2(16, -20), Vector2(20, -32), Vector2(24, -20)]), c)
			"staff":
				draw_line(Vector2(16, 15), Vector2(18, -23), Color("765541"), 4)
				draw_circle(Vector2(18, -24), 6, Color("20252c"))
				draw_circle(Vector2(18, -24), 4, c)
			"shield":
				draw_colored_polygon(PackedVector2Array([Vector2(-25,-8),Vector2(-11,-8),Vector2(-11,8),Vector2(-18,15),Vector2(-25,8)]), c)
				draw_line(Vector2(-18,-6), Vector2(-18,10), Color("d4bf91"), 2)
			"coat":
				draw_rect(Rect2(-9, -10, 18, 22), Color("17212a"))
				draw_rect(Rect2(-7, -8, 14, 18), c)
				draw_line(Vector2(0,-8),Vector2(0,10),Color("b8a47e"),2)
			"boots":
				draw_rect(Rect2(-10,14,8,6),c)
				draw_rect(Rect2(2,14,8,6),c)
			"gloves":
				draw_rect(Rect2(-15,0,6,8),c)
				draw_rect(Rect2(9,0,6,8),c)
			"amulet": draw_circle(Vector2(0,-5),3,c)
			"ring": draw_arc(Vector2(12,5),3,0,TAU,12,c,2)
