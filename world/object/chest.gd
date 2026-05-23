class_name Chest
extends MapObject
## 宝箱 — MapObject + Interactable + LootTable
##
## 玩家按 E 交互时：
##   1. 从 loot_table 随机抽取物品
##   2. 生成掉落物
##   3. 标记为已开启（一次性）


@export var loot_table: LootTable

var _opened: bool = false


func _ready() -> void:
	# fallback：场景实例化时 object_data 可能未持久化，创建默认数据
	if not object_data:
		var data := MapObjectData.new()
		data.display_name = "宝箱"
		data.max_hp = 10
		data.is_interactable = true
		object_data = data
	super._ready()
	add_to_group("interactable")
	# 注册 Interactable 接口
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.set_callback(_on_interact_chest)
	add_child(interactable)


func _on_interact_chest(_actor: Node2D) -> void:
	if _opened:
		return
	if _state != "INTACT":
		return

	_opened = true
	_state = "DAMAGED"
	_apply_visual()

	var drops: Array[Dictionary] = []
	if loot_table:
		drops = loot_table.roll()

	# fallback: 无掉落表或空表时至少掉一个血包
	if drops.is_empty():
		drops.append({"item_path": "res://entities/pickups/health_pickup.tscn", "count": 1})

	for drop in drops:
		_spawn_item(drop.get("item_path", ""), drop.get("count", 1))


func _spawn_item(item_path: String, count: int) -> void:
	if item_path.is_empty():
		return
	var item := load(item_path)
	if not item:
		push_warning("[Chest] 无法加载物品: %s" % item_path)
		return

	# 生成掉落物节点
	var pickup_scene := load("res://entities/pickups/health_pickup.tscn") as PackedScene
	if not pickup_scene:
		return

	for i in range(count):
		var pickup := pickup_scene.instantiate()
		pickup.global_position = global_position + Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)
		get_parent().add_child(pickup)


func _apply_visual() -> void:
	if _opened:
		# 已开启：灰色半透明
		var spr := get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			spr.modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		super._apply_visual()
