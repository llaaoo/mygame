extends SceneTree
## Authored geometry, independent of combat: every interaction remains reachable
## before repairing the middle bridge. Props can be broken by ordinary attacks.
const STEP := 32.0
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message); push_error(message)
func block_rect(blocked: Dictionary, rect: Rect2) -> void:
	for x in range(floori(rect.position.x / STEP), ceili(rect.end.x / STEP) + 1):
		for y in range(floori(rect.position.y / STEP), ceili(rect.end.y / STEP) + 1):
			if rect.has_point(Vector2(x,y)*STEP): blocked[Vector2i(x,y)] = true
func run() -> void:
	for region in GrayriverDefinition.build().regions:
		for puzzle in region.spell_objects:
			for route in puzzle.routes:
				if route.required_surface.is_empty(): continue
				var sample: Vector2 = puzzle.pos + route.surface_offset
				var center := Vector2(SurfaceManager.cell_at(sample))*64+Vector2(32,32)
				check(sample.distance_to(center)<1,"Ground detector lies on a fragile grid boundary: "+puzzle.id)
		var layout := region.make_layout()
		region.reserve_interaction_space(layout)
		var blocked := {}
		for obstacle in layout.obstacles:
			block_rect(blocked,Rect2(obstacle.position-obstacle.size*.5,obstacle.size).grow(18))
		if region.open_field:
			block_rect(blocked,Rect2(170,300,260,400).grow(18))
			for x in range(-3,44):
				for y in range(-102,-73):
					if ((Vector2(x,y)*STEP-Vector2(650,-2800))/Vector2(718,438)).length_squared() <= 1: blocked[Vector2i(x,y)] = true
		var start := Vector2i((layout.entry_offset/STEP).round())
		var reached := {start:true}
		var queue: Array[Vector2i] = [start]
		var index := 0
		while index < queue.size():
			var point := queue[index]
			index += 1
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = point+direction
				var pos := Vector2(next)*STEP
				if reached.has(next) or blocked.has(next) or absf(pos.x)>layout.arena_size.x*.5-24 or absf(pos.y)>layout.arena_size.y*.5-24: continue
				reached[next]=true
				queue.append(next)
		for item in region.interaction_points():
			var cell := Vector2i((item.pos/STEP).round())
			var accessible := false
			for x in range(-1,2):
				for y in range(-1,2):
					if reached.has(cell+Vector2i(x,y)): accessible=true
			check(accessible,"Unreachable interaction in %s at %s"%[region.id,item.pos])
		if region.open_field:
			check(not reached.has(Vector2i(9,15)),"Unrepaired middle bridge can be crossed")
			check(reached.has(Vector2i(10,-47)) and reached.has(Vector2i(10,75)),"North bridge or south ford unavailable")
	if errors.is_empty(): print("Grayriver routes passed: all authored interactions and dungeon exits reachable without bridge repair or consumables; deep lake/river stay blocked")
	quit(0 if errors.is_empty() else 1)
