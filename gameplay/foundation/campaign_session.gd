class_name CampaignSession
extends Node
## Composition/lifetime owner. Content adapters bind callbacks; domain objects receive capabilities.
var rules: RulesetDefinition
var condition_query: ConditionQuery
var region:=RegionContext.new()
var inventory:=InventoryService.new()
var production:=ProductionService.new()
var _production_time := 0.0
var facts:=GameplayFacts.new()
var relations:=RelationService.new()
var conversations:=NpcConversationService.new()
var actor_records: Dictionary={}
var actors: Dictionary={}
var proficiency: Dictionary={}
var catalog: ExplorationContentCatalog
var notify: Callable
var save_requested: Callable
var inspect_actor: Callable
var hostility_changed: Callable
var equipment_page: Callable
var supply_page: Callable
var ground_page: Callable
var equip_item: Callable
var sync_extra: Callable
var death_handler: Callable
var hour_query: Callable
var state: Dictionary={}
# Compatibility projection for old callers; QuickslotLoadout is authoritative.
var belt: Array[Dictionary]:
	get:
		var result: Array[Dictionary]=[]
		var actor:=actor_for_id("player")
		for source in QuickslotLoadout.ITEM_SOURCES:
			var entry: Dictionary=actor.get_node("SkillManager").shortcuts.binding(source) if actor else {}
			var id:=str(entry.get("item_id",""))
			var definition:=ItemCatalog.default_catalog().definition(id)
			result.append({"id":id,"method":"throw" if definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.THROWABLE else "use"})
		return result
var _pack_nodes: Dictionary={}
var _ground_nodes: Dictionary={}
var _activity_families: Dictionary={}
var _pending_effect_time: Dictionary={}
var restoring_effects := false
var save_sections:=SaveSections.new()
var fieldcraft:=FieldcraftKnowledge.new()
var encounters:=EncounterCoordinator.new()
var law:=LawService.new()
var expedition:=ExpeditionState.new()
func configure(content: ExplorationContentCatalog,profile: RulesetDefinition) -> void:
	catalog=content
	rules=profile
	inventory.rules=rules
	inventory.facts=facts
	inventory.perk_query=perk_value
	law.configure(inventory,relations,facts);law.witness_query=property_witnesses
	relations.facts=facts
	conversations.configure(self,NpcCatalog.default_catalog())
	production.producer_reason=producer_reason
	relations.factions["guards|traveler"]="hostile"
	relations.factions["traveler|guards"]="hostile"
	save_sections.register("production",SaveAdapter.new(production.snapshot,production.restore,ProductionService.valid_snapshot))
	save_sections.register("relations",SaveAdapter.new(relations.snapshot,relations.restore,_valid_relation_state))
	save_sections.register("conversations",SaveAdapter.new(conversations.snapshot,conversations.restore,NpcConversationService.valid_state))
	save_sections.register("fieldcraft",fieldcraft)
	save_sections.register("law",law)
	save_sections.register("expedition",expedition)
	for item in ItemCatalog.default_catalog().items: inventory.register_definition(item)
	for item: EquipmentData in catalog.equipment.values(): inventory.register_definition(item)
	facts.committed.connect(_on_fact)
func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	if snapshot_read_status(data)!=SaveSections.Status.VALID: return false
	if data.has("inventory") and not inventory.valid_definitions(data.inventory): return false
	_pending_effect_time.clear()
	state=data.duplicate(true)
	inventory.clock_seconds=float(data.get("clock_seconds",0))
	if data.has("inventory"): inventory.restore(data.inventory)
	actor_records=data.get("actors",{}).duplicate(true)
	proficiency=data.get("proficiency",{}).duplicate(true)
	return save_sections.restore(data)
func snapshot_read_status(data: Variant) -> int:
	return int(save_sections.prepare(data).status)
static func _valid_relation_state(data: Variant) -> bool:
	return data is Dictionary and RelationService.valid_dispositions(data.get("dispositions",{})) and RelationService.valid_affiliations(data.get("affiliations",{}))
func _exit_tree() -> void:
	save_sections.clear()
