@tool
extends EditorScript

## 给所有 MapObject 场景添加 StaticBody2D 物理碰撞体（WORLD_STATIC 层）

func _run() -> void:
	var scenes := [
		"res://world/object/oil_barrel.tscn",
		"res://world/object/wooden_crate.tscn",
		"res://world/object/wooden_fence.tscn",
		"res://world/object/ice_wall.tscn",
	]

	for scene_path in scenes:
		var packed := load(scene_path) as PackedScene
		if not packed:
			print("❌ 加载失败: ", scene_path)
			continue

		var root := packed.instantiate()
		
		# 检查是否已有 Body 节点
		if root.has_node("Body"):
			print("⏭ 已有 Body: ", scene_path)
			root.free()
			continue

		var hit_area := root.get_node_or_null("HitArea") as Area2D
		var hit_shape_node := hit_area.get_node_or_null("CollisionShape2D") if hit_area else null
		var hit_shape: Shape2D = hit_shape_node.shape if hit_shape_node else null

		if not hit_shape:
			print("⚠ 无碰撞形状，跳过: ", scene_path)
			root.free()
			continue

		# 创建 StaticBody2D 作为物理阻挡体
		var body := StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = 1   # WORLD_STATIC
		body.collision_mask = 0    # 纯阻挡，不检测
		root.add_child(body)
		body.owner = root  # 确保 pack 时正确序列化

		# 复用 HitArea 的碰撞形状
		var body_shape := CollisionShape2D.new()
		body_shape.name = "CollisionShape2D"
		body_shape.shape = hit_shape.duplicate(true)
		body.add_child(body_shape)
		body_shape.owner = root

		# 确保 Body 在 HitArea 前面（先阻挡再检测）
		root.move_child(body, 0)

		var repacked := PackedScene.new()
		repacked.pack(root)
		var err := ResourceSaver.save(repacked, scene_path)
		if err == OK:
			print("✅ %s → 已添加 Body (shape=%s)" % [scene_path.get_file(), hit_shape.get_class()])
		else:
			print("❌ 保存失败: ", scene_path)
		
		root.free()
	
	print("\n🎉 完成！")
