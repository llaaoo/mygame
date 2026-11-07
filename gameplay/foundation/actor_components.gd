class_name ActorComponents
extends Node2D
@onready var stamina: StaminaComponent=$Stamina
@onready var stability: StabilityComponent=$Stability
@onready var actions: ActorActionController=$Actions
func configure(context: ActorContext) -> void:
	actions.context=context
	actions.stamina=stamina
	actions.stability=stability
	context.actions=actions
	context.item_actions=$Items; $Items.context=context
	context.spray=$Spray; $Spray.context=context
