class_name SkillPool
extends Resource
## 技能池 — ID 索引表，描述"有哪些"
## 技能数据的注册中心，支持 O(1) ID 查找
## 每个玩家/NPC 拥有一个 SkillPool 实例 (.tres)

@export var skills: Array[SkillData] = []

## ── 内部索引（O(1) 查找） ──
var map: Dictionary = {}


## 构建 ID 索引表（加载技能后必须调用）
func build() -> void:
	map.clear()
	for s in skills:
		if s:
			var key := s.get_id()
			if not key.is_empty():
				map[key] = s


## 通过 id 查找（O(1)）
func get_skill(skill_id: String) -> SkillData:
	return map.get(skill_id, null)


## 添加技能到池中（自动更新索引）
func add_skill(skill: SkillData) -> void:
	if not skill:
		return
	var key := skill.get_id()
	if key.is_empty():
		return
	if map.has(key):
		return
	skills.append(skill)
	map[key] = skill


## 移除技能（自动更新索引）
func remove_skill(skill_id: String) -> void:
	if not map.has(skill_id):
		return
	map.erase(skill_id)
	for i in range(skills.size()):
		if skills[i] and skills[i].get_id() == skill_id:
			skills.remove_at(i)
			return


## 是否已学会
func has_skill(skill_id: String) -> bool:
	return map.has(skill_id)


## 获取所有已注册 id
func get_all_ids() -> Array[String]:
	return map.keys()


## 池大小
func size() -> int:
	return map.size()
