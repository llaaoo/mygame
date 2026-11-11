class_name ActorWeaponVisual
extends Node2D
## Rendering reads real equipment/coating and the executor clock. Never owns contacts or action clocks.
var actor: CharacterBody2D
var rig: ActorAnimationController
func _process(_delta: float) -> void: queue_redraw()

## Shared read-only view for drawing and inspection. A nocked arrow exists only
## before its actual release; the real projectile owns its appearance afterwards.
func visual_snapshot() -> Dictionary:
	if not is_instance_valid(actor) or not "actor_context" in actor: return {}
	var context: ActorContext=actor.get("actor_context")
	if not context or not context.actions or not context.actions.active(): return {}
	var manager:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var weapon: EquipmentData=manager.get_equipment(EquipmentData.SlotType.RIGHT_HAND) if manager else null
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),"")) if context.items else ""
	if context.rules.physical_inventory and weapon and uid.is_empty(): weapon=null
	if context.actions.mode=="attack" and uid!=context.actions.attack_weapon_uid: return {}
	var phase:="held"; var progress:=0.0
	var profile: AttackProfile=context.actions.profile if context.actions.mode=="attack" else null
	if profile:
		var elapsed:=context.actions.elapsed
		phase="windup" if elapsed<profile.windup else "active" if elapsed<profile.windup+profile.active else "recovery"
		progress=clampf(elapsed/maxf(.001,profile.windup),0,1) if phase=="windup" else clampf((elapsed-profile.windup)/profile.active,0,1) if phase=="active" else clampf((elapsed-profile.windup-profile.active)/maxf(.001,profile.recovery),0,1)
	var coating: ItemUseDefinition=context.items.coating(uid) if context.items and not uid.is_empty() else null
	var color: Color=weapon.world_color if weapon else Color("c6a17e")
	if coating: color=color.lerp(coating.payload.color,.8)
	if context.actions.counter_strike: color=color.lerp(Color("f3d58a"),.55)
	var nocked: bool=profile!=null and profile.motion=="shot" and phase=="windup" and not profile.ammo_id.is_empty() and context.items!=null and context.items.count(context.id,profile.ammo_id)>0
	return {"uid":uid,"shape":weapon.world_shape if weapon else "none","color":color,"phase":phase,"progress":progress,"nocked":nocked,"profile":profile}

func _draw() -> void:
	var view:=visual_snapshot()
	if view.is_empty(): return
	var context: ActorContext=actor.get("actor_context")
	_draw_offhand(context)
	var profile:=view.profile as AttackProfile
	var facing:=context.actions.facing
	var hand: Vector2=rig.socket_position(&"main_hand") if is_instance_valid(rig) else facing*10
	var color: Color=view.color
	if not profile:
		if view.shape=="none": return
		var direction:=rig.aim_direction if is_instance_valid(rig) else facing
		if view.shape=="bow": _draw_bow(hand,direction,0,false,color)
		else: _draw_weapon(view.shape,hand,hand+direction*(29 if view.shape=="blade" else 42),color)
		return
	var before: bool=view.phase=="windup"
	var active_phase: bool=view.phase=="active"
	var progress: float=view.progress
	if profile.motion=="shot":
		_draw_bow(hand,facing,progress if before else 0,view.nocked,color)
		return
	var angle:=facing.angle()
	var length:=profile.reach*(.42+.2*progress if before else 1.0 if active_phase else 1-.6*progress)
	if profile.motion in ["slash","sweep"]:
		var span:=deg_to_rad(profile.angle_degrees*.5)
		angle+=profile.swing_direction*(-span*(.4+.6*progress) if before else lerpf(-span,span,progress) if active_phase else span*(1-progress))
	var direction:=Vector2.from_angle(angle)
	if active_phase:
		draw_arc(Vector2.ZERO,profile.reach,facing.angle()-deg_to_rad(profile.angle_degrees*.5),facing.angle()+deg_to_rad(profile.angle_degrees*.5),24,Color(color,.13),2,true)
		if profile.motion in ["slash","sweep"]:
			var start_angle:=facing.angle()-profile.swing_direction*deg_to_rad(profile.angle_degrees*.5)
			draw_arc(Vector2.ZERO,profile.reach,minf(start_angle,angle),maxf(start_angle,angle),18,Color(color,.24),5,true)
		else: draw_line(direction*12,direction*profile.reach,Color(color,.25),7,true)
	_draw_weapon(view.shape,hand,direction*length,color)

