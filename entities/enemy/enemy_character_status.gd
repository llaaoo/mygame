extends Node2D
## Reads the same resources and pending plan as the player HUD.
var actor: Enemy
var _clock := 0.0
var _label: Label
func _ready() -> void:
	_label=Label.new()
	_label.position=Vector2(-100,-86)
	_label.size.x=200
	_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",11)
	add_child(_label)
func _process(delta: float) -> void:
	_clock-=delta
	if _clock>0:return
	_clock=.1
	var plan := actor.skill_manager.combinations.pending
	_label.text=actor.enemy_name+"\nMP %d/%d"%[actor.mana_component.mp,actor.mana_component.max_mp]
	for entry in (actor.get_node("BuffManager") as BuffManager).get_active_buff_entries():
		if entry.status_id in ["ember_focus","focus","frost_stride","resonant_guard"]:
			_label.text+=" · "+entry.name
	if not plan.is_empty():
		_label.text+="\n"+plan.action.display_name+(" → "+plan.effect_label if plan.action.display_name!=plan.effect_label else "")
	queue_redraw()
func _draw() -> void:
	for entry in [[actor.health_component.hp,actor.health_component.max_hp,-42,Color(.8,.25,.18)],[actor.mana_component.mp,actor.mana_component.max_mp,-36,Color(.2,.5,.9)]]:
		draw_rect(Rect2(-23,entry[2],46,4),Color(.1,.1,.1,.8))
		draw_rect(Rect2(-23,entry[2],46*clampf(float(entry[0])/entry[1],0,1),4),entry[3])