func bind_actor(actor: CharacterBody2D,id: String,legacy_counts: Dictionary = {},legacy_loadout: Dictionary = {}, persistent := true) -> ActorContext:
	var context:=ActorContext.new()
	if not persistent: id="trial.%d.%s"%[region.generation,id]
	context.actor=actor; context.id=id; context.rules=rules; context.region=region
	context.items=inventory; context.facts=facts; context.relations=relations
	context.fieldcraft=fieldcraft
	var body:=actor.get("character_definition") as ActorCharacterData
	if body: context.body_moveset=body.body_moveset;context.guard_allowed=body.can_guard
	context.encounter_group=str(actor.get_meta("encounter_group",""))
	var tactics:=actor.get_meta("encounter_tactics") as EncounterTactics if actor.has_meta("encounter_tactics") else null
	if tactics and actor is Enemy:context.awareness=encounters.register(context,tactics)
	context.learning_query=ConditionQuery.new()
	context.learning_query.actor_id=id; context.learning_query.items=inventory; context.learning_query.relations=relations
	context.learning_query.actor_query=actor_for_id
	context.learning_query.law=law
	context.learning_query.fieldcraft=fieldcraft;context.learning_query.knowledge_query=knows
	if condition_query: context.learning_query.progress=condition_query.progress; context.learning_query.regions=condition_query.regions
	context.reward_eligible=bool(actor.get("rewards_enabled")) if "rewards_enabled" in actor else true
	context.persistent=persistent
	context.loot_eligible=rules.physical_inventory and persistent and id!="player"
	if actor is Enemy and actor.attack_preparation:
		context.preparation_query=actor.attack_preparation.is_preparing
		context.cancel_preparation=actor.attack_preparation.cancel
	context.nearby_allies=nearby_allies.bind(id)
	context.inspect_requested=inspect_actor
	context.hostile_requested=hostility_changed
	actor.actor_context=context
	actors[id]=weakref(actor)
	(actor.get_node("BuffManager") as BuffManager).source_resolver=actor_for_id
	actor.get_node("HealthComponent").died.connect(mark_dead.bind(actor))
	actor.get_node("HealthComponent").died.connect((actor.get_node("BuffManager") as BuffManager).buildup.clear)
	var components:=preload("res://gameplay/foundation/actor_components.tscn").instantiate() as ActorComponents
	actor.add_child(components)
	components.configure(context)
	if "survival" in actor and actor.survival: context.actions.needs=actor.survival.needs
	if rules.physical_inventory:
		var existed:=inventory.has_container(id + ".gear")
		context.restored_inventory=existed
		inventory.ensure_actor(id)
		var manager:=actor.get_node_or_null("EquipmentManager") as EquipmentManager
		var supplies: CastingSupplies=actor.get_node("SkillManager").combinations.supplies
		if not existed:
			inventory.begin_batch()
			for key in supplies.amounts: inventory.receive(id,key,int(supplies.amounts[key]),true)
			if not legacy_counts.is_empty():
				for key in legacy_counts: inventory.receive(id,key,int(legacy_counts[key]),true)
				for slot in legacy_loadout:
					var uid:=inventory.find_owned(id,legacy_loadout[slot])
					if not uid.is_empty(): inventory.equip(id,uid)
			elif manager:
				for item in manager.get_all_equipped():
					inventory.register_definition(item)
					inventory.receive(id,item.id,1,true)
					inventory.equip(id,inventory.find_owned(id,item.id))
			if "inventory" in actor and actor.inventory:
				for i in range(actor.inventory.capacity):
					var entry: Dictionary=actor.inventory.get_slot(i)
					if not entry.item or catalog.equipment.has(entry.item.id): continue
					inventory.register_definition(entry.item)
					inventory.receive(id,entry.item.id,entry.quantity,true)
			inventory.end_batch()
			if context.loot_eligible and body and body.harvest_profile:
				body.harvest_profile.initialize(inventory,id)
		supplies.bind_inventory(inventory,id)
		supplies.fieldcraft=fieldcraft
		if manager: manager.bind_inventory(inventory,id)
		if "inventory" in actor and actor.inventory: actor.inventory.bind_container(inventory,id+".pack")
	if rules.physical_inventory and actor_records.has(id): _restore_actor(actor,actor_records[id])
	else:
		context.actions.needs.bind_effects(actor.get_node("BuffManager"),true)
		if actor is Enemy and actor.character_definition:
			for technique in actor.character_definition.techniques: context.martial.learn(technique)
	if rules.material_operations: actor.get_node("SkillManager").enable_material_operations()
	if rules.tactical_combat and actor is Player:
		actor.state_machine.process_mode=Node.PROCESS_MODE_DISABLED
		if notify.is_valid(): context.actions.action_refused.connect(notify)
		context.actions.input_provider=actor.input_controller.poll_universal_actions
		context.item_actions.aim_query=actor.get_mouse_direction
		context.spray.aim_query=actor.get_mouse_direction
		context.spray.held_query=actor.input_controller.source_held
		context.actions.legacy_request=actor.input_controller.execute_action
		context.actions.pack_request=drop_pack.bind(id)
	if rules.tactical_combat:
		context.actions.item_request=func(request: Action): return execute_item_request(id,request)
	relations.memberships[id]="traveler" if id=="player" else "guards"
	if actor is Player:
		restore_shortcuts(actor)
		if not actor.skill_manager.binding_changed.is_connected(actor.input_controller.shortcut_changed): actor.skill_manager.binding_changed.connect(actor.input_controller.shortcut_changed)
	return context
