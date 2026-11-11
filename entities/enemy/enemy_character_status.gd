extends Node2D
## Reads the same resources and pending plan as the player HUD.
var actor: Enemy
var _clock := 0.0
var _label: Label
func _ready() -> void:
	_label=Label.new()
	_label.position=Vector2(-100,-98)
	_label.size.x=200
	_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",11)
	_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
func _process(delta: float) -> void:
	_clock-=delta
	if _clock>0:return
	_clock=.1
	# Hidden labels still pay shaping/layout costs when their text changes. Gate
	# the expensive status projection before querying it; bars remain independent.
	queue_redraw()
	_label.visible=is_instance_valid(actor.player) and actor.position.distance_squared_to(actor.player.position)<260.0*260.0 and actor.can_see(actor.player)
	if not _label.visible:return
	var plan := actor.skill_manager.combinations.pending
	var physical:=actor.actor_context.actions if actor.actor_context else null
	var buffs:=actor.get_node("BuffManager") as BuffManager
	var partial:=buffs.buildup.snapshot()
	var in_combat:=not actor.story_truce and physical and (not partial.is_empty() or buffs.has_buff("burning") or buffs.has_buff("poison") or physical.busy() or physical.guarding or is_instance_valid(actor.player) and actor.player.actor_context and (actor.player.actor_context.actions.busy() or actor.player.actor_context.actions.guarding or actor.player.actor_context.actions.counter_remaining>0))
	var awareness:=actor.actor_context.awareness if actor.actor_context else null
	var warning: bool=awareness!=null and awareness.phase=="warning" and awareness.rules!=null
	var text:=actor.enemy_name
	if awareness:text+="\n"+awareness.caption()
	# Encounter rules live on this regional awareness, not on the shared body.
	# Warning is the existing opportunity to read a counter and withdraw, without
	# opening a near-range inventory panel or stopping normal AI.
	if warning: text+="\n"+awareness.rules.observation
	for id in partial:
		var buildup: Dictionary=partial[id]
		var definition:=WeaponEnchantment.definition(id)
		text+=" · %s蓄积%.0f%%"%[ElementCatalog.affinity_label(definition.tags),100*float(buildup.value)/definition.threshold]
	if not in_combat: text+="\nMP %d/%d"%[actor.mana_component.mp,actor.mana_component.max_mp]
	for entry in (actor.get_node("BuffManager") as BuffManager).get_active_buff_entries():
		if entry.status_id in ["ember_focus","focus","frost_stride","resonant_guard"]:
			text+=" · "+entry.name
	if not plan.is_empty():
		text+="\n"+plan.action.display_name+(" → "+plan.effect_label if plan.action.display_name!=plan.effect_label else "")
	if actor.physical_loot and not in_combat and actor.position.distance_squared_to(actor.player.position)<PlayerInputController.INTERACT_RANGE*PlayerInputController.INTERACT_RANGE:
		text += "\n[F] 交涉 · 停战中" if actor.story_truce else "\n[F] 观察穿戴与行囊"
	var width:=240.0 if warning else 200.0
	if _label.text!=text or _label.size.x!=width:
		_label.size.x=width
		_label.text=text
		_label.size.y=0
	_label.position=Vector2(-width*.5,-54-_label.get_combined_minimum_size().y if warning else -76 if in_combat else -98)
	if is_instance_valid(actor.player):
		_label.modulate=Color("a5d5bd") if actor.story_truce else Color.WHITE
func _draw() -> void:
	if actor.actor_context and actor.actor_context.rules.tactical_combat:
		draw_rect(Rect2(-23,-30,46,3),Color(.1,.1,.1,.8))
		draw_rect(Rect2(-23,-30,46*actor.actor_context.actions.stability.current/100,3),Color("a5b4b6"))
	for entry in [[actor.health_component.hp,actor.health_component.max_hp,-42,Color(.8,.25,.18)],[actor.mana_component.mp,actor.mana_component.max_mp,-36,Color(.2,.5,.9)]]:
		draw_rect(Rect2(-23,entry[2],46,4),Color(.1,.1,.1,.8))
		draw_rect(Rect2(-23,entry[2],46*clampf(float(entry[0])/entry[1],0,1),4),entry[3])
