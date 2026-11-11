extends SceneTree
## Controlled physics clock/target. Presentation must not become a second combat executor.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n := 3) -> void:
	for i in n: await process_frame
func weapon_feedback(actor: Player,rig: ActorAnimationController,visual: ActorEquipmentVisual) -> void:
	var actions:=actor.actor_context.actions; var store:=actor.actor_context.items
	var weapon_visual: ActorWeaponVisual
	for child in visual.get_children():
		if child is ActorWeaponVisual: weapon_visual=child
	check(weapon_visual!=null,"Missing shared weapon visual")
	if not weapon_visual: return
	store.receive("player","arrow",8,true)
	var signatures: Dictionary={}
	for pair in [["river_sabre","blade","slash"],["river_spear","spear","thrust"],["river_staff","staff","sweep"],["river_bow","bow","shot"]]:
		actions.cancel(); actions.stamina.current=100
		if store.find_owned("player",pair[0]).is_empty(): store.receive("player",pair[0],1)
		var uid:=store.find_owned("player",pair[0]); check(store.equip("player",uid).accepted,"Could not equip feedback weapon: "+pair[0])
		var request:=Action.melee(actor); request.direction=Vector2.RIGHT
		check(actions.try_action(request).accepted,"Could not start feedback action: "+pair[0])
		actions.advance(actions.profile.windup*.9); rig.render(0)
		var anticipated:=rig.rig.position
		var view:=weapon_visual.visual_snapshot()
		check(view.uid==uid and view.shape==pair[1] and view.phase=="windup","Weapon view lost its actual UID/shape/phase")
		check(rig.body.animation==StringName(pair[2]+"_e") and anticipated.dot(Vector2.RIGHT)<0,"Body did not anticipate its own weapon along the locked facing: "+pair[0])
		check(bool(view.nocked)==(pair[1]=="bow"),"Nocked ammunition is not tied to real bow windup")
		signatures[pair[1]]=str([rig.rig.position,rig.main_hand.position,rig.off_hand.position])
		var stock:=store.snapshot();var elapsed:=actions.elapsed;var remaining:=actions.remaining;var stamina:=actions.stamina.current;var position:=actor.position
		rig.render(2); weapon_visual.visual_snapshot()
		check(rig.rig.position.is_equal_approx(anticipated),"Repeated seek accumulated facing-relative visual displacement")
		check(store.snapshot()==stock and actor.position==position and actions.elapsed==elapsed and actions.remaining==remaining and actions.stamina.current==stamina,"Feedback query/render changed physical state")
		actions.advance(actions.profile.windup*.1+actions.profile.active*.6); rig.render(0)
		view=weapon_visual.visual_snapshot()
		check(view.phase=="active" and not view.nocked,"Released arrow remained drawn on the bow")
		check(rig.rig.position.dot(Vector2.RIGHT)>0 if pair[1]!="bow" else rig.rig.position.dot(Vector2.RIGHT)<0,"Release silhouette did not distinguish planted bow from melee extension")
		actions.cancel(); actions.stamina.current=100
		request.action_type=Action.ActionType.HEAVY_ATTACK
		check(actions.try_action(request).accepted,"Could not start heavy feedback action")
		actions.advance(actions.profile.windup*.9);rig.render(0)
		check(rig.current.resolved==pair[2]+"_heavy" and rig.rig.position.length()>anticipated.length(),"Heavy strike reused the light body anticipation")
		actions.cancel();rig.render(0)
		check(rig.rig.position.is_equal_approx(Vector2.ZERO),"Weapon pose leaked after cancellation")
	for first in signatures:
		for second in signatures:
			if first!=second:check(signatures[first]!=signatures[second],"Weapon silhouettes collapsed into one gesture")
	actions.cancel(); actions.stamina.current=100
	store.equip("player",store.find_owned("player","river_staff"))
	for state in ["sweep","thrust","sweep_reverse"]:
		var request:=Action.melee(actor);request.direction=Vector2.RIGHT
		check(actions.try_action(request).accepted,"Staff combo feedback action refused")
		rig.render(0)
		check(rig.current.resolved==state,"Staff reverse finisher fell back to an idle body")
		actions.advance(actions.remaining)
	store.equip("player",store.find_owned("player","river_sabre"))
	var guard:=Action.new();guard.action_type=Action.ActionType.GUARD;guard.params["held"]=true;guard.direction=Vector2.RIGHT
	check(actions.try_action(guard).accepted,"Guard presentation request refused")
	rig.render(0)
	check(rig.body.animation==&"guard_e" and rig.current.resolved=="guard","Guard still uses the casting gesture")
	actions.cancel();rig.render(0)
	actions.stamina.current=100
