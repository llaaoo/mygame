class_name DamageNumberSpawner
extends Node
## 伤害数字生成器 — 监听 CombatEventBus，在命中位置生成浮动数字
##
## 挂载到场景根节点（get_tree().current_scene）
## 订阅: ON_DAMAGE → 红色伤害数字, ON_HEAL → 绿色治疗数字

var _world: Node = null


func _ready() -> void:
	# 伤害数字必须渲染在 CanvasItem 下（Node2D 不能直接挂在纯 Node 下）
	_world = get_tree().current_scene
	call_deferred("_subscribe")


func _subscribe() -> void:
	var bus := CombatEventBus.instance
	if not bus:
		await get_tree().process_frame
		_subscribe()
		return
	bus.subscribe(CombatEvent.Type.ON_DAMAGE, _on_damage)
	bus.subscribe(CombatEvent.Type.ON_HEAL, _on_heal)
	# 预留给未来实现
	bus.subscribe(CombatEvent.Type.ON_DODGE, _on_dodge)
	bus.subscribe(CombatEvent.Type.ON_CRIT, _on_crit)
	print("📊 [DamageNumberSpawner] 已订阅 CombatEventBus")


## ── 事件处理 ──

func _on_damage(ev: CombatEvent) -> void:
	if not ev.target or not is_instance_valid(ev.target):
		return
	var amount: int = ev.data.get("damage", 0)
	if amount <= 0:
		return
	var pos: Vector2 = ev.target.global_position if "global_position" in ev.target else Vector2.ZERO
	DamageNumber.spawn_damage(_world, amount, pos, false)


func _on_heal(ev: CombatEvent) -> void:
	if not ev.target or not is_instance_valid(ev.target):
		return
	var amount: int = ev.data.get("amount", 0)
	if amount <= 0:
		return
	var pos: Vector2 = ev.target.global_position if "global_position" in ev.target else Vector2.ZERO
	DamageNumber.spawn_heal(_world, amount, pos)


func _on_dodge(ev: CombatEvent) -> void:
	if not ev.target or not is_instance_valid(ev.target):
		return
	var pos: Vector2 = ev.target.global_position if "global_position" in ev.target else Vector2.ZERO
	DamageNumber.spawn_miss(_world, pos)


func _on_crit(ev: CombatEvent) -> void:
	if not ev.target or not is_instance_valid(ev.target):
		return
	var amount: int = ev.data.get("damage", 0)
	if amount <= 0:
		return
	var pos: Vector2 = ev.target.global_position if "global_position" in ev.target else Vector2.ZERO
	DamageNumber.spawn_damage(_world, amount, pos, true)
