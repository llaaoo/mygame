class_name ActorWeaponVisual
extends Node2D
## Rendering reads the same physical profile and real coating. Never owns contacts or action clocks.
var actor: CharacterBody2D
var rig: ActorAnimationController
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor) or not "actor_context" in actor: return
	var context: ActorContext=actor.get("actor_context")
	if not context or not context.actions or not context.actions.active(): return
	_draw_offhand(context)
	if context.actions.mode!="attack": _draw_held(context); return
	var profile:=context.actions.profile
	var elapsed:=context.actions.elapsed
	var facing:=context.actions.facing
	var attack_weapon_uid:=context.actions.attack_weapon_uid
	var counter_strike:=context.actions.counter_strike
	var manager:=context.actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var weapon:=manager.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if manager else null
	var color:=weapon.world_color if weapon else Color("c6a17e")
	var coating:=context.items.coating(attack_weapon_uid)
	if coating: color=color.lerp(coating.payload.color,.8)
	if counter_strike: color=color.lerp(Color("f3d58a"),.55)
	var before:=elapsed<profile.windup
	var active_phase:=elapsed>=profile.windup and elapsed<profile.windup+profile.active
	var progress:=clampf(elapsed/maxf(.001,profile.windup),0,1) if before else clampf((elapsed-profile.windup)/profile.active,0,1) if active_phase else 1-clampf((elapsed-profile.windup-profile.active)/maxf(.001,profile.recovery),0,1)
	var angle:=facing.angle()
	var length:=profile.reach*(.42+.2*progress if before else 1.0 if active_phase else .4+.6*progress)
	if profile.motion in ["slash","sweep"]:
		var span:=deg_to_rad(profile.angle_degrees*.5)
		angle+=profile.swing_direction*((-span*(.4+.6*progress)) if before else lerpf(-span,span,progress) if active_phase else span*progress)
	var direction:=Vector2.from_angle(angle)
	if profile.motion=="shot":
		draw_set_transform(Vector2.ZERO,facing.angle())
		draw_arc(Vector2(12,0),18,-PI/2,PI/2,16,color,3,true)
		var string_point:=Vector2(10-9*progress,0)
		draw_polyline(PackedVector2Array([Vector2(12,-18),string_point,Vector2(12,18)]),Color("dacead"),1,true)
		draw_line(string_point,string_point+Vector2(25,0),Color("ded1a7"),2,true)
		draw_set_transform(Vector2.ZERO)
		return
	if active_phase:
		draw_arc(Vector2.ZERO,profile.reach,facing.angle()-deg_to_rad(profile.angle_degrees*.5),facing.angle()+deg_to_rad(profile.angle_degrees*.5),24,Color(color,.13),2,true)
		if profile.motion in ["slash","sweep"]:
			var start_angle:=facing.angle()-profile.swing_direction*deg_to_rad(profile.angle_degrees*.5)
			draw_arc(Vector2.ZERO,profile.reach,minf(start_angle,angle),maxf(start_angle,angle),18,Color(color,.24),5,true)
		else: draw_line(direction*12,direction*profile.reach,Color(color,.25),7,true)
	var start:=rig.socket_position(&"main_hand") if is_instance_valid(rig) else direction*10
	var tip:=direction*length
	if not weapon: draw_circle(tip,5,color); return
	draw_line(start,tip,Color("302d27"),6,true)
	draw_line(start,tip,color,3 if weapon.world_shape!="staff" else 5,true)
	if weapon.world_shape=="staff": draw_circle(tip,5,color.lightened(.25))
	elif weapon.world_shape=="spear": draw_colored_polygon(PackedVector2Array([tip+direction*2,tip-direction*10+direction.orthogonal()*4,tip-direction*10-direction.orthogonal()*4]),color.lightened(.25))
	else: draw_line(start+direction*6-direction.orthogonal()*5,start+direction*6+direction.orthogonal()*5,Color("aa894b"),3,true)

func _draw_held(context: ActorContext) -> void:
	var manager:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var item:=manager.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if manager else null
	if not item: return
	var hand:=rig.socket_position(&"main_hand") if rig else Vector2(12,0)
	var direction:=rig.aim_direction if rig else context.actions.facing
	var color:=item.world_color
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var coating:=context.items.coating(uid)
	if coating: color=color.lerp(coating.payload.color,.8)
	draw_set_transform(hand,direction.angle())
	match item.world_shape:
		"bow":
			draw_arc(Vector2.ZERO,17,-PI/2,PI/2,16,color,3,true); draw_line(Vector2(0,-17),Vector2(0,17),Color("ddd0ad"),1,true)
		"blade","spear","staff":
			var length:=25.0 if item.world_shape=="blade" else 40.0
			draw_line(Vector2(-5,0),Vector2(length,0),Color("302d27"),6,true); draw_line(Vector2(-5,0),Vector2(length,0),color,3 if item.world_shape!="staff" else 5,true)
			if item.world_shape=="staff": draw_circle(Vector2(length,0),5,color.lightened(.2))
			elif item.world_shape=="blade": draw_line(Vector2(1,-5),Vector2(1,5),Color("aa894b"),3,true)
			else: draw_colored_polygon(PackedVector2Array([Vector2(length+3,0),Vector2(length-9,-4),Vector2(length-9,4)]),color)
	draw_set_transform(Vector2.ZERO)
func _draw_offhand(context: ActorContext) -> void:
	var manager:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var shield:=manager.get_equipment(EquipmentData.SlotType.LEFT_HAND) if manager else null
	if not shield or shield.world_shape!="shield": return
	var hand:=rig.socket_position(&"off_hand") if rig else Vector2(-12,0)
	if context.actions.guarding: hand+=context.actions.facing*10
	draw_set_transform(hand,context.actions.facing.angle()+PI*.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-9),Vector2(7,-9),Vector2(7,5),Vector2(0,12),Vector2(-7,5)]),shield.world_color)
	draw_line(Vector2(0,-7),Vector2(0,8),Color("d4bf91"),2,true)
	draw_set_transform(Vector2.ZERO)
