class_name GrayriverResidents
extends RefCounted
## Chapter composition: actors and UI adapters; shared social rules know no chapter.
var game: GrayriverGame
var _adapters: Dictionary={}
func _init(owner_game: GrayriverGame) -> void: game=owner_game
func adapter_for(id: String) -> TownServices:
	if _adapters.has(id): return _adapters[id]
	var profile:=game.session.conversations.catalog.profile(id)
	if not profile: return null
	if id in [game.town_services.market.actor_id,game.town_services.training.actor_id]: _adapters[id]=game.town_services
	else: _adapters[id]=TownServices.new(game,profile.market,profile.training,false)
	return _adapters[id]
func mount() -> void:
	game.session.conversations.record=game.progress_service.record_service_result
	for profile in game.session.conversations.catalog.profiles:
		if profile.region_id!=game.region_id: continue
		if profile.market: adapter_for(profile.actor_id).ensure_stock()
		if is_instance_valid(game.session.actor_for_id(profile.actor_id)): continue
		var configure_actor:=func(actor: CharacterBody2D):
			var npc:=actor as ServiceNPC
			npc.character_definition=profile.character
			npc.threat_response=profile.threat_response
			npc.schedule=profile.daily_schedule()
			npc.locations={"work":profile.work_location(),"rest":profile.rest_location()}
			npc.hour_query=game.session.hour_query; npc.service_request=open.bind(profile.actor_id); npc.notify=game.session.notify; npc.lookup_actor=game.session.actor_for_id
			npc.set_meta("frontier_claim",profile.actor_id)
		var npc:=game.session.mount_actor(load("res://gameplay/foundation/service_npc.tscn"),profile.actor_id,profile.work_location(),configure_actor) as ServiceNPC
		if npc:
			game.session.relations.memberships[profile.actor_id]="civilian"
			var saved: Dictionary=game.session.actor_records.get(profile.actor_id,{})
			if saved.is_empty() or float(saved.get("updated_at",0))<game.session.inventory.clock_seconds: npc.resume_schedule()
func open(id: String) -> void:
	var result:=game.session.conversations.begin(id)
	if not result.accepted: game.ui.notify(result.reason); return
	var screen:=NpcConversationScreen.new()
	screen.setup(game.session.conversations,result,service.bind(id),game.ui.close_modal,game.ui.notify)
	game.ui.show_view("交谈",screen)
	game.ui.modal.set_meta("npc_conversation",id)
func service(kind: String,id: String) -> void:
	if not game.session.conversations.reason(id,true).is_empty(): return
	var profile:=game.session.conversations.catalog.profile(id)
	if not profile or not profile.topics.any(func(topic: NpcTopic): return topic.kind==NpcTopic.Kind.SERVICE and topic.service==kind): return
	var adapter:=adapter_for(id)
	match kind:
		"trade": adapter.show()
		"production": adapter.show_production()
		"training": adapter.show_training()
		"quests": game._show_quests()
		"progression": game.presenter._show_progression()
