class_name ActorCharacterData
extends Resource
## Shared body/loadout definitions; input, AI, rewards and persistence belong to controllers.
@export var animation_profile: ActorAnimationProfile
@export var temperament: CombatTemperament
@export var body_moveset: WeaponMoveset
@export var can_guard := true
@export var harvest_profile: HarvestProfile
@export var id: String
@export var title: String
@export var level := 1
@export var strength := 10
@export var intelligence := 10
@export var agility := 10
@export var endurance := 10
@export var base_move_speed := 300.0
@export var melee_multiplier := 1.0
@export var health_regen := 0.0
@export var mana_regen := 2.0
@export var magic_aptitude := true
@export var starts_awakened := true
@export var skills: Array[SkillData] = []
@export var techniques: Array[String]=[]
@export var combinations: PackedStringArray = []
@export var loadout: SkillLoadout
@export var materials: Dictionary = {}
@export var equipment: Array[EquipmentData] = []

func validation_errors(available_rules: Variant = null) -> Array[String]:
	var errors: Array[String] = []
	if animation_profile:
		errors.append_array(animation_profile.validation_errors())
		if not animation_profile.equipment_free or animation_profile not in ActorAnimationCatalog.default_catalog().profiles: errors.append("Unregistered/live profile with baked equipment")
	if temperament and not temperament.valid(): errors.append("Invalid combat temperament")
	if body_moveset and not body_moveset.valid(): errors.append("Invalid natural attack moveset")
	if harvest_profile: errors.append_array(harvest_profile.validation_errors())
	if starts_awakened and not magic_aptitude: errors.append("Awakened character lacks magic aptitude")
	if level<1 or level>100: errors.append("Invalid character level")
	if id.is_empty() or title.is_empty(): errors.append("Missing character id/title")
	for key in Buff.PRIMARY_STATS:
		if get(key) < 1 or get(key) > 100: errors.append("Invalid primary: "+key)
	for key in ["base_move_speed","melee_multiplier"]:
		if not is_finite(get(key)) or get(key) <= 0: errors.append("Invalid body parameter: "+key)
	for key in ["health_regen","mana_regen"]:
		if not is_finite(get(key)) or get(key) < 0: errors.append("Invalid recovery: "+key)
	var known := {}
	var martial:=MartialArts.new()
	for technique in techniques:
		if not martial.learn(technique): errors.append("Invalid/duplicate initial technique: "+technique)
	for skill in skills:
		if not skill or skill.combination_only or known.has(skill.get_id()): errors.append("Invalid/duplicate base action")
		else: known[skill.get_id()] = true
	if loadout:
		if loadout.slots.size()>SkillManager.MAX_SLOTS: errors.append("Too many action slots")
		for action in [loadout.left_hand,loadout.right_hand]+Array(loadout.slots):
			if not str(action).is_empty() and not known.has(action): errors.append("Unknown equipped action: "+str(action))
	# Cross-resource references are validated by the catalog owner, not a fixed chapter.
	if available_rules is Dictionary:
		for id_rule in combinations:
			if not available_rules.has(id_rule): errors.append("Unknown combination: "+id_rule)
			elif not known.has(available_rules[id_rule].trigger_action_id): errors.append("Unknown combination trigger: "+id_rule)
	for item in materials:
		if not CastingSupplies.known_item(str(item)) or not materials[item] is int or materials[item]<0: errors.append("Invalid carried material: "+str(item))
	var slots := {}
	for item in equipment:
		if not item or slots.has(item.slot_type): errors.append("Invalid/duplicate equipment slot")
		else: slots[item.slot_type] = true
	return errors
