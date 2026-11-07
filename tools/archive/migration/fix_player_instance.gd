@tool
extends EditorScript

## 在 main.tscn 的 Player + Enemy 实例上显式设碰撞层，打破编辑器缓存

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if not packed:
		print("❌ 加载 main.tscn 失败")
		return

	var root := packed.instantiate()

	# Player
	var player := root.get_node_or_null("Player") as CharacterBody2D
	if player:
		player.collision_layer = 2
		player.collision_mask = 1
		print("✅ Player: layer=2 mask=1")

	# 所有 Enemy 实例（在 Overworld 下）
	var overworld := root.get_node_or_null("Overworld")
	if overworld:
		for child in overworld.get_children():
			if child is CharacterBody2D and child.has_method("take_damage"):
				child.collision_layer = 2
				child.collision_mask = 1
				print("✅ %s: layer=2 mask=1" % child.name)

	var repacked := PackedScene.new()
	repacked.pack(root)
	var err := ResourceSaver.save(repacked, "res://main.tscn")
	if err == OK:
		print("✅ main.tscn 已保存")
	else:
		print("❌ 保存失败: ", err)

	root.free()
