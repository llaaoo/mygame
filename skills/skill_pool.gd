class_name SkillPool
extends Resource
## 技能池 — 存储所有已学会的技能
## 每个玩家/NPC 拥有一个 SkillPool 实例 (.tres)

@export var skills: Array[SkillData] = []


## 添加技能到池中
func add_skill(skill: SkillData) -> void:
	if not skill or has_skill(skill.skill_id):
		return
	skills.append(skill)


## 移除技能
func remove_skill(skill_id: String) -> void:
	for i in range(skills.size()):
		if skills[i] and skills[i].skill_id == skill_id:
			skills.remove_at(i)
			return


## 通过 id 查找
func get_skill(skill_id: String) -> SkillData:
	for s in skills:
		if s and s.skill_id == skill_id:
			return s
	return null


## 是否已学会
func has_skill(skill_id: String) -> bool:
	return get_skill(skill_id) != null