func _restore_actor(actor: CharacterBody2D,record: Dictionary) -> void:
	if record.get("position") is Array: actor.position=Vector2(float(record.position[0]),float(record.position[1]))
	if "story_truce" in actor: actor.story_truce=bool(record.get("truce",actor.story_truce))
	actor.actor_context.actions.stamina.restore(record.get("stamina",{}))
	actor.actor_context.actions.needs.restore(record.get("needs",{}))
	var away:=maxf(0,inventory.clock_seconds-float(record.get("updated_at",inventory.clock_seconds)))
	var buffs:=actor.get_node("BuffManager") as BuffManager
	if record.has("effects"):
		buffs.restore_campaign_state(record.effects,actor_for_id)
	else:
		# Older campaigns stored food/potions only; import their actual remainders.
		buffs.restore_campaign_state({"schema":1,"entries":[],"immunity":{}})
		buffs.restore_provisions(record.get("provisions",[]))
	buffs.buildup.restore(record.get("buildup",{}))
	actor.actor_context.actions.needs.bind_effects(buffs,not record.has("provision_schema"))
	actor.get_node("SkillManager").restore_campaign_cooldowns(record.get("cooldowns",{}),away)
	if away>0: _pending_effect_time[actor.actor_context.id]=away
	if away>0: actor.actor_context.actions.needs.tick(away,actor.get_node("StatsComponent").effective_stat("endurance"),rules.is_base(record.region,actor.position))
	actor.actor_context.martial.restore(record.get("martial",{}))
	var health:=actor.get_node("HealthComponent") as HealthComponent
	health.hp=clampi(int(record.get("hp",health.hp)),1,health.max_hp)
	var mana:=actor.get_node_or_null("ManaComponent") as ManaComponent
	if mana: mana.mp=clampi(int(record.get("mp",mana.mp)),0,mana.max_mp)

func restore_actor_state(actor: CharacterBody2D) -> void:
	var id: String=actor.actor_context.id
	if actor_records.has(id): _restore_actor(actor,actor_records[id])

func finish_effect_restoration() -> void:
	restoring_effects=true
	var pending:=_pending_effect_time.duplicate(); _pending_effect_time.clear()
	for id in pending:
		var actor:=actor_for_id(id)
		if not is_instance_valid(actor) or actor.get_node("HealthComponent").is_dead: continue
		if actor is Enemy: actor.player=actor_for_id("player")
		(actor.get_node("BuffManager") as BuffManager).advance_campaign_time(float(pending[id]))
	restoring_effects=false
func capture_actors() -> void:
	if not rules.physical_inventory: return
	for id in actors:
		var actor: Object=actors[id].get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.actor_context.persistent: continue
		var health:=actor.get_node("HealthComponent") as HealthComponent
		if health.is_dead: continue
		actor_records[id]=_actor_record(actor)
