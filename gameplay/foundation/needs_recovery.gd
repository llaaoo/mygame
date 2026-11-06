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
		mana.regen_bonus_sources={"food":.5 if needs.meal=="broth" and needs.meal_remaining>0 else 0.0,"water":.5 if needs.water_remaining>0 else 0.0,"tea":1.0 if needs.tea_remaining>0 else 0.0}
