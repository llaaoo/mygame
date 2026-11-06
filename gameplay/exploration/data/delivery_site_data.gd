class_name DeliverySiteData
extends Resource
## A physical handover of inventory, paid only after interruptible work succeeds.
@export var id: String
@export var title: String
@export var pos := Vector2.ZERO
@export_multiline var description: String
@export var methods: Array[FieldWorkMethod] = []
@export var rewards: Dictionary = {}
@export var required_claims: PackedStringArray = []
@export_multiline var completion_text := "口粮已经送到。镇边苦叶药圃开放，艾妲的委托板可记录这次成果。"
@export_multiline var already_text := "这批口粮已经送到。你亲手交付的补给帮了忙，镇边的苦叶药圃现在可以采集；重复交谈不会再发放奖励。"
