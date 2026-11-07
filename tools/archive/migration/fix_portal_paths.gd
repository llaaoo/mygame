@tool
extends EditorScript

## 修复迁移后 .tscn 文件中残留的旧 ext_resource 路径

func _run() -> void:
	# 1. 修复 portal.tscn 中的脚本和形状引用
	_fix_scene("res://world/portals/portal.tscn", {
		"res://world/portal.gd": "res://world/portals/portal.gd",
		"res://world/portal_shape.tres": "res://world/portals/portal_shape.tres",
	})

	# 2. 修复 overworld.tscn 中的 portal 引用
	_fix_scene("res://world/maps/overworld.tscn", {
		"res://world/portal.tscn": "res://world/portals/portal.tscn",
	})

	# 3. 修复 main.tscn 中的 overworld 和其他引用
	_fix_scene("res://main.tscn", {
		"res://maps/overworld.tscn": "res://world/maps/overworld.tscn",
	})

	# 4. 修复 burning_forest.tscn 中的对象引用
	_fix_scene("res://world/regions/burning_forest/burning_forest.tscn", {
		"res://world/object/oil_barrel.tscn": "res://world/object/oil_barrel.tscn",
	})

	print("\n✅ 所有路径修复完成")


func _fix_scene(path: String, replacements: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		printerr("文件不存在: ", path)
		return

	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()

	var changed := false
	for old in replacements:
		var new_path: String = replacements[old]
		if old in text:
			text = text.replace(old, new_path)
			changed = true
			print("  %s: %s → %s" % [path.get_file(), old.get_file(), new_path.get_file()])

	if changed:
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(text)
		out.close()
		print("  ✅ 已保存: ", path.get_file())
