class_name FieldPlacementPreview
extends Node2D

var _tint := Color.WHITE
var _radius := 96.0

func _ready() -> void:
	z_index = 2
	hide()

func _process(_delta: float) -> void:
	var actor := get_parent() as Player
	var controller := actor.skill_manager.combinations
	var action: SkillData
	var point := actor.global_position
	if not controller.pending.is_empty() and not controller.pending.action.field_type.is_empty():
		action = controller.pending.action
		point = controller.pending.position
	else:
		for source in actor.aiming_sources:
			var skill := actor._get_skill_for_source(source)
			if skill and not skill.field_type.is_empty():
				action = skill
	if not action:
		hide()
		return
	_radius = controller.pending.placement_radius if not controller.pending.is_empty() else controller.build_plan(action, actor).placement_radius
	show()
	global_position = point
	_tint = Color(0.3, 0.75, 1.0) if action.get_id() == "frost_sigil" else Color(1.0, 0.6, 0.2)
	if action.get_id() == "storm_sigil":
		_tint = Color(0.85, 0.65, 1.0)
	if not controller._can_place(actor, point, _radius):
		_tint = Color(1, 0.2, 0.2)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(_tint, 0.06))
	for i in range(12):
		var angle := i * TAU / 12
		draw_arc(Vector2.ZERO, _radius, angle, angle + 0.3, 8, Color(_tint, 0.75), 2, true)
