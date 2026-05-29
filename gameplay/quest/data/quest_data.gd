class_name QuestData
extends Resource

@export var quest_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var stages: Array[QuestStageData] = []
@export var reward_experience: int = 0