func _actor_record(actor: CharacterBody2D) -> Dictionary:
	var health:=actor.get_node("HealthComponent") as HealthComponent
	var mana:=actor.get_node_or_null("ManaComponent") as ManaComponent
	return {"provision_schema":1,"effects":(actor.get_node("BuffManager") as BuffManager).campaign_state(),"cooldowns":actor.get_node("SkillManager").campaign_cooldowns(),"buildup":(actor.get_node("BuffManager") as BuffManager).buildup.snapshot(),"updated_at":inventory.clock_seconds,"hp":health.hp,"mp":mana.mp if mana else 0,"position":[actor.position.x,actor.position.y],"region":region.id,"stamina":actor.actor_context.actions.stamina.snapshot(),"needs":actor.actor_context.actions.needs.serialize(),"martial":actor.actor_context.martial.snapshot(),"provisions":(actor.get_node("BuffManager") as BuffManager).provision_state(),"truce":bool(actor.story_truce) if "story_truce" in actor else false,"dead":health.is_dead}
func snapshot() -> Dictionary:
	capture_actors()
	if sync_extra.is_valid(): sync_extra.call()
	var result:=state.duplicate(true)
	result.merge({"schema":1,"clock_seconds":inventory.clock_seconds,"shortcut_schema":1,"inventory":persistent_inventory(),"actors":actor_records.duplicate(true),"proficiency":proficiency.duplicate(true)},true)
	result.erase("belt")
	return save_sections.capture(result)
func leave_region() -> void:
	encounters.clear();law.leave_region()
	conversations.invalidate()
	capture_actors()
	for id in actors.keys():
		if id=="player": continue
		var actor: Object=actors[id].get_ref()
		if is_instance_valid(actor):
			actor.actor_context.dispose()
		if id.begins_with("trial."):
			inventory.discard_actor_containers(id)
		actors.erase(id)
	for id in relations.memberships.keys():
		if id.begins_with("trial."): relations.memberships.erase(id)
	for key in relations.personal.keys():
		if key.begins_with("trial.") or "|trial." in key: relations.personal.erase(key)
	_pack_nodes.clear()
	_ground_nodes.clear()
	region.leave()
func mount_region(id: String,root: Node2D,layout: RunRoomLayout) -> void:
	region.id=id; region.root=root
	region.navigation=RegionNavigation.new()
	region.navigation.configure(layout)
	refresh_ground()
	for container_id in inventory.dropped_pack_ids(id):
		_mount_pack(container_id)
func refresh_ground() -> void:
	if not region.available(): return
	var current:=inventory.ground_ids(region.id)
	for id in _ground_nodes.keys():
		if id not in current:
			if is_instance_valid(_ground_nodes[id]): _ground_nodes[id].queue_free()
			_ground_nodes.erase(id)
	for id in current:
		if _ground_nodes.has(id) and is_instance_valid(_ground_nodes[id]): continue
		var node:=GroundItems.new()
		node.service=self; node.container_id=id; node.position=inventory.ground_position(id)
		region.root.add_child(node); _ground_nodes[id]=node
func inspect_ground(actor: Node2D,id: String) -> void:
	if ground_available(actor,id) and ground_page.is_valid(): ground_page.call(id)
func ground_available(actor: Node2D,id: String) -> bool:
	return is_instance_valid(actor) and region.available() and id in inventory.ground_ids(region.id) and actor.global_position.distance_to(inventory.ground_position(id))<80
func mark_dead(actor: CharacterBody2D) -> void:
	if not actor.actor_context.persistent: return
	var id: String=actor.actor_context.id
	if actor_records.get(id,{}).get("dead",false): return
	actor_records[id]=_actor_record(actor)
	actor_records[id].dead=true; actor_records[id].hp=0
	production.cancel_actor(id)
	facts.publish("actor_died",id,{"region":region.id,"reward_eligible":actor.actor_context.reward_eligible})
	if actor.actor_context.loot_eligible and death_handler.is_valid(): death_handler.call(actor)
