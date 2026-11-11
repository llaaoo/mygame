extends "res://tests/support/input_scene_probe.gd"
## Controlled arena positions/equipment, authored opponents and normal AI.
## Observes actual executor phases while real RMB guards; no injected AI actions.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
const STATUS:=preload("res://entities/enemy/enemy_character_status.gd")
const CASES: Array[Dictionary]=[
	{"id":"river.enemy.camp.forest.3","distance":160.0,"caption":"近击起手"},
	{"id":"river.enemy.camp.fieldcraft.mauler.v1","distance":125.0,"caption":"重击起手"},
	{"id":"river.enemy.camp.fieldcraft.archer.v1","distance":220.0,"caption":"远射起手"},
]
func run() -> void:
	root.size=Vector2i(1152,648)
	for entry in CASES:
		var fixture:=Fixture.new(self);game=await fixture.boot()
		var actor:=game.player
		var foe:=game.session.actor_for_id(str(entry.id)) as Enemy
		check(foe!=null,"Missing authored phase opponent: "+str(entry.id))
		if not foe:await fixture.close();continue
		var view: Node2D
		for child in foe.get_children():
			if child.get_script()==STATUS:view=child
		check(view!=null,"Missing live status projection: "+str(entry.id))
		if not view:await fixture.close();continue
		var label:=view.get("_label") as Label
		var store:=game.session.inventory
		store.receive("player","river_sabre",1);store.receive("player","river_shield",1)
		store.equip("player",store.find_owned("player","river_sabre"));store.equip("player",store.find_owned("player","river_shield"))
		actor.position=Vector2(-4000,800);foe.position=actor.position+Vector2(float(entry.distance),0);foe._home_position=foe.position
		actor.get_node("Camera2D").reset_smoothing()
		# Observe before enabling AI: the first ranged action can already start
		# during aim_world's awaited frame. Require its committed family as well.
		var serial:=foe.actor_context.actions._attack_sequence
		var starts: Array[String]=[]
		var observe_start:=func(fact: Dictionary):
			if fact.kind=="physical_action_started" and fact.source==foe.actor_context.id:starts.append(str(fact.data.family))
		game.session.facts.committed.connect(observe_start)
		for enemy in game.active_enemies:enemy.process_mode=Node.PROCESS_MODE_INHERIT
		GameRuntime.instance.set_process(true)
		await aim_world(foe.position)
		var windup_seen:=false;var recovery_seen:=false;var guarding:=false
		var observed_family:=""
		var deadline:=Time.get_ticks_msec()+10000
		while Time.get_ticks_msec()<deadline and not actor.health_component.is_dead and not (windup_seen and recovery_seen):
			var physical:=foe.actor_context.actions
			var snapshot:=physical.presentation_snapshot()
			if str(snapshot.get("phase",""))=="windup" and label.visible and label.text.contains(str(entry.caption)):
				windup_seen=true
				observed_family=str(snapshot.get("token",""))
				if not guarding:
					await pointer_button(MOUSE_BUTTON_RIGHT,true);guarding=true
			if windup_seen and str(snapshot.get("token",""))==observed_family and str(snapshot.get("phase",""))=="recovery" and label.visible and label.text.contains("收招 · 寻机还击"):
				recovery_seen=true
				await capture("enemy-phase-"+str(entry.caption))
			await frames(1)
		await pointer_button(MOUSE_BUTTON_RIGHT,false)
		check(windup_seen,"Normal AI did not expose the actual "+str(entry.caption)+" phase")
		check(recovery_seen,"Actual shared recovery was not readable: "+str(entry.id))
		check(foe.actor_context.actions._attack_sequence>serial and starts.has(observed_family),"Phase labels were not backed by this opponent's committed physical action: "+str(entry.id))
		check(not paused,"Reading physical phases paused normal combat")
		if str(entry.caption)=="远射起手":
			# The label's existing observation boundary must still hide phases in cover.
			var wall:=StaticBody2D.new();wall.collision_layer=1;wall.collision_mask=0
			wall.position=actor.position.lerp(foe.position,.5)
			var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(12,160)
			collision.shape=shape;wall.add_child(collision);game.region_root.add_child(wall)
			var hide_deadline:=Time.get_ticks_msec()+500
			while Time.get_ticks_msec()<hide_deadline and label.visible:await frames(1)
			check(not foe.can_see(actor) and not label.visible,"Covered opponent still disclosed its live phase")
		game.session.facts.committed.disconnect(observe_start)
		await fixture.close()
	if failures.is_empty():print("PASS enemy phase input: authored ordinary/heavy/archer normal-AI windups and shared recovery labels, real RMB, cover gating; controlled arena/equipment, not a balance benchmark")
	quit(0 if failures.is_empty() else 1)
