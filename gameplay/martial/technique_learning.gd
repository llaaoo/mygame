class_name TechniqueLearning
extends RefCounted
## Courses add world requirements; ability prerequisites also apply to books.
static func reason(offer: LearningOffer,context: ActorContext) -> String:
	if not offer or not offer.valid() or not context: return "课程不可用"
	var knowledge:=context.martial.learn_reason(offer.technique.id)
	if not knowledge.is_empty(): return knowledge
	for condition in offer.requirements:
		if not condition.satisfied(context.learning_query): return condition.hint
	if not context.items.can_pay(context.id,offer.costs): return "课程所需物资不足"
	return ""
static func purchase(offer: LearningOffer,context: ActorContext,teacher: String) -> OperationResult:
	if not context or teacher==context.id or not context.items.has_container(teacher+".pack"): return OperationResult.reject("教师不可用")
	var refused:=reason(offer,context)
	if not refused.is_empty(): return OperationResult.reject(refused)
	var previous:=context.martial.snapshot()
	context.items.begin_batch()
	if not context.martial.learn(offer.technique.id): context.items.end_batch(); return OperationResult.reject("学习条件已变化")
	var payment:=context.items.exchange(context.id,teacher,offer.costs,{})
	if not payment.accepted: context.martial.restore(previous)
	context.items.end_batch()
	if not payment.accepted: return payment
	context.facts.publish("technique_learned",context.id,{"id":offer.technique.id,"source":teacher,"course":offer.id})
	return OperationResult.success()
