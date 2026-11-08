class_name ProvisionDefinition
extends Resource
## Immutable food/drink definition. BuffManager owns the effect's live clock.
@export var id := ""
@export var nutrition := 0.0
@export var hydration := 0.0
@export var fatigue := 0.0
@export var seconds := 1.0
@export_multiline var description := ""
@export var effect: Buff
func valid() -> bool:
	if id.is_empty() or not is_finite(seconds) or seconds<=0: return false
	for value in [nutrition,hydration,fatigue]:
		if not is_finite(value): return false
	if not effect: return true
	if not is_finite(effect.duration) or effect.duration<=0 or effect.duration>86400 or effect.provision_group not in ["","meal","water","tea"]: return false
	for value in [effect.health_recovery_bonus,effect.mana_recovery_bonus,effect.stamina_recovery_bonus]:
		if not is_finite(value) or value<0: return false
	if not effect.provision_group.is_empty() and (effect.max_stacks!=1 or effect.stack_behavior==Buff.StackBehavior.INDEPENDENT): return false
	return effect.provision_group.is_empty() or not effect.exclusive_group.is_empty()