func drop_pack(actor_id: String) -> bool:
	if not rules.physical_inventory or not actors.has(actor_id): return false
	var actor: Node2D=actors[actor_id].get_ref()
	if not is_instance_valid(actor) or not region.available(): return false
	var id:=actor_id+".pack"
	if not inventory.drop_pack(actor_id, region.id, actor.position):
		return false
	_mount_pack(id)
	facts.publish("pack_dropped",actor_id,{"container":id})
	if save_requested.is_valid(): save_requested.call()
	return true
func _mount_pack(id: String) -> void:
	if _pack_nodes.has(id): return
	var pack:=DroppedPack.new()
	pack.service=self; pack.container_id=id
	pack.position = inventory.dropped_pack_position(id)
	region.root.add_child(pack)
	_pack_nodes[id]=pack
func recover_pack(actor_id: String,id: String) -> bool:
	if not actors.has(actor_id) or not _pack_nodes.has(id): return false
	var actor: Node2D=actors[actor_id].get_ref()
	var pack:=_pack_nodes[id] as Node2D
	if not is_instance_valid(actor) or not is_instance_valid(pack) or actor.position.distance_to(pack.position)>=80: return false
	if not inventory.recover_pack(actor_id, id):
		return false
	pack.queue_free(); _pack_nodes.erase(id)
	facts.publish("pack_recovered",actor_id,{"container":id})
	if save_requested.is_valid(): save_requested.call()
	return true
func begin_item(actor_id: String,id: String) -> bool:
	var owner:=actor_for_id(actor_id)
	var definition:=inventory.definitions.get(id) as ItemData
	if owner and definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY: return prepare_sprayer(actor_id,id)
	if owner and definition and definition.use_profile: return owner.actor_context.item_actions.begin(id)
	if not actors.has(actor_id) or not SurvivalCatalog.FOODS.has(id): return false
	var actor: CharacterBody2D=actors[actor_id].get_ref()
	if not is_instance_valid(actor) or not actor.actor_context.items.can_pay(actor_id,{id:1},true): return false
	if actor is Player and actor.survival:
		actor.survival.begin_eating(id)
		return actor.field_work.is_busy()
	var use:=ActorItemUse.new()
	use.context=actor.actor_context; use.item_id=id
	actor.add_child(use)
	return true
func prepare_sprayer(actor_id: String,id: String,uid := "") -> bool:
	var owner:=actor_for_id(actor_id)
	if not owner: return false
	var manager:=owner.get_node("SkillManager") as SkillManager
	var action:=manager.pool.get_skill("disperse")
	if not action or not manager.knows_action(action): return false
	for payload in SpellOperationCatalog.default_catalog().operation("disperse").payloads:
		if payload.material_id==id: return manager.combinations.supplies.select_payload(action,payload.id,manager,uid)
	return false
func _on_fact(fact: Dictionary) -> void:
	if fact.source=="player":
		var actor:=actor_for_id("player")
		if actor and not actor.actor_context.reward_eligible: return
	if fact.kind=="corpse_harvested" and not fieldcraft.record_harvest(str(fact.source),str(fact.data.get("raw_uid","")),str(fact.data.get("skill",""))): return
	if fact.source=="player" and fact.kind in ["melee_hit","hit_blocked","recipe_crafted","resource_harvested","corpse_harvested","field_work","discovery","equipment_upgraded","equipment_dismantled"]:
		var school: String={"melee_hit":"melee","hit_blocked":"defense","recipe_crafted":"crafting","resource_harvested":"survival","corpse_harvested":"survival","field_work":"crafting","discovery":"survival","equipment_upgraded":"crafting","equipment_dismantled":"crafting"}[fact.kind]
		var family: String=str(fact.data.get("family",""))
		var receipt: String=str(fact.kind)+"."+family
		if not family.is_empty() and _activity_families.has(receipt): return
		if not family.is_empty():
			_activity_families[receipt]=true
			if _activity_families.size()>256: _activity_families.erase(_activity_families.keys()[0])
		proficiency[school]=float(proficiency.get(school,0))+1
		if actors.has("player"):
			var player: Object=actors["player"].get_ref()
			if is_instance_valid(player) and player.mastery_manager: player.mastery_manager.record_activity(fact.kind,4.0 if fact.kind in ["recipe_crafted","resource_harvested","corpse_harvested","discovery"] else 1.0)
	if save_requested.is_valid(): save_requested.call()
