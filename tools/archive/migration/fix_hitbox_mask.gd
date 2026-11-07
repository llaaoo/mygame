@tool
extends EditorScript

func _run() -> void:
	var packed := load("res://entities/player/player.tscn") as PackedScene
	var root := packed.instantiate()
	var hitbox := root.get_node_or_null("AttackHitbox") as Area2D
	if hitbox:
		hitbox.collision_mask = 10  # ACTOR(2) | HURTBOX(8)
		print("✅ AttackHitbox mask = 10")
	
	var repacked := PackedScene.new()
	repacked.pack(root)
	ResourceSaver.save(repacked, "res://entities/player/player.tscn")
	root.free()
	print("✅ player.tscn saved")
