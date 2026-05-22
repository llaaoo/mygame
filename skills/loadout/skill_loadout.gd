class_name SkillLoadout
extends Resource
## 技能装备映射表 — 槽位 → skill_id
## 本质是"装备哪几个技能"的纯数据，不持有 SkillData 引用
## 运行时由 SkillManager 通过 SkillPool 解析 skill_id → SkillData

## ── 左右手 ──
@export var left_hand: String = ""
@export var right_hand: String = ""

## ── 快捷键槽位（4个） ──
@export var slots: Array[String] = []


## 快捷构造：全部指定
static func create(left: String, right: String, slot_ids: Array[String] = []) -> SkillLoadout:
	var lo := SkillLoadout.new()
	lo.left_hand = left
	lo.right_hand = right
	lo.slots = slot_ids
	return lo


## 是否为空（未装备任何技能）
func is_empty() -> bool:
	if not left_hand.is_empty():
		return false
	if not right_hand.is_empty():
		return false
	for s in slots:
		if not s.is_empty():
			return false
	return true