func knows(id: String,key: String,kind: int) -> bool:
	var actor:=actor_for_id(id)
	var query:=condition_query
	if id=="player" and query and query.progress:
		if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.ACTION] and query.progress.actions.has(key): return true
		if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.COMBINATION] and query.progress.spell_rules.has(key): return true
	if actor:
		var manager:=actor.get_node("SkillManager") as SkillManager
		if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.ACTION]:
			var action:=manager.pool.get_skill(key)
			if action and manager.knows_action(manager.canonical_action(action)):return true
		if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.COMBINATION] and manager.combinations.learned_rules.has(key):return true
	if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.FIELDCRAFT] and fieldcraft.knows(id,key): return true
	if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.MARTIAL]:
		if actor and actor.actor_context.martial.learned.has(key): return true
		if not actor and actor_records.get(id,{}).get("martial",{}).get("learned",{}).has(key): return true
	if kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.PERK] and actor and "mastery_manager" in actor and actor.mastery_manager: return actor.mastery_manager.has_perk(key)
	return false
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if not NpcConversationService.valid_state(data.get("conversations",{})): return false
	if not data.get("relations",{}) is Dictionary: return false
	if not RelationService.valid_dispositions(data.get("relations",{}).get("dispositions",{})): return false
	if not RelationService.valid_affiliations(data.get("relations",{}).get("affiliations",{})):return false
	var law_state: Variant=data.get("law",{})
	if not LawService.valid_state(law_state):return false
	if typeof(data.get("clock_seconds",0)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.get("clock_seconds",0))) or data.get("clock_seconds",0)<0 or data.get("clock_seconds",0)>1000000000: return false
	if not ProductionService.valid_snapshot(data.get("production",{})): return false
	if data.has("shortcut_schema") and (not data.shortcut_schema is int or data.shortcut_schema!=1): return false
	if data.has("belt"):
		if not data.belt is Array or data.belt.size()!=4: return false
		for binding in data.belt:
			if not binding is Dictionary or not binding.get("id") is String or binding.get("method","") not in ["use","throw"]: return false
			if not valid_belt_item(binding.id,binding.method): return false
	if data.get("schema")!=1 or not InventoryService.valid_snapshot(data.get("inventory",{})) or not data.get("actors") is Dictionary or not data.get("relations") is Dictionary or not data.get("proficiency") is Dictionary: return false
	if not LawService.valid_inventory_links(data.inventory,law_state.get("cases",{})):return false
	for id in data.actors:
		var record=data.actors[id]
		if not id is String or not record is Dictionary or not record.get("hp") is int or record.hp<0 or record.hp>100000 or not record.get("dead") is bool or not record.get("region") is String: return false
		if not SurvivalNeeds.valid(record.get("needs",{})) or not MartialArts.valid(record.get("martial",{})) or not BuffManager.valid_provisions(record.get("provisions",[])) or not StatusBuildup.valid(record.get("buildup",{})): return false
		if record.has("provision_schema") and (not record.provision_schema is int or record.provision_schema!=1): return false
		if record.has("effects") and not BuffManager.valid_campaign_state(record.effects): return false
		if not SkillManager.valid_campaign_cooldowns(record.get("cooldowns",{})): return false
		if typeof(record.get("updated_at",0)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.get("updated_at",0))) or record.get("updated_at",0)<0 or record.get("updated_at",0)>data.get("clock_seconds",0): return false
		var stamina=record.get("stamina",{})
		if not stamina is Dictionary: return false
		for key in stamina:
			if key not in ["current","maximum","delay"] or typeof(stamina[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(stamina[key])) or float(stamina[key])<0 or float(stamina[key])>100000: return false
		var point=record.get("position",[])
		if not point is Array or point.size()!=2: return false
		for n in point:
			if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)): return false
	for category in ["personal","factions","memberships"]:
		if not data.relations.get(category,{}) is Dictionary: return false
		for key in data.relations.get(category,{}):
			var value=data.relations[category][key]
			if not key is String or not value is String: return false
			if category!="memberships" and value not in RelationService.ATTITUDES: return false
	for value in data.proficiency.values():
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0: return false
	return true

