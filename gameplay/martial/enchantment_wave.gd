class_name EnchantmentWave
extends Node2D
## One locked, travelling front. Geometry/chemistry reuse common combat/surfaces.
var context: ActorContext
var enchantment: WeaponEnchantment
var technique: MartialTechnique
var direction:=Vector2.RIGHT
var family := ""
var radius := 0.0
var hit_targets: Dictionary={}
var _ground: Dictionary={}
var _skill: SkillData
var _outline:=PackedVector2Array()
func _ready() -> void:
	_skill=SkillData.new(); _skill.id="enchantment_wave."+enchantment.id
	_skill.requires_magic=false
	_skill.display_name=enchantment.title+"释放"
	_skill.skill_type=SkillData.SkillType.AOE
	_skill.tags=enchantment.tags.duplicate(); _skill.tags.append_array(["physical","projectile","enchantment_release"])
	_skill.weapon_enchantment=enchantment; _skill.enchantment_buildup=enchantment.release_buildup
	_skill.enchantment_only=true
func _physics_process(delta: float) -> void:
	if not context or not is_instance_valid(context.actor) or not context.region.available(): queue_free(); return
	var old:=radius
	radius=minf(technique.release_reach,radius+technique.release_speed*delta)
	_outline.clear()
	var half:=deg_to_rad(technique.release_angle*.5)
	for i in range(25):
		var point:=Vector2.from_angle(direction.angle()-half+2*half*i/24)*radius
		var ray:=PhysicsRayQueryParameters2D.create(global_position,global_position+point,1,[context.actor.get_rid()])
		var wall:=get_world_2d().direct_space_state.intersect_ray(ray)
		_outline.append(Vector2(wall.position)-global_position if not wall.is_empty() else point)
	var shape:=CircleShape2D.new(); shape.radius=radius+14
	var query:=PhysicsShapeQueryParameters2D.new(); query.shape=shape; query.transform=Transform2D(0,global_position)
	query.collision_mask=10; query.collide_with_areas=true; query.exclude=[context.actor.get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query,64):
		var target:=hit.collider as Node2D
		if target and not target.has_method("take_damage"): target=target.owner as Node2D
		if not target or not target.has_method("take_damage") or target==context.actor or hit_targets.has(target.get_instance_id()): continue
		var distance:=global_position.distance_to(target.global_position)
		if distance+14<old or not ConeCoverage.contains(self,global_position,direction,target.global_position,radius+14,technique.release_angle): continue
		hit_targets[target.get_instance_id()]=true
		var result:=CombatExecutor.report_hit(context.actor,target,enchantment.release_damage,target.global_position,_skill,_skill.tags,family,0.0,null,global_position)
		if result.damage_dealt>0 and not result.blocked: ActorCombatModel.apply_melee_surface(target,enchantment.tags)
	var surfaces:=SurfaceManager.instance
	if surfaces:
		for cell in surfaces.get_cells_in_radius(global_position,radius+45):
			if _ground.has(cell): continue
			var point:=Vector2(cell)*64+Vector2(32,32)
			if global_position.distance_to(point)>radius or not ConeCoverage.contains(self,global_position,direction,point,radius,technique.release_angle): continue
			_ground[cell]=true
			if surfaces.get_surface(cell).get("state","dry")!="dry": surfaces.apply_tags(cell,enchantment.tags,_skill.display_name)
	queue_redraw()
	if radius>=technique.release_reach: queue_free()
func _draw() -> void:
	if _outline.size()<2: return
	draw_polyline(_outline,Color(enchantment.color,.85),6,true)
	if radius>10:
		var inner:=PackedVector2Array()
		for point in _outline: inner.append(point*maxf(0,(radius-8)/radius))
		draw_polyline(inner,Color(enchantment.color,.22),9,true)
