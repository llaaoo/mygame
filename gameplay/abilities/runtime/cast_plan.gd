class_name CastPlan
extends RefCounted

var requires_magic := true
var delivery_reach := 0.0
var delivery_angle := 0.0
var selection: Dictionary={}
var binding_revision := -1

var requires_live_target := false
var live_target: Node2D
## Shared by preview, accepted preparation and commit. Resources are read-only definitions.
var components: Array[CastComponent] = []
var skill: SkillData
var rule_id := ""
var field: FireSigil
var cost := 0
var material_costs: Dictionary = {}
var instance_costs: Array[Dictionary]=[]
var stamina_cost := 0.0
var material_id := ""
var cooldown_keys: Dictionary = {}
var cooldown_key := ""
var cooldown := 0.0
var action_cooldown := 0.0
var preparation := 0.0
var field_bonus := 0.0
var signature: Array = []
var empower := false
var charge_power := 1.0
var status_conditions: Array[CastStatusRequirement] = []
var retained_boons: Array[String] = []
var consumed_boons: Array[String] = []
var partial_boons: Array[String] = []
var infusions: Array[String] = []
var explanation: Array[CastExplanationStep] = []
var effect_label := ""
var modifier_id := ""
var operation_reason := ""
var reason := ""
var ready := false
var action: SkillData
var source := ""
var actor: Node2D
var scope: Node
var position := Vector2.ZERO
var direction := Vector2.ZERO
var target_position := Vector2.ZERO
var has_target_position := false
var health := 0
var execution_id := 0
var remaining := 0.0
var soul_remnant: SoulRemnant
var soul_revision := -1
var placement_radius := 96.0
var placement_duration := 15.0

func field_budget() -> Dictionary:
	var timed: bool=is_instance_valid(actor) and "actor_context" in actor and actor.actor_context and actor.actor_context.rules.timed_fields
	var duration: float=(clampf(skill.field_duration+placement_duration-15,5,40) if not skill.operation_id.is_empty() else placement_duration)+field_bonus
	var use_cost:=0.0
	if timed:
		duration=(120.0 if skill.field_type=="arcane" else 180.0)+maxf(0,placement_duration-15.0)+field_bonus
		use_cost=(40.0 if skill.field_type=="arcane" else 30.0)*clampf(1+ActorProgression.modifier(actor,"field.use_cost"),.5,1.5)
	return {"duration":duration*clampf(1+ActorProgression.modifier(actor,"field.duration"),.5,2),"use_seconds":use_cost}

func is_empty() -> bool:
	return action == null

func cost_label() -> String:
	return "%d MP"%cost if requires_magic else "1剂喷剂" if not instance_costs.is_empty() else "实物消耗"