func observe_combat(executor: CombatExecutor) -> void:
	if executor:
		executor.damage_applied.connect(_on_damage)
		executor.harmful_contact_applied.connect(_on_hostile_contact)
func _on_damage(source: Node2D,target: Node2D,amount: int) -> void:
	if amount>0:
		var context:=target.get("actor_context") as ActorContext if "actor_context" in target else null
		if context:
			context.item_actions.cancel()
			context.spray.stop()
		if context and context.awareness:
			var body:=target as Enemy
			context.awareness.provoke(source.position if is_instance_valid(source) and body.can_see(source) else target.position)
		_on_hostile_contact(source,target)
func _on_hostile_contact(source: Node2D,target: Node2D) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target) or source==target: return
	if target.is_queued_for_deletion() or target.get_node("HealthComponent").is_dead: return
	if not "actor_context" in source or not "actor_context" in target or not source.actor_context or not target.actor_context: return
	var a: ActorContext=source.actor_context
	var b: ActorContext=target.actor_context
	if a.id==b.id: return
	var was_hostile:=relations.attitude(b.id,a.id)=="hostile"
	relations.set_attitude(b.id,a.id,"hostile")
	if not was_hostile and b.actor is ServiceNPC: relations.adjust_disposition(b.id,a.id,-30)
	if "story_truce" in target: target.story_truce=false
	if b.hostile_requested.is_valid(): b.hostile_requested.call(target)
func has_hostiles_near(actor_id: String,point: Vector2,radius := 500.0) -> bool:
	for id in actors:
		if id==actor_id: continue
		var actor: Object=actors[id].get_ref()
		if not is_instance_valid(actor) or actor.get_node("HealthComponent").is_dead: continue
		if "story_truce" in actor and actor.story_truce: continue
		if relations.attitude(id,actor_id)=="hostile" and actor.position.distance_to(point)<radius: return true
	return false
func set_player_rewards(eligible: bool) -> void:
	if actors.has("player"):
		var actor: Object=actors["player"].get_ref()
		if is_instance_valid(actor): actor.actor_context.reward_eligible=eligible

func persistent_inventory() -> Dictionary:
	var saved:=inventory.snapshot()
	for id in saved.containers.keys():
		if id.begins_with("trial."): saved.containers.erase(id)
	return saved
func actor_for_id(id: String) -> Node2D:
	return actors[id].get_ref() as Node2D if actors.has(id) else null
func mount_actor(scene: PackedScene,id: String,position: Vector2,configure_actor: Callable = Callable()) -> CharacterBody2D:
	if actor_records.get(id,{}).get("dead",false) or not region.available(): return null
	var actor:=scene.instantiate() as CharacterBody2D
	if not actor: return null
	actor.position=position
	if configure_actor.is_valid(): configure_actor.call(actor)
	region.root.add_child(actor)
	bind_actor(actor,id)
	return actor

func _process(delta: float) -> void:
	if rules and rules.physical_inventory and region.available():
		inventory.clock_seconds+=delta
		_production_time+=delta
		if _production_time>=1:
			_production_time=0
			production.advance()
func restore_shortcuts(actor: Player) -> void:
	if int(state.get("shortcut_schema",0))==1: return
	var previous: Array=state.get("belt",[{"id":"ration"},{"id":"clean_water"},{"id":"tea"},{"id":"broth"}])
	for i in range(4):
		var id:=str(previous[i].id)
		var definition:=inventory.definitions.get(id) as ItemData
		var uid:=inventory.ready_uid("player",id) if definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else ""
		actor.skill_manager.shortcuts.bind_item("item_%d"%i,id,uid)
	state["shortcut_schema"]=1

func bind_belt(index: int,id: String,method := "use") -> bool:
	var actor:=actor_for_id("player")
	if not actor or index<0 or index>=4 or not valid_belt_item(id,method): return false
	var definition:=inventory.definitions.get(id) as ItemData
	var uid:=inventory.ready_uid("player",id) if definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else ""
	return actor.get_node("SkillManager").shortcuts.bind_item("item_%d"%index,id,uid)
