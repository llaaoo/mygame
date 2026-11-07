class_name CastPlan
extends RefCounted

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

func is_empty() -> bool:
	return action == null
