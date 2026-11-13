class_name GroundItems
extends Node2D
## World projection of a persisted InventoryService cache; contains no second item list.
var service: CampaignSession
var container_id: String
var title := "地面物资：查看与拾取"
func _ready() -> void:
 service.inventory.changed.connect(queue_redraw)
 add_to_group("interactable")
 var interaction:=Interactable.new(); interaction.name="Interactable"
 interaction.set_callback(func(actor: Node2D): service.inspect_ground(actor,container_id))
 add_child(interaction)
func _exit_tree() -> void:
 if service.inventory.changed.is_connected(queue_redraw): service.inventory.changed.disconnect(queue_redraw)
func _draw() -> void:
 draw_set_transform(Vector2(0,10),0,Vector2(1,.4)); draw_circle(Vector2.ZERO,22,Color(0,0,0,.3)); draw_set_transform(Vector2.ZERO)
 draw_colored_polygon(PackedVector2Array([Vector2(-16,7),Vector2(-10,-14),Vector2(9,-15),Vector2(17,8),Vector2(9,14),Vector2(-10,14)]),Color("85745a"))
 draw_line(Vector2(-9,-8),Vector2(9,-8),Color("c6b58c"),3)
 draw_line(Vector2(-7,-15),Vector2(7,-15),Color("4a4638"),3)
 var entries:=service.inventory.entries(container_id)
 if not entries.is_empty():
  var definition:=service.inventory.definitions.get(str(entries[0].definition)) as ItemData
  var icon:=InterfaceIcons.item(definition)
  if icon: draw_texture_rect(icon,Rect2(-14,-18,28,28),false)
