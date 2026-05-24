class_name QuestData
extends Resource
## 任务配置 — 纯数据，只读
##
## 一个 .tres 文件 = 一个任务


@export var quest_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var stages: Array[QuestStageData] = []
