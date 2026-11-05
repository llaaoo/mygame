class_name SurfaceValve
extends Node2D
signal state_changed(mode: String)
var spec: SurfaceValveData
var mode := "off"
var _elapsed := 0.0
var _label: Label

func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)
	add_to_group("interactable")
	var interaction := Interactable.new()
	interaction.name = "Interactable"
	interaction.set_callback(cycle)
	add_child(interaction)
	_label = Label.new()
	_label.position = Vector2(-140, -48)
	_label.size.x = 280
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_refresh()
	refill()

func cycle(_actor: Node2D = null) -> void:
	var modes := ["off", "a", "b"]
	mode = modes[(modes.find(mode) + 1) % modes.size()]
	refill()
	_refresh()
	state_changed.emit(mode)

func tick(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0: return
	_elapsed = fmod(_elapsed, 1.0)
	refill()

func refill() -> void:
	if mode == "off" or not GameRuntime.instance: return
	var index := 0 if mode == "a" else 1
	if index >= spec.paths.size(): return
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	for point in spec.paths[index].points:
		var cell := SurfaceManager.cell_at(get_parent().to_global(point))
		var state: String = surfaces.get_surface(cell).get("state", "dry")
		if state in ["dry", "wet"]:
			surfaces.force_set_surface(cell, "wet", 12, spec.id)

func _refresh() -> void:
	var title := "关闭" if mode == "off" else spec.paths[0 if mode == "a" else 1].title
	_label.text = "[E] " + spec.title + " · " + title + "\n关闭→路线A→路线B；旧水自然消退"
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18, Color(0.15, .5, .8, .7))
	draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Color(.5, .85, 1), 3)
	draw_line(Vector2(-14, -14), Vector2(14, 14), Color.WHITE, 3)
