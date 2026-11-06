class_name CampaignSession
extends Node
## Composition/lifetime owner. Content adapters bind callbacks; domain objects receive capabilities.
var rules: RulesetDefinition
var region:=RegionContext.new()
var inventory:=InventoryService.new()
var facts:=GameplayFacts.new()
var relations:=RelationService.new()
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
var sync_extra: Callable
var death_handler: Callable
var hour_query: Callable
var state: Dictionary={}
var _pack_nodes: Dictionary={}
var _activity_families: Dictionary={}
func configure(content: ExplorationContentCatalog,profile: RulesetDefinition) -> void:
	catalog=content
	rules=profile
	inventory.rules=rules
	inventory.facts=facts
	relations.facts=facts
	relations.factions["guards|traveler"]="hostile"
	relations.factions["traveler|guards"]="hostile"
	for item in ItemCatalog.default_catalog().items: inventory.register_definition(item)
	for item: EquipmentData in catalog.equipment.values(): inventory.register_definition(item)
	facts.committed.connect(_on_fact)
func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	if data.has("inventory") and not inventory.valid_definitions(data.inventory): return false
	state=data.duplicate(true)
	if data.has("inventory"): inventory.restore(data.inventory)
	actor_records=data.get("actors",{}).duplicate(true)
	proficiency=data.get("proficiency",{}).duplicate(true)
	if data.has("relations"): relations.restore(data.relations)
	return true
func bind_actor(actor: CharacterBody2D,id: String,legacy_counts: Dictionary = {},legacy_loadout: Dictionary = {}, persistent := true) -> ActorContext:
	var context:=ActorContext.new()
	if not persistent: id="trial.%d.%s"%[region.generation,id]
	context.actor=actor; context.id=id; context.rules=rules; context.region=region
	context.items=inventory; context.facts=facts; context.relations=relations
	context.reward_eligible=bool(actor.get("rewards_enabled")) if "rewards_enabled" in actor else true
	context.persistent=persistent
	context.loot_eligible=rules.physical_inventory and persistent and id!="player"
	context.inspect_requested=inspect_actor
	context.hostile_requested=hostility_changed
	actor.actor_context=context
	actors[id]=weakref(actor)
	actor.get_node("HealthComponent").died.connect(mark_dead.bind(actor))
	var components:=preload("res://gameplay/foundation/actor_components.tscn").instantiate() as ActorComponents
	actor.add_child(components)
	components.configure(context)
	if "survival" in actor and actor.survival: context.actions.needs=actor.survival.needs
	if rules.physical_inventory:
		var existed:=inventory.containers.has(id+".gear")
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
		supplies.bind_inventory(inventory,id)
		if manager: manager.bind_inventory(inventory,id)
		if "inventory" in actor and actor.inventory: actor.inventory.bind_container(inventory,id+".pack")
	if rules.physical_inventory and actor_records.has(id): _restore_actor(actor,actor_records[id])
	if rules.tactical_combat and actor is Player:
		actor.state_machine.process_mode=Node.PROCESS_MODE_DISABLED
		context.actions.input_provider=actor.input_controller.poll_universal_actions
		context.actions.legacy_request=actor.input_controller.resolve_action
		context.actions.pack_request=drop_pack.bind(id)
	if rules.tactical_combat:
		context.actions.item_request=func(item_id: String): return begin_item(id,item_id)
	relations.memberships[id]="traveler" if id=="player" else "guards"
	return context
func _restore_actor(actor: CharacterBody2D,record: Dictionary) -> void:
	var health:=actor.get_node("HealthComponent") as HealthComponent
	health.hp=clampi(int(record.get("hp",health.hp)),1,health.max_hp)
	var mana:=actor.get_node_or_null("ManaComponent") as ManaComponent
	if mana: mana.mp=clampi(int(record.get("mp",mana.mp)),0,mana.max_mp)
	if record.get("position") is Array: actor.position=Vector2(float(record.position[0]),float(record.position[1]))
	if "story_truce" in actor: actor.story_truce=bool(record.get("truce",actor.story_truce))
	actor.actor_context.actions.stamina.restore(record.get("stamina",{}))
	actor.actor_context.actions.needs.restore(record.get("needs",{}))
func capture_actors() -> void:
	if not rules.physical_inventory: return
	for id in actors:
		var actor: Object=actors[id].get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.actor_context.persistent: continue
		var health:=actor.get_node("HealthComponent") as HealthComponent
		if health.is_dead: continue
		var mana:=actor.get_node_or_null("ManaComponent") as ManaComponent
		actor_records[id]={"hp":health.hp,"mp":mana.mp if mana else 0,"position":[actor.position.x,actor.position.y],"region":region.id,"stamina":actor.actor_context.actions.stamina.snapshot(),"needs":actor.actor_context.actions.needs.serialize(),"truce":bool(actor.story_truce) if "story_truce" in actor else false,"dead":false}
func snapshot() -> Dictionary:
	capture_actors()
	if sync_extra.is_valid(): sync_extra.call()
	return {"schema":1,"inventory":persistent_inventory(),"actors":actor_records.duplicate(true),"relations":relations.snapshot(),"proficiency":proficiency.duplicate(true)}
