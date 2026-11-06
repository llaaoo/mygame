class_name ActorCombatModel
extends RefCounted
## Single attribute/scaling/loadout implementation for player and authored NPCs.
static func bases(stats: StatsComponent, move_base: float, melee_multiplier: float) -> Dictionary:
	stats._recalculate_all()
	return {"max_hp":50+stats.max_hp_bonus,"max_mana":stats.max_mana,"attack_damage":roundi((10+stats.physical_damage)*melee_multiplier),"move_speed":move_base+stats.move_speed_bonus}

static func rebuild(actor: Node2D) -> void:
	var stats:=actor.get_node("StatsComponent") as StatsComponent
	var buffs:=actor.get_node("BuffManager") as BuffManager
	buffs.set_base_attributes(bases(stats,actor.base_move_speed,actor.melee_damage_multiplier))
	var health:=actor.get_node("HealthComponent") as HealthComponent
	var mana:=actor.get_node("ManaComponent") as ManaComponent
	health.hp=clampi(health.hp,0 if health.is_dead else 1,health.max_hp)
	mana.mp=clampi(mana.mp,0,mana.max_mp)

static func initialize_body(actor: Node2D, definition: ActorCharacterData) -> void:
	var stats := actor.get_node("StatsComponent") as StatsComponent
	stats.level=definition.level
	for key in Buff.PRIMARY_STATS: stats.set(key,definition.get(key))
	actor.base_move_speed = definition.base_move_speed
	actor.melee_damage_multiplier = definition.melee_multiplier
	(actor.get_node("HealthComponent") as HealthComponent).regen_rate = definition.health_regen
	(actor.get_node("ManaComponent") as ManaComponent).mp_regen_rate = definition.mana_regen

static func setup_scaling(manager: SkillManager) -> void:
	for modifier in manager.executor.modifiers:
		if modifier is StatScalingModifier: return
	manager.executor.add_modifier(StatScalingModifier.new())

static func configure_actions(actor: Node2D, definition: ActorCharacterData) -> void:
	var manager := actor.get_node("SkillManager") as SkillManager
	manager.pool = SkillPool.new()
	manager.restrict_actions = true
	manager.known_actions.clear()
	manager.unequip_hand("left")
	manager.unequip_hand("right")
	for i in range(SkillManager.MAX_SLOTS): manager.unequip_slot(i)
	for skill in definition.skills:
		manager.pool.add_skill(skill)
		manager.known_actions[skill.get_id()] = true
	var controller := manager.combinations
	controller.allow_layered_fields=true
	controller.learned_rules.clear()
	for rule in controller.rules:
		if rule.id in definition.combinations:
			controller.learned_rules[rule.id] = true
			manager.pool.add_skill(rule.result_skill)
	controller.supplies.restore({"amounts":definition.materials.duplicate(true)})
	manager.apply_loadout(definition.loadout)
	setup_scaling(manager)

static func configure_equipment(actor: Node2D, definition: ActorCharacterData) -> void:
	var manager := actor.get_node("EquipmentManager") as EquipmentManager
	for item in definition.equipment: manager.equip(item.duplicate(true))

static func melee_contact(actor: Node2D, target: Node2D, damage: int, base_tags: Array[String]) -> void:
	var tags := base_tags.duplicate()
	var buffs := actor.get_node_or_null("BuffManager") as BuffManager
	var imbued_tags: Array[String] = buffs.get_attack_tags() if buffs else []
	var skill: SkillData = null
	if not imbued_tags.is_empty():
		for tag in imbued_tags:
			if tag not in tags: tags.append(tag)
		skill = SkillData.new()
		skill.id="imbued_melee"
		skill.display_name="元素近战"
		skill.tags=tags
	var surface := SurfaceManager.instance
	if surface and not imbued_tags.is_empty():
		var cell := SurfaceManager.cell_at(target.global_position)
		if surface.get_surface(cell).get("state","dry")!="dry": surface.apply_tags(cell,tags,"元素近战")
	CombatExecutor.report_hit(actor,target,damage,target.global_position,skill,tags)

static func incoming_damage(actor: Node2D, amount: int) -> int:
	if amount <= 0: return 0
	var equipment := actor.get_node_or_null("EquipmentManager") as EquipmentManager
	var reduction := clampf(equipment.get_modifier_value("damage_reduction"),0.0,0.75) if equipment else 0.0
	return maxi(1,roundi(amount*(1.0-reduction)))