func run() -> void:
	var assets: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://content/art/third_party/puny/animation_assets.json"))
	check(assets is Array,"Missing animation asset provenance")
	if assets is Array:
		for asset in assets: check(FileAccess.get_sha256("res://"+str(asset.path))==str(asset.vendored_sha256),"Animation asset/license hash mismatch")
	var catalog:=ActorAnimationCatalog.default_catalog()
	check(catalog.validation_errors().is_empty(),"Live animation catalog invalid")
	for key in ["puny_body","puny_reference","puny_mage"]:
		var profile:=load("res://content/animations/"+key+".tres") as ActorAnimationProfile
		check(profile.validation_errors().is_empty(),"Animation profile invalid: "+key)
		for direction in range(8): check(ActorAnimationProfile.direction_index(Vector2.DOWN.rotated(direction*PI/4))==direction,"Eight-direction row mismatch")
	var profile:=catalog.definition(&"puny_body")
	for key in ["slash","slash_reverse","slash_heavy","thrust","thrust_heavy","sweep","sweep_reverse","sweep_heavy","shot","shot_heavy","guard"]:
		check(profile.resolve(key).frames==StringName(key),"Weapon body still uses the generic gesture: "+key)
	# Source weapon pixels must never enter live characters, irrespective of animation semantics.
	for name in profile.sprite_frames.get_animation_names():
		for index in profile.sprite_frames.get_frame_count(name):
			var texture:=profile.sprite_frames.get_frame_texture(name,index) as AtlasTexture
			check(texture!=null and int(texture.region.position.x/32) in [0,1,2,3,16,17,18,20,21,22,23],"Baked weapon entered the live body profile")
	var invalid:=profile.duplicate(true) as ActorAnimationProfile
	invalid.fallback={"a":"b","b":"a"}
	check(not invalid.validation_errors().is_empty(),"Cyclic visual fallback accepted")
	invalid=profile.duplicate(true) as ActorAnimationProfile
	invalid.facing_relative_poses=[&"missing_pose"]
	check(not invalid.validation_errors().is_empty(),"Unresolved visual offset basis accepted")
	invalid=profile.duplicate(true) as ActorAnimationProfile
	invalid.poses=AnimationLibrary.new()
	for name in profile.poses.get_animation_list(): invalid.poses.add_animation(name,profile.poses.get_animation(name))
	var call_animation:=Animation.new(); var track:=call_animation.add_track(Animation.TYPE_METHOD); call_animation.track_set_path(track,NodePath("..")); invalid.poses.add_animation("forbidden",call_animation)
	check(not invalid.validation_errors().is_empty(),"Imported callback track could commit gameplay")
	var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true)
	var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	actor.position=Vector2(-4000,800)
	var visual:=actor.get_node("EquipmentVisual") as ActorEquipmentVisual
	var rig:=visual.animator; rig.set_process(false)
	check(rig.profile==profile and rig.poses.has_animation("slash") and actor.get_node("Sprite2D").self_modulate.a==0,"Live actor did not install the native layered rig")
	check(not rig.set_profile(invalid) and rig.profile==profile,"Bad animation resource replaced a live profile")
	store.receive("player","river_sabre",1); store.equip("player",store.find_owned("player","river_sabre"))
	var request:=Action.melee(actor); request.direction=Vector2.RIGHT
	check(actions.try_action(request).accepted,"Could not begin physical strike")
	var cost:=actions.stamina.current; var position:=actor.position; var inventory:=store.snapshot()
	var duration:=actions.remaining; var elapsed:=actions.elapsed
	rig.render(5)
	check(actions.remaining==duration and actions.elapsed==elapsed and actor.position==position and store.snapshot()==inventory and actions.stamina.current==cost,"Rendering advanced a domain clock, moved the body or paid resources")
	check(rig.current.get("phase","")=="windup" and rig.current.get("direction",-1)==6 and rig.body.animation==&"slash_e","Presentation did not read the actual locked direction/windup")
	var cues: Array[String]=[]; rig.cue_emitted.connect(func(kind: String,_token: String): cues.append(kind))
	actions.advance(actions.profile.windup+.01); rig.render(0)
	var live_frame:=rig.body.frame; var socket:=rig.socket_position(&"main_hand")
	rig.render(40); rig.render(40)
	check(rig.current.get("phase","")=="active" and rig.body.frame==live_frame and cues.count("weapon_release")==1 and socket.is_finite(),"Native animation drifted/repeated the physical release cue")
	actions.advance(actions.profile.active+.01); rig.render(0)
	check(rig.current.get("phase","")=="recovery","Recovery pose ignored the authoritative timeline")
	actions.cancel(); rig.render(0)
	check(rig.current.get("state","")=="idle" and rig.rig.position.is_equal_approx(Vector2.ZERO) and is_zero_approx(rig.rig.rotation),"Cancel retained an old pose/root displacement")
	# Committed cues cannot disappear when the renderer skips the whole active interval.
	actions.stamina.current=100; actions.try_action(request); actions.advance(actions.remaining)
	check(cues.count("weapon_release")==2,"Skipping render frames lost an actual committed release cue")
	rig.render(0)
	weapon_feedback(actor,rig,visual)
	# Footsteps follow authored contacts and actual distance, independent of sprite frame count.
	actor.velocity=Vector2.RIGHT*100; rig.render(0)
	var steps:=cues.count("footstep")
	actor.position+=Vector2(33,0); rig.render(.1)
	check(cues.count("footstep")==steps+1,"A real stride missed its authored foot contact")
	actor.position+=Vector2(500,0); rig.render(.1)
	check(cues.count("footstep")==steps+1,"Teleport minted footstep cues")
	actor.position=position; actor.velocity=Vector2.ZERO; rig.render(0)
	# A late idle update, heal and weapon swap cannot continue an old attack.
	rig.render(3)
	CombatExecutor.report_hit(game.active_enemies[0],actor,12,actor.position,SkillData.new(),["physical"],"animation.hurt")
	rig.render(.3); actor.health_component.heal(5); rig.render(.01)
	check(rig.current.get("state","")=="idle","Healing caused a damage reaction")
	# Loading/attribute changes may lower HP without a new damage fact.
	actor.health_component.hp-=1; actor.health_component.health_changed.emit(actor.health_component.hp,actor.health_component.max_hp); rig.render(0)
	check(rig.current.get("state","")=="idle","A non-damage health projection caused a fake hurt reaction")
	var invalid_character:=ActorCharacterData.new(); invalid_character.id="invalid"; invalid_character.title="invalid"; invalid_character.animation_profile=load("res://content/animations/puny_reference.tres")
	check(not invalid_character.validation_errors().is_empty(),"An actor could equip a reference sheet with baked weapons")
	# Actual death creates one animated loot body; the item UIDs remain the source of truth.
	var enemy:=game.active_enemies[0]; enemy.position=actor.position+Vector2(90,0)
	var id:=str(enemy.get_meta("frontier_claim")); var before:=GrayriverLoot.snapshot(enemy)
	CombatExecutor.report_hit(actor,enemy,9999,enemy.position,SkillData.new(),["physical"],"animation.death"); await frames()
	var corpse:=game.loot.corpses.get(id) as GrayriverLootCorpse
	check(corpse!=null and corpse.gear.animator!=null and corpse.fresh_death,"Accepted lethal hit failed to mount the live death rig")
	if corpse:
		corpse.gear.animator.render(.7)
		check(corpse.gear.animator.current.state=="death" and corpse.gear.animator.current.frame==2,"Corpse did not finish and hold its terminal frame")
		check(game.progress.loot_records[id].equipment==before.equipment and game.progress.loot_records[id].materials==before.materials,"Death animation changed recoverable contents")
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	corpse=game.loot.corpses.get(id) as GrayriverLootCorpse
	check(corpse!=null and not corpse.fresh_death and corpse.gear.animator.current.frame==2,"Reload replayed death instead of restoring the terminal pose")
	check(CampaignSession.valid_snapshot(game.session.snapshot()),"Animation metadata invalidated campaign persistence")
	await fixture.close()
	if failures.is_empty(): print("PASS actor animation: eight directions, safe live frames/callbacks, actual phase/UID/cost invariance, per-family cue, cancel/reset, no heal flinch, lethal loot animation and terminal-pose save/reentry; controlled clock/target")
	quit(0 if failures.is_empty() else 1)
