class_name ActorEquipmentVisual
extends Node2D
## Draw the actual equipped resources. Loot uses this same renderer.
var items: Array[EquipmentData] = []
var manager: EquipmentManager
var inventory_store: InventoryService
var display_uids: Array[String]=[]
var preview_pack := false
var animator: ActorAnimationController

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
	visual.animator=(load("res://gameplay/presentation/actors/actor_animation_rig.tscn") as PackedScene).instantiate()
	visual.animator.actor=actor
	var definition: ActorCharacterData=actor.get("character_definition") if "character_definition" in actor else null
	if definition and definition.animation_profile: visual.animator.profile=definition.animation_profile
	visual.add_child(visual.animator)
	var weapon:=ActorWeaponVisual.new(); weapon.actor=actor; weapon.rig=visual.animator; weapon.z_index=1
	visual.add_child(weapon)
	actor.add_child(visual)
	visual.manager.loadout_changed.connect(visual.refresh)
	visual.refresh()
	return visual

func refresh() -> void:
	if manager: items = manager.get_all_equipped()
	queue_redraw()

func _process(_delta: float) -> void:
	if not manager:
		if inventory_store: queue_redraw()
		return
	var actor := get_parent() as Node2D
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite: modulate = sprite.modulate
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(animator) and animator.is_node_ready():
		draw_set_transform(Vector2(1,19),0,Vector2(1,.38)); draw_circle(Vector2.ZERO,20,Color(0,0,0,.24))
		draw_set_transform(animator.rig.position+animator.get_node("Reaction").position,animator.rig.rotation)
		var wearer:=get_parent()
		var context: ActorContext=wearer.get("actor_context") if "actor_context" in wearer else null
		if preview_pack or context and context.rules.physical_inventory and context.items.is_attached(context.id+".pack"):
			draw_rect(Rect2(-17,-12,9,23),Color("665238")); draw_line(Vector2(-13,-10),Vector2(-13,10),Color("b39964"),2)
	for item in items:
		if manager and (item.slot_type==EquipmentData.SlotType.RIGHT_HAND or animator and item.world_shape=="shield"):
			var actor_context:=get_parent().get("actor_context") as ActorContext
			if actor_context and actor_context.actions.active() and (animator or actor_context.actions.mode=="attack"): continue
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
			"bow":
				draw_arc(Vector2(12,0),19,-PI/2,PI/2,20,c,3,true)
				draw_line(Vector2(12,-19),Vector2(12,19),Color("ddd0ad"),1,true)
			"spear":
				draw_line(Vector2(15, 19), Vector2(20, -23), Color("654d35"), 3)
				draw_colored_polygon(PackedVector2Array([Vector2(16, -20), Vector2(20, -32), Vector2(24, -20)]), c)
			"staff":
				draw_line(Vector2(16, 15), Vector2(18, -23), Color("765541"), 4)
				draw_circle(Vector2(18, -24), 6, Color("20252c"))
				draw_circle(Vector2(18, -24), 4, c)
			"shield":
				draw_colored_polygon(PackedVector2Array([Vector2(-25,-8),Vector2(-11,-8),Vector2(-11,8),Vector2(-18,15),Vector2(-25,8)]), c)
				draw_polyline(PackedVector2Array([Vector2(-24,-7),Vector2(-12,-7),Vector2(-12,7),Vector2(-18,13),Vector2(-24,7),Vector2(-24,-7)]),Color("8e9390"),1.5)
				draw_line(Vector2(-23,1),Vector2(-13,1),Color("443b2e"),2)
				draw_line(Vector2(-22,-3),Vector2(-22,5),Color("443b2e"),2)
				draw_line(Vector2(-14,-3),Vector2(-14,5),Color("443b2e"),2)
			"coat":
				draw_rect(Rect2(-9, -10, 18, 22), Color("17212a"))
				draw_rect(Rect2(-7, -8, 14, 18), c)
				draw_line(Vector2(0,-8),Vector2(0,10),Color("b8a47e"),2)
				draw_line(Vector2(-7,4),Vector2(7,4),Color("493727"),3)
				draw_rect(Rect2(-2,3,4,3),Color("a28b58"),false,1)
				for y in [-5,-1,8]: draw_line(Vector2(-6,y),Vector2(-3,y+1),c.lightened(.22),1)
			"boots":
				draw_rect(Rect2(-10,14,8,6),c)
				draw_rect(Rect2(2,14,8,6),c)
				draw_line(Vector2(-10,20),Vector2(-2,20),Color("352e27"),2)
				draw_line(Vector2(2,20),Vector2(10,20),Color("352e27"),2)
			"gloves":
				draw_rect(Rect2(-15,0,6,8),c)
				draw_rect(Rect2(9,0,6,8),c)
			"amulet": draw_circle(Vector2(0,-5),3,c)
			"ring": draw_arc(Vector2(12,5),3,0,TAU,12,c,2)
