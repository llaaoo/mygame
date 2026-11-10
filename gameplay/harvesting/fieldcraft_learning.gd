class_name FieldcraftLearning
extends RefCounted
static func reason(skill: FieldcraftSkill,context: ActorContext) -> String:
	if not skill or not context or not context.fieldcraft: return "技艺课程不可用"
	var refusal:=context.fieldcraft.reason(context.id,skill.id)
	if not refusal.is_empty(): return refusal
	return "" if context.items.can_pay(context.id,skill.costs) else "课程所需物资不足"
static func purchase(skill: FieldcraftSkill,context: ActorContext,teacher: String) -> OperationResult:
	if not context or teacher==context.id or not context.items.has_container(teacher+".pack"): return OperationResult.reject("教师不可用")
	var refusal:=reason(skill,context)
	if not refusal.is_empty(): return OperationResult.reject(refusal)
	var previous:=context.fieldcraft.serialize_save_data()
	context.items.begin_batch()
	if not context.fieldcraft.learn(context.id,skill.id): context.items.end_batch();return OperationResult.reject("学习条件已变化")
	var payment:=context.items.exchange(context.id,teacher,skill.costs,{})
	if not payment.accepted: context.fieldcraft.deserialize_save_data(previous)
	context.items.end_batch()
	if payment.accepted: context.facts.publish("fieldcraft_learned",context.id,{"skill":skill.id,"teacher":teacher})
	return payment
