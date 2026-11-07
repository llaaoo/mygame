class_name WeaponArrow
extends Node2D
## Real ammunition is committed by the physical executor. One contact, wall-aware.
var context: ActorContext
var profile: AttackProfile
var direction:=Vector2.RIGHT
var family := ""
var tags: Array[String]=["physical","projectile"]
var statuses: Array[Buff]=[]
var travelled := 0.0
func _physics_process(delta: float) -> void:
	if not context or not is_instance_valid(context.actor) or not context.region.available(): queue_free(); return
	var distance:=minf(profile.reach-travelled,profile.projectile_speed*delta)
	var query:=PhysicsRayQueryParameters2D.create(global_position,global_position+direction*distance,11,[context.actor.get_rid()])
	query.collide_with_areas=true
	var hit:=get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target:=hit.collider as Node2D
		if target and not target.has_method("take_damage"): target=target.owner as Node2D
		if target and target.has_method("take_damage"):
			var skill:=SkillData.new(); skill.id="weapon_arrow"; skill.tags=tags.duplicate(); skill.contact_statuses=statuses.duplicate()
			var damage: int=context.actor.combat_component.attack_damage if not "attack_damage" in context.actor else context.actor.attack_damage
			CombatExecutor.report_hit(context.actor,target,roundi(damage*profile.damage_multiplier),hit.position,skill,skill.tags,family,profile.impact)
		queue_free(); return
	global_position+=direction*distance; travelled+=distance
	if travelled>=profile.reach: queue_free()
func _draw() -> void:
	draw_line(-direction*12,direction*4,Color("ded1a7"),2,true)
	draw_line(direction*4,direction.rotated(.45)*-3,Color.WHITE,2,true)
	draw_line(direction*4,direction.rotated(-.45)*-3,Color.WHITE,2,true)