func _draw_weapon(shape: String,start: Vector2,tip: Vector2,color: Color) -> void:
	if shape=="none": draw_circle(tip,5,color); return
	var delta:=tip-start
	var length:=maxf(8,delta.length())
	draw_set_transform(start,delta.angle())
	match shape:
		"blade":
			draw_colored_polygon(PackedVector2Array([Vector2(4,-4),Vector2(length-8,-3),Vector2(length+2,0),Vector2(length-8,3),Vector2(4,4)]),Color("202724"))
			draw_colored_polygon(PackedVector2Array([Vector2(6,-2),Vector2(length-8,-2),Vector2(length,0),Vector2(6,2)]),color)
			draw_line(Vector2(7,0),Vector2(length-3,0),color.lightened(.35),1,true)
			draw_line(Vector2(-6,0),Vector2(5,0),Color("6a4a35"),5,true)
			draw_line(Vector2(4,-7),Vector2(4,7),Color("bea271"),3,true)
			draw_circle(Vector2(-7,0),3,Color("bea271"))
		"spear":
			draw_line(Vector2(-15,0),Vector2(length-8,0),Color("302d27"),5,true)
			draw_line(Vector2(-15,0),Vector2(length-8,0),Color("977149"),3,true)
			draw_colored_polygon(PackedVector2Array([Vector2(length+2,0),Vector2(length-13,-5),Vector2(length-9,0),Vector2(length-13,5)]),color)
			draw_line(Vector2(length-10,0),Vector2(length,0),color.lightened(.4),1,true)
			for x in [-2,2,6]: draw_line(Vector2(x,-3),Vector2(x,3),Color("c7b78d"),1,true)
		"staff":
			draw_line(Vector2(-14,0),Vector2(length,0),Color("302d27"),7,true)
			draw_line(Vector2(-14,0),Vector2(length,0),Color("8f6744"),4,true)
			for x in [-9,-5,3,7]: draw_line(Vector2(x,-3),Vector2(x,3),Color("c7b78d"),2,true)
			draw_circle(Vector2(length-1,0),6,Color("292d2a"))
			draw_circle(Vector2(length,0),4,color)
			draw_line(Vector2(length-2,-2),Vector2(length+1,-2),color.lightened(.4),1,true)
	draw_set_transform(Vector2.ZERO)

func _draw_bow(hand: Vector2,direction: Vector2,pull: float,nocked: bool,color: Color) -> void:
	draw_set_transform(hand,direction.angle())
	draw_arc(Vector2(-6,0),20,-PI/2,PI/2,20,Color("292b25"),6,true)
	draw_arc(Vector2(-6,0),20,-PI/2,PI/2,20,color,3,true)
	var string_point:=Vector2(-6-12*pull,0)
	draw_polyline(PackedVector2Array([Vector2(-6,-20),string_point,Vector2(-6,20)]),Color("e0d7b8"),1,true)
	draw_line(Vector2(12,-5),Vector2(12,5),Color("5f4a35"),4,true)
	if nocked:
		draw_line(string_point,string_point+Vector2(34,0),Color("dfc99e"),2,true)
		draw_colored_polygon(PackedVector2Array([string_point+Vector2(38,0),string_point+Vector2(31,-3),string_point+Vector2(31,3)]),Color("dce0d6"))
		draw_line(string_point+Vector2(3,-3),string_point+Vector2(7,0),Color("bda372"),2,true)
	draw_set_transform(Vector2.ZERO)

func _draw_offhand(context: ActorContext) -> void:
	var manager:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var shield: EquipmentData=manager.get_equipment(EquipmentData.SlotType.LEFT_HAND) if manager else null
	if not shield or shield.world_shape!="shield": return
	var hand:=rig.socket_position(&"off_hand") if rig else Vector2(-12,0)
	if context.actions.guarding: hand+=context.actions.facing*10
	draw_set_transform(hand,context.actions.facing.angle()+PI*.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-10),Vector2(8,-10),Vector2(8,5),Vector2(0,14),Vector2(-8,5)]),Color("292e29"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6,-8),Vector2(6,-8),Vector2(6,4),Vector2(0,11),Vector2(-6,4)]),shield.world_color)
	draw_line(Vector2(0,-6),Vector2(0,8),Color("d4bf91"),2,true)
	draw_set_transform(Vector2.ZERO)
