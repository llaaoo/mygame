class_name SpellWorldObject
extends Area2D
## Spell puzzles consume hit events, including zero-damage utility hits.
signal solved(spec: Dictionary)
var spec: Dictionary
var completed := false
var _steps: Array[int] = []
var _label: Label

func _ready() -> void:
	collision_layer = 0 if completed else 8
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22
	shape.shape = circle
	add_child(shape)
	for route in spec.routes:
		_steps.append(0)
	_label = Label.new()
	_label.position = Vector2(-120, -55)
	_label.size.x = 240
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	_refresh()
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_HIT, _on_hit)
	add_to_group("interactable")
	var interaction := Interactable.new()
	interaction.name = "Interactable"
	interaction.set_callback(func(_actor: Node2D):
		var scene := get_tree().current_scene
		if scene is MVPGame:
			scene.ui.show_panel(spec.title, "机关已解开，奖励已保存。" if completed else spec.hint, [{"title": "继续探索", "callback": scene.ui.close_modal}]))
	add_child(interaction)

func _exit_tree() -> void:
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_HIT, _on_hit)

func take_damage(_amount: int) -> void:
	pass # This object responds to elements rather than health depletion.

func _on_hit(event: CombatEvent) -> void:
	if completed or event.target != self:
		return
	var tags: Array = event.skill.tags if event.skill else event.data.get("tags", [])
	for i in range(_steps.size()):
		var route: Array = spec.routes[i]
		if str(route[_steps[i]]) in tags:
			_steps[i] += 1
			if _steps[i] >= route.size():
				completed = true
				set_deferred("collision_layer", 0)
				solved.emit(spec)
				break
	_refresh()

func _refresh() -> void:
	var count := 0
	for step in _steps:
		count = maxi(count, step)
	_label.text = "[E] " + str(spec.title) + (" · 已解开" if completed else (" · 共鸣%d" % count if count > 0 else ""))
	queue_redraw()

func _draw() -> void:
	var color := Color(0.4, 0.9, 0.65) if completed else Color(0.8, 0.6, 1.0)
	draw_circle(Vector2.ZERO, 23, Color(color, 0.18))
	draw_rect(Rect2(-18, -18, 36, 36), color, false, 2)
	draw_arc(Vector2.ZERO, 13, 0, TAU, 24, color, 2)
	if completed:
		draw_polyline(PackedVector2Array([Vector2(-9, 0), Vector2(-2, 8), Vector2(11, -8)]), color, 3)
