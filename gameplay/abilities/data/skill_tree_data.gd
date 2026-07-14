class_name SkillTreeData
extends Resource

@export var tree_id: String = ""
@export var display_name: String = "未命名学派"
@export_multiline var description: String = ""
@export var school: SkillMastery.School = SkillMastery.School.DESTRUCTION
@export var accent_color: Color = Color.WHITE
@export var skill_ids: Array[String] = []
@export var perks: Array[Resource] = []