static func valid_belt_item(id: String,method: String) -> bool:
	var definition:=ItemCatalog.default_catalog().definition(id)
	if not definition: return false
	if method=="throw": return definition.use_profile!=null and definition.use_profile.kind==ItemUseDefinition.Kind.THROWABLE
	return method=="use" and (SurvivalCatalog.FOODS.has(id) or definition.use_profile!=null)

func execute_item_request(actor_id: String,request: Action) -> bool:
	var actor:=actor_for_id(actor_id)
	if not actor: return false
	if not request.params.has("binding"): return begin_item(actor_id,request.skill_id)
	var manager:=actor.get_node("SkillManager") as SkillManager
	var binding:=manager.shortcuts.binding(request.skill_source)
	if binding!=request.params.binding or binding.get("kind","")!="item": return false
	var controller: ItemActionController=actor.actor_context.item_actions
	if request.params.get("release",false):
		return controller.input_source==request.skill_source and controller.confirm()
	var id:=str(binding.item_id)
	var uid:=str(binding.get("uid",""))
	var definition:=inventory.definitions.get(id) as ItemData
	if not definition: return false
	if not uid.is_empty():
		var instance:=inventory.item(uid)
		if not instance or instance.definition_id!=id or inventory.locate(uid) not in inventory.actor_containers(actor_id)+[actor_id+".gear"]: return false
	if definition is EquipmentData: return equip_item.is_valid() and equip_item.call(id,uid)
	if definition.use_profile:
		if definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY:
			var operation:=SpellOperationCatalog.default_catalog().operation("disperse")
			for payload in operation.payloads:
				if payload.material_id==id: return actor.actor_context.spray.start(operation.action,request.skill_source,request.direction,{"payload":payload.id,"uid":uid,"modifier":""})
			return false
		return controller.begin(uid if not uid.is_empty() else id,definition.use_profile.kind==ItemUseDefinition.Kind.THROWABLE,request.direction,request.skill_source)
	return begin_item(actor_id,id)

func advance_rest_time(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0: return
	inventory.clock_seconds+=seconds
	production.advance()
	for id in actors:
		var actor:=actor_for_id(id)
		if not is_instance_valid(actor) or id=="player": continue
		actor.actor_context.actions.needs.tick(seconds,actor.get_node("StatsComponent").effective_stat("endurance"),rules.is_base(region.id,actor.position))
		actor.actor_context.actions.rest_elapsed(seconds)
		if actor is ServiceNPC: actor.resume_schedule()
	facts.publish("time_advanced","player",{"seconds":seconds})

func elapsed_seconds() -> float: return inventory.clock_seconds

func nearby_allies(radius: float,id: String) -> Array[Node2D]:
	var result: Array[Node2D]=[]
	var actor:=actor_for_id(id)
	if not is_instance_valid(actor) or not region.available(): return result
	for other_id in actors:
		if other_id==id or relations.memberships.get(id,"")=="" or relations.memberships.get(other_id,"")!=relations.memberships.get(id,""): continue
		var other:=actor_for_id(other_id)
		if is_instance_valid(other) and other.global_position.distance_to(actor.global_position)<=radius and not other.get_node("HealthComponent").is_dead: result.append(other)
	return result

func perk_value(actor_id: String,key: String) -> float:
	return ActorProgression.modifier(actor_for_id(actor_id),key)
func producer_reason(id: String) -> String:
	if actor_records.get(id,{}).get("dead",false): return "producer_dead"
	var actor:=actor_for_id(id)
	return "producer_dead" if is_instance_valid(actor) and actor.get_node("HealthComponent").is_dead else ""

func property_witnesses(actor_id: String,point: Vector2) -> Array[String]:
	var result: Array[String]=[];var offender:=actor_for_id(actor_id)
	if not offender:return result
	for id in actors:
		var npc:=actor_for_id(id) as ServiceNPC
		if not npc or npc.health_component.is_dead or npc.position.distance_to(point)>260:continue
		var sight:=PhysicsRayQueryParameters2D.create(npc.global_position,offender.global_position,1,[npc.get_rid()])
		if not npc.get_world_2d().direct_space_state.intersect_ray(sight).is_empty():continue
		var ray:=PhysicsRayQueryParameters2D.create(npc.global_position,point,1,[npc.get_rid()])
		if npc.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():result.append(id)
	return result
