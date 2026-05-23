@tool
extends EditorScript

func _run() -> void:
	var path := "res://main.tscn"
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()

	var replacements := {
		"path=\"res://maps/overworld.tscn\"": "path=\"res://world/maps/overworld.tscn\"",
		"path=\"res://runtime/combat/skills/manager/skill_manager.gd\"": "path=\"res://gameplay/abilities/manager/skill_manager.gd\"",
		"path=\"res://components/stats_component.gd\"": "path=\"res://entities/components/stats_component.gd\"",
		"path=\"res://runtime/combat/input_setup.gd\"": "path=\"res://core/input_setup.gd\"",
		"path=\"res://runtime/game_runtime.gd\"": "path=\"res://core/game_runtime.gd\"",
		"path=\"res://runtime/world/world_runtime.gd\"": "path=\"res://world/world_runtime.gd\"",
		"path=\"res://runtime/simulation/simulation_runtime.gd\"": "path=\"res://gameplay/interaction/simulation_runtime.gd\"",
	}

	for old in replacements:
		var new_path: String = replacements[old]
		if text.contains(old):
			text = text.replace(old, new_path)
			print("  ✅ %s" % old.get_file())

	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	print("✅ main.tscn fixed")

	# Also fix burning_forest.tscn
	var bf_path := "res://world/regions/burning_forest/burning_forest.tscn"
	if FileAccess.file_exists(bf_path):
		var bf := FileAccess.open(bf_path, FileAccess.READ)
		var bf_text := bf.get_as_text()
		bf.close()
		# Fix script path
		bf_text = bf_text.replace(
			"path=\"res://world/regions/burning_forest.gd\"",
			"path=\"res://world/regions/burning_forest/burning_forest.gd\""
		)
		var bf_out := FileAccess.open(bf_path, FileAccess.WRITE)
		bf_out.store_string(bf_text)
		bf_out.close()
		print("✅ burning_forest.tscn fixed")
