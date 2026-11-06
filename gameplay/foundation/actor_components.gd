class_name ActorComponents
extends Node
@onready var stamina: StaminaComponent=$Stamina
@onready var stability: StabilityComponent=$Stability
@onready var actions: ActorActionController=$Actions
func configure(context: ActorContext) -> void:
	actions.context=context
	actions.stamina=stamina
	actions.stability=stability
	context.actions=actions