func leave_region() -> void:
	capture_actors()
	for id in actors.keys():
		if id=="player": continue
		var actor: Object=actors[id].get_ref()
		if is_instance_valid(actor): actor.actor_context.dispose()
		actors.erase(id)
	for id in relations.memberships.keys():
		if id.begins_with("trial."): relations.memberships.erase(id)
	for key in relations.personal.keys():
		if key.begins_with("trial.") or "|trial." in key: relations.personal.erase(key)
	for id in inventory.containers.keys():
		if id.begins_with("trial."):
			for item: ItemInstance in inventory.containers[id].items: inventory._unindex(item)
			inventory.containers.erase(id)
	_pack_nodes.clear()
	region.leave()
func mount_region(id: String,root: Node2D,layout: RunRoomLayout) -> void:
	region.id=id; region.root=root
	region.navigation=RegionNavigation.new()
	region.navigation.configure(layout)
	for container_id in inventory.containers:
		var container: Dictionary=inventory.containers[container_id]
		if container.kind=="pack" and not container.attached and container.region==id: _mount_pack(container_id)
func mark_dead(actor: CharacterBody2D) -> void:
	if not actor.actor_context.persistent: return
	var id: String=actor.actor_context.id
	if actor_records.get(id,{}).get("dead",false): return
	actor_records[id]={"dead":true,"hp":0,"region":region.id,"position":[actor.position.x,actor.position.y]}
	facts.publish("actor_died",id,{"region":region.id,"reward_eligible":actor.actor_context.reward_eligible})
	if actor.actor_context.loot_eligible and death_handler.is_valid(): death_handler.call(actor)
func drop_pack(actor_id: String) -> bool:
	if not rules.physical_inventory or not actors.has(actor_id): return false
	var actor: Node2D=actors[actor_id].get_ref()
	if not is_instance_valid(actor) or not region.available(): return false
	var id:=actor_id+".pack"
	if not inventory.containers[id].attached: return false
	inventory.containers[id].attached=false
	inventory.containers[id].region=region.id
	inventory.containers[id].position=[actor.position.x,actor.position.y]
	_mount_pack(id)
	facts.publish("pack_dropped",actor_id,{"container":id})
	if save_requested.is_valid(): save_requested.call()
	return true
func _mount_pack(id: String) -> void:
	if _pack_nodes.has(id): return
	var pack:=DroppedPack.new()
	pack.service=self; pack.container_id=id
	var pos: Array=inventory.containers[id].position
	pack.position=Vector2(pos[0],pos[1])
	region.root.add_child(pack)
	_pack_nodes[id]=pack
func recover_pack(actor_id: String,id: String) -> bool:
	if not actors.has(actor_id) or not inventory.containers.has(id) or not _pack_nodes.has(id): return false
	var actor: Node2D=actors[actor_id].get_ref()
	var pack:=_pack_nodes[id] as Node2D
	if not is_instance_valid(actor) or not is_instance_valid(pack) or actor.position.distance_to(pack.position)>=80 or inventory.containers[id].owner!=actor_id: return false
	inventory.containers[id].attached=true
	pack.queue_free(); _pack_nodes.erase(id)
	facts.publish("pack_recovered",actor_id,{"container":id})
	if save_requested.is_valid(): save_requested.call()
	return true
func begin_item(actor_id: String,id: String) -> bool:
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
func _on_fact(fact: Dictionary) -> void:
	if fact.source=="player":
		var actor:=actor_for_id("player")
		if actor and not actor.actor_context.reward_eligible: return
	if fact.source=="player" and fact.kind in ["melee_hit","hit_blocked","recipe_crafted"]:
		var school: String={"melee_hit":"melee","hit_blocked":"defense","recipe_crafted":"crafting"}[fact.kind]
		var family: String=str(fact.data.get("family",""))
		var receipt: String=str(fact.kind)+"."+family
		if not family.is_empty() and _activity_families.has(receipt): return
		if not family.is_empty():
			_activity_families[receipt]=true
			if _activity_families.size()>256: _activity_families.erase(_activity_families.keys()[0])
		proficiency[school]=float(proficiency.get(school,0))+1
		if actors.has("player"):
			var player: Object=actors["player"].get_ref()
			if is_instance_valid(player) and player.mastery_manager: player.mastery_manager.record_activity(fact.kind)
	if save_requested.is_valid(): save_requested.call()
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if data.get("schema")!=1 or not InventoryService.valid_snapshot(data.get("inventory",{})) or not data.get("actors") is Dictionary or not data.get("relations") is Dictionary or not data.get("proficiency") is Dictionary: return false
	for id in data.actors:
		var record=data.actors[id]
		if not id is String or not record is Dictionary or not record.get("hp") is int or record.hp<0 or record.hp>100000 or not record.get("dead") is bool or not record.get("region") is String: return false
		if not SurvivalNeeds.valid(record.get("needs",{})): return false
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
	if executor: executor.damage_applied.connect(_on_damage)
func _on_damage(source: Node2D,target: Node2D,amount: int) -> void:
	if amount<=0 or not is_instance_valid(source) or not is_instance_valid(target) or source==target: return
	if target.is_queued_for_deletion() or target.get_node("HealthComponent").is_dead: return
	if not "actor_context" in source or not "actor_context" in target or not source.actor_context or not target.actor_context: return
	var a: ActorContext=source.actor_context
	var b: ActorContext=target.actor_context
	relations.set_attitude(b.id,a.id,"hostile")
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
