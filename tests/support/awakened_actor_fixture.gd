extends RefCounted
## Opt-in for tests of established spell mechanics, never ordinary new-game setup.
## A newly awakened test caster receives the explicitly controlled historical
## 60-MP budget; already-restored actors retain their actual current MP.
## No knowledge, items, stats or world/trial claims are granted here.
static func awaken(actor: Node2D,mana_budget := 60) -> bool:
	if not is_instance_valid(actor): return false
	var context:=actor.get("actor_context") as ActorContext
	if not context: return false
	if not context.magic: return false
	if context.magic.awakened: return true
	var result: OperationResult=context.magic.awaken(actor,"test.fixture",0,0.0,60)
	if not result.accepted: return false
	var mana:=actor.get_node("ManaComponent") as ManaComponent
	mana.mp=mana_budget
	mana.notify_changed()
	return context.magic.awakened
