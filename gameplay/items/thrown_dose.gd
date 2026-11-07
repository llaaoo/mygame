class_name ThrownDose
extends Node2D
## Physical carrier: its consumable has already left inventory at launch.
var actor_context: ActorContext
var profile: ItemUseDefinition
var direction:=Vector2.RIGHT
var remaining := 360.0
var excluded: Array[RID]=[]
var spent := false
func _ready() -> void: queue_redraw()
func _physics_process(delta: float) -> void:
	if spent: return
	var distance:=minf(remaining,480*delta)
	var next:=global_position+direction*distance
	var ray:=PhysicsRayQueryParameters2D.create(global_position,next,11,excluded); ray.collide_with_areas=true
	var hit:=get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): global_position=Vector2(hit.position)-direction*2; impact(); return
	global_position=next; remaining-=distance
	if remaining<=0: impact()
func impact() -> void:
	if spent: return
	spent=true; hide(); set_physics_process(false)
	var skill:=SkillData.new(); skill.id="item."+profile.id; skill.display_name="投掷 · "+profile.payload.title
	skill.skill_type=SkillData.SkillType.AOE; skill.archetype="persistent_aoe"; skill.damage=0; skill.damage_scaling=0
	skill.tags=profile.payload.tags.duplicate(); skill.contact_statuses=profile.payload.statuses.duplicate()
	skill.aoe_radius=profile.splash_radius; skill.aoe_lifetime=.5; skill.aoe_color=profile.payload.color
	skill.creates_surface=profile.payload.surface; skill.surface_duration=profile.payload.surface_duration; skill.ignites_dry_surface=false
	ConeCoverage.apply(self,skill,direction,"throw.%d"%get_instance_id(),profile.splash_radius,360,profile.payload.surface_duration)
	get_tree().create_timer(2).timeout.connect(queue_free)
func _draw() -> void:
	draw_circle(Vector2.ZERO,6,profile.payload.color if profile and profile.payload else Color.WHITE)
	draw_arc(Vector2.ZERO,7,0,TAU,16,Color.WHITE,1)
