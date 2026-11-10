class_name ActorProgression
extends RefCounted
## Common, read-only progression projection. Actor-owned mastery remains authoritative.
static func modifier(actor: Node,key: String) -> float:
 var mastery:=actor.get_node_or_null("MasteryManager") as SkillMasteryManager if actor else null
 return mastery.get_modifier_value(key) if mastery else 0.0
static func values(actor: Node,overrides: Dictionary={}) -> Dictionary:
 var stats:=actor.get_node_or_null("StatsComponent") as StatsComponent
 var result:=stats.derived_values(overrides) if stats else {"max_stamina":100.0,"stamina_regeneration":10.0,"carry_bonus":0.0,"dodge_multiplier":1.0,"work_multiplier":1.0}
 result.max_stamina=maxf(1,result.max_stamina+modifier(actor,"stamina.maximum"))
 result.stamina_regeneration=maxf(0,result.stamina_regeneration+modifier(actor,"stamina.regeneration"))
 result.carry_bonus+=modifier(actor,"carry.maximum")
 result.dodge_multiplier=clampf(result.dodge_multiplier*(1+modifier(actor,"stamina.dodge")),.4,1.5)
 result.work_multiplier=clampf(result.work_multiplier*(1+modifier(actor,"work.duration")),.4,1.5)
 return result
static func refresh_stamina(actor: Node) -> void:
 if not actor or not "actor_context" in actor or not actor.actor_context or not actor.actor_context.actions: return
 var actions: ActorActionController=actor.actor_context.actions
 var data:=stamina_values(actor)
 actions.stamina.configure_values(data.maximum,data.regeneration)
static func stamina_values(actor: Node,overrides: Dictionary={}) -> Dictionary:
 var actions: ActorActionController=actor.actor_context.actions
 var data:=values(actor,overrides)
 var needs:=actions.needs
 var factor: float=(.35 if needs.hydration<=20 else 1.0)*(.5 if needs.fatigue>=85 else .75 if needs.fatigue>=60 else 1.0)
 var bonus:=float(needs.recovery().stamina_bonus)+actions.equipment_value("stamina_recovery")
 if not needs.meal.is_empty() and needs.meal_remaining>0: bonus+=modifier(actor,"survival.fed_regen")
 return {"maximum":data.max_stamina,"base_regeneration":data.stamina_regeneration,"regeneration":maxf(0,data.stamina_regeneration*factor+bonus),"needs_multiplier":factor,"bonus":bonus,"delay":actions.stamina.delay,"guarding":actions.guarding,"guard_fraction":modifier(actor,"stamina.guarding_regen")}
