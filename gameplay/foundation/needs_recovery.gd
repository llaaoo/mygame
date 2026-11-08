class_name NeedsRecovery
extends RefCounted
static func apply(actor: Node2D,needs: SurvivalNeeds) -> void:
	var recovery:=needs.recovery()
	var health:=actor.get_node_or_null("HealthComponent") as HealthComponent
	var mana:=actor.get_node_or_null("ManaComponent") as ManaComponent
	if health:
		health.regen_multiplier=recovery.health_multiplier
		health.regen_bonus=recovery.health_bonus
		health.regen_bonus_sources={"food":recovery.health_bonus}
	if mana:
		mana.regen_multiplier=recovery.mana_multiplier
		mana.regen_bonus=recovery.mana_bonus
		mana.regen_bonus_sources=recovery.mana_sources.duplicate()
