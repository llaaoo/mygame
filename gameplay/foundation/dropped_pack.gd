class_name DroppedPack
extends Node2D
var service: CampaignSession
var container_id := ""
var title := "旅行背包：拾回"
func _ready() -> void:
	add_to_group("interactable")
	var interaction:=Interactable.new()
	interaction.name="Interactable"
	interaction.set_callback(func(actor: Node2D):
		var context:=actor.get("actor_context") as ActorContext
		if context: service.recover_pack(context.id,container_id))
	add_child(interaction)
func _draw() -> void:
	draw_circle(Vector2(0,10),18,Color(0,0,0,.3))
	draw_rect(Rect2(-13,-14,26,28),Color("716343"))
	draw_rect(Rect2(-9,-18,18,9),Color("9f8a60"))
	draw_line(Vector2(-6,-14),Vector2(-6,14),Color("3a352b"),3)
	draw_line(Vector2(6,-14),Vector2(6,14),Color("3a352b"),3)
