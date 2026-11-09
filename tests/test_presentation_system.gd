extends SceneTree
## Controlled contracts. Actual input/work/normal AI are covered by presentation_input.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self); var game:=await fixture.boot(true)
	var director:=game.presentation
	check(director!=null and director.scope==game.region_root and director.environment!=null,"Campaign failed to compose scene presentation")
	check(PresentationCatalog.defaults().validation_errors().is_empty() and WorldAnimationProfile.defaults().validation_errors().is_empty(),"Sample presentation resources invalid")
	var sounds: Array=JSON.parse_string(FileAccess.get_file_as_string("res://content/presentation/sounds/manifest.json"))
	for sound in sounds: check(FileAccess.get_sha256("res://"+sound.path)==sound.sha256,"Original cue sound hash changed: "+sound.path)
	var bad:=WorldAnimationProfile.new(); bad.poses=AnimationLibrary.new()
	for id in WorldAnimationProfile.defaults().poses.get_animation_list(): bad.poses.add_animation(id,WorldAnimationProfile.defaults().poses.get_animation(id))
	var animation:=Animation.new(); var track:=animation.add_track(Animation.TYPE_METHOD); animation.track_set_path(track,NodePath("."))
	animation.track_insert_key(track,0,{"method":&"queue_free","args":[]}); bad.poses.add_animation("unsafe",animation)
	check(not bad.validation_errors().is_empty(),"World visual accepted a callback track")
	for scene in [preload("res://content/presentation/well_display.tscn"),preload("res://content/presentation/ember_trail.tscn"),preload("res://content/presentation/ember_impact.tscn")]: check(PresentationScene.validation_errors(scene).is_empty(),"Native art prefab rejected")
	var invalid_scene:=PackedScene.new(); var collision:=Area2D.new(); invalid_scene.pack(collision); collision.free()
	check(not PresentationScene.validation_errors(invalid_scene).is_empty(),"Visual prefab accepted a gameplay collision object")
	var fire:=preload("res://content/visuals/fire_visual.tres") as ProjectileVisualData
	check(fire.trail_scene!=null and fire.hit_effect!=null and fire.sound_cast!=null and fire.sound_hit!=null,"Actual fire visual did not exercise the authored asset interfaces")
	var original_motion: bool=PresentationPreferences.value("reduced_motion")
	var original_quality: int=PresentationPreferences.value("effects_quality")
	check(not PresentationPreferences.set_option("effects_quality",-1) and not PresentationPreferences.set_option("world_volume",NAN),"Malformed cosmetic settings accepted")
	PresentationPreferences.set_option("effects_quality",0)
	var store:=game.session.inventory
	var before:=store.snapshot(); var position:=game.player.position; var hp:=game.player.health_component.hp; var mp:=game.player.mana_component.mp
	var point:=game.player.global_position
	seed(92381); var expected:=randi(); seed(92381)
	check(director.emit_cue(&"harvest",point,"same_fact"),"Real scene cue rejected")
	check(not director.emit_cue(&"harvest",point,"same_fact"),"Duplicate fact replayed its presentation")
	for i in range(30): director.emit_cue(&"craft",point,"bounded:"+str(i))
	check(director.snapshot().effects==12 and director.audio._voices.size()<=PresentationAudio.MAX_VOICES,"Effects/voices exceeded the configured bounds")
	check(director.emit_cue(&"puzzle",point,"important") and director.snapshot().effects==12,"Higher-priority committed feedback could not replace decoration")
	check(not director.emit_cue(&"craft",Vector2(100000,100000)),"Offscreen decoration was not culled")
	check(randi()==expected,"Cosmetic effects consumed gameplay RNG")
	var _combat_rng:=game.player.skill_manager.executor._combat_rng
	var _reaction_rng: RandomNumberGenerator=game.player.get_node("SkillSynergyResolver")._reaction_rng
	var combat_state:=_combat_rng.state; var reaction_state:=_reaction_rng.state
	var target: Enemy=game.active_enemies[0]
	var loot_state:=target._loot_rng.state
	var trail:=PresentationScene.attach(game.region_root,fire.trail_scene)
	check(trail!=null and _combat_rng.state==combat_state and _reaction_rng.state==reaction_state and target._loot_rng.state==loot_state,"Authored particle prefab consumed an actor's gameplay RNG")
	if trail: trail.queue_free()
	check(store.snapshot()==before and game.player.position==position and game.player.health_component.hp==hp and game.player.mana_component.mp==mp,"Presentation changed resources, clocks or the actor root")
	PresentationPreferences.set_option("reduced_motion",false)
	director.audio.clear()
	target.position=point+Vector2(40,0)
	var utility:=SkillData.new(); utility.visual=fire; utility.tags=["utility"]
	var hit:=CombatExecutor.report_hit(game.player,target,0,target.global_position,utility,["utility"])
	check(hit.accepted and not director.audio._voices.is_empty() and director.audio._voices.back().get("stream")==fire.sound_hit,"Accepted zero-damage hit did not use the actual visual sound override")
	CombatExecutor.report_hit(target,game.player,1,point,null,[],"presentation.camera")
	check(director.camera_feedback._strength>0,"Real applied damage did not reach camera feedback")
	director.camera_feedback.kick(5); director.camera_feedback._process(.01)
	check(director.camera_feedback.camera.offset.length()>0 and director.camera_feedback.camera.offset.length()<7,"Camera feedback missing or unbounded")
	PresentationPreferences.set_option("reduced_motion",true); director.camera_feedback._process(.01)
	check(director.camera_feedback.camera.offset.is_zero_approx(),"Reduced motion failed to restore camera offset immediately")
	var phase:=director.environment.phase; director.environment._process(10)
	check(director.environment.phase==phase and not paused and Engine.time_scale==1,"Reduced motion stopped simulation or advanced ambient motion")
	var visual:=WorldObjectPresentation.new(); var state:={"kind":"hearth","state":"active"}
	visual.query=func(): return state.duplicate()
	game.region_root.add_child(visual)
	await process_frame
	check(visual._embers!=null,"Native world rig failed to become ready: "+str(visual.profile.validation_errors() if visual.profile else []))
	if not visual._embers: await fixture.close(); quit(1); return
	check(visual._embers.use_fixed_seed and not visual._embers.emitting,"Reduced-motion particles emitted or used gameplay randomness")
	state.state="complete"; visual._process(.2)
	check(visual.snapshot.state=="complete","World animation failed to read its real state adapter")
	var old_scope:=director.scope; var generation:=director.generation
	director.leave_region()
	check(director.scope==null and director.snapshot().effects==0 and director.audio._voices.is_empty() and director.generation>generation,"Region exit retained transient effects or audio")
	check(not director.emit_cue(&"harvest",point),"Stale scope admitted a world effect")
	director.enter_region(old_scope,preload("res://content/presentation/outdoors.tres")); await process_frame
	check(director.emit_cue(&"harvest",point,"same_fact"),"New region retained old cue deduplication")
	PresentationPreferences.set_option("reduced_motion",original_motion); PresentationPreferences.set_option("effects_quality",original_quality)
	await fixture.close()
	if failures.is_empty(): print("PASS presentation system: native resource safety, original sound hashes, bounds/priority/dedup/culling, no gameplay RNG or mutation, motion preferences and region lifecycle")
	quit(0 if failures.is_empty() else 1)

