class_name SharedActor
extends CharacterBody2D
## Minimal self-contained actor scene. Player, AI and services compose the same components.
@export var character_definition: ActorCharacterData
var actor_context: ActorContext
var enemy_name: String:
	get: return character_definition.title if character_definition else name
var base_move_speed := 180.0
var melee_damage_multiplier := 1.0
var move_speed := 180.0
var attack_damage := 20
var rewards_enabled := false
var facing_direction := Vector2.DOWN
@onready var health_component: HealthComponent=$HealthComponent
@onready var mana_component: ManaComponent=$ManaComponent
@onready var stats_component: StatsComponent=$StatsComponent
@onready var skill_manager: SkillManager=$SkillManager
func _ready() -> void:
	health_component.setup($CollisionShape2D)
	health_component.died.connect(queue_free)
	if character_definition:
		ActorCombatModel.initialize_body(self,character_definition)
		ActorCombatModel.configure_actions(self,character_definition)
		ActorCombatModel.configure_equipment(self,character_definition)
	ActorCombatModel.rebuild(self)
	stats_component.stat_changed.connect(func(_key,_value): ActorCombatModel.rebuild(self))
	ActorEquipmentVisual.install(self)
func take_damage(amount: int) -> void:
	health_component.take_damage(ActorCombatModel.incoming_damage(self,amount))
func get_player_direction() -> Vector2: return facing_direction
