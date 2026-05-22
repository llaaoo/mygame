class_name BuffManager
extends Node
## Buff 管理器 — 挂载到 Player 节点，管理所有激活的 Buff
##
## 装备、技能、消耗品等任何系统都通过 BuffManager 施加/移除效果

## 当前激活的所有 Buff
var _active_buffs: Array[Buff] = []

## 定时器引用
var _tick_timer: float = 0.0


func _process(delta: float) -> void:
	if _active_buffs.is_empty():
		return
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_timer -= 1.0
		_tick_buffs()


func _tick_buffs() -> void:
	var entity = get_parent()
	for buff in _active_buffs:
		if buff.tick_interval > 0 and buff.tick_heal > 0:
			if entity.has_method("heal"):
				entity.heal(buff.tick_heal)


## 施加 Buff（装备、技能等调用）
func apply_buff(buff: Buff) -> void:
	if not buff:
		return
	buff.apply_to(get_parent())
	_active_buffs.append(buff)
	print("🟢 BuffManager: 施加 %s" % buff.display_name)


## 移除 Buff
func remove_buff(buff: Buff) -> void:
	if not buff or not buff in _active_buffs:
		return
	buff.remove_from(get_parent())
	_active_buffs.erase(buff)
	print("🔴 BuffManager: 移除 %s" % buff.display_name)


## 检查是否拥有指定名称的 Buff（供 StatusCondition 等系统查询）
func has_buff(buff_name: String) -> bool:
	for buff in _active_buffs:
		if buff.display_name == buff_name:
			return true
	return false


## 移除所有 Buff（死亡/重置时）
func clear_all() -> void:
	for buff in _active_buffs:
		buff.remove_from(get_parent())
	_active_buffs.clear()
