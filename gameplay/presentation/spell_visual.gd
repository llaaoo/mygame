class_name SpellVisual
extends Node2D
## Bounded procedural effects: no collision, gameplay RNG, status or damage calls.
var kind := "projectile"
var tags: Array[String] = []
var tint := Color.WHITE
var radius := 12.0
var duration := .5
var elapsed := 0.0

static func attach(host: Node2D, skill: SkillData, mode: String, extent: float = 12.0, life: float = .5) -> SpellVisual:
	var effect := SpellVisual.new()
	effect.kind = mode
	effect.tags = skill.tags.duplicate()
	effect.tint = ElementVisuals.color_for(skill.tags)
	effect.radius = extent
	effect.duration = maxf(.05, life)
	host.add_child(effect)
	if mode=="burst" and skill.aoe_visual and skill.aoe_visual.hit_effect:
		PresentationScene.attach(effect,skill.aoe_visual.hit_effect)
	return effect

static func impact(host: Node2D, skill: SkillData,play_sound := false) -> void:
	if not host.is_inside_tree() or not skill: return
	var director:=PresentationDirector.for_node(host)
	var authored:=skill.visual.hit_effect if skill.visual else null
	if not authored and skill.aoe_visual: authored=skill.aoe_visual.hit_effect
	if authored and director:
		director.emit_cue(&"authored_impact",host.global_position,"",skill.visual.sound_hit if play_sound and skill.visual else null,authored)
		return
	if play_sound and director: director.emit_cue(&"spell_hit",host.global_position,"",skill.visual.sound_hit if skill.visual else null)
	if host.get_tree().get_nodes_in_group("spell_impact_visual").size() >= PresentationPreferences.effect_limit(): return
	var scope := host.get_parent() as Node2D
	if not scope: return
	var effect := attach(scope, skill, "impact", 23, .24)
	effect.global_position = host.global_position
	effect.add_to_group("spell_impact_visual")

func _ready() -> void:
	z_index = 1

func _process(delta: float) -> void:
	elapsed += delta
	if kind != "projectile" and elapsed >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	if kind == "projectile":
		_draw_projectile()
		return
	var progress := clampf(elapsed / duration, 0, 1)
	var alpha := 1.0 - progress
	var wave := radius * (0.28 + .72 * progress)
	draw_circle(Vector2.ZERO, radius, Color(tint, alpha * .065))
	draw_arc(Vector2.ZERO, wave, 0, TAU, 48, Color(tint, alpha * .75), 2, true)
	if kind == "burst":
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(tint, alpha * .45), 1, true)
	for i in range(10):
		var angle := TAU * i / 10.0
		var point := Vector2.from_angle(angle) * wave
		var tail := point * .78
		if "ice" in tags:
			draw_line(tail, point, Color(tint.lightened(.4), alpha), 2, true)
		elif "poison" in tags or "water" in tags:
			draw_circle(point, 2 + i % 3, Color(tint, alpha * .6), false, 1, true)
		else:
			draw_line(tail, point + Vector2.from_angle(angle + .3) * 4, Color(tint, alpha), 2, true)

func _draw_projectile() -> void:
	var time:=elapsed*PresentationPreferences.motion_scale()
	var pulse := .9 + .1 * sin(time * 12)
	for i in range(7, 0, -1):
		var point := Vector2(-i * 4, sin(time * 12 - i) * 1.8)
		draw_circle(point, maxf(1, radius * .5 - i * .35), Color(tint, (1 - i / 8.0) * .28))
	draw_circle(Vector2.ZERO, radius * 1.3 * pulse, Color(tint, .1))
	if "ice" in tags:
		draw_colored_polygon(PackedVector2Array([Vector2(radius, 0), Vector2(-radius * .6, -radius * .45), Vector2(-radius * .2, 0), Vector2(-radius * .6, radius * .45)]), tint)
		draw_line(Vector2(-radius * .5, 0), Vector2(radius, 0), Color.WHITE, 1, true)
	elif "lightning" in tags:
		draw_polyline(PackedVector2Array([Vector2(-22, 0), Vector2(-9, -5), Vector2(-12, 3), Vector2(3, -3), Vector2(12, 0)]), Color(tint, .35), 6, true)
		draw_polyline(PackedVector2Array([Vector2(-22, 0), Vector2(-9, -5), Vector2(-12, 3), Vector2(3, -3), Vector2(12, 0)]), tint.lightened(.5), 2, true)
	else:
		draw_circle(Vector2.ZERO, radius * .62 * pulse, Color(tint, .85))
		draw_circle(Vector2(radius * .18, -radius * .12), radius * .28, tint.lightened(.65))
	# Secondary material properties stay visible without replacing the main form.
	if tags.size() > 1:
		var index := 0
		for id in ["fire", "water", "ice", "lightning", "poison"]:
			if id not in tags: continue
			var color := ElementVisuals.color_for([id])
			if color == tint: continue
			draw_circle(Vector2(-9 - index * 5, 8), 2, color)
			index += 1
