class_name SupplyDeliveryService
extends RefCounted
var game: MVPGame
func _init(owner_game: MVPGame) -> void: game=owner_game
func mount(spec: DeliverySiteData) -> void:
	var node:=game._add_interaction(spec.title,spec.pos,Callable(),"person")
	node.callback=inspect.bind(node,spec)
func inspect(node: ExplorationInteractable, spec: DeliverySiteData) -> void:
	if not _valid(node,spec):return
	if game.progress.claims.has(spec.id):
		game.ui.show_panel(spec.title,spec.already_text,[{"title":"继续旅程","callback":game.ui.close_modal}])
		return
	game.player.field_work.inspect(node,spec.title,spec.methods,_reason.bind(node,spec),_complete.bind(node,spec),spec.description)
func _valid(node: Node2D, spec: DeliverySiteData) -> bool:
	return not game._switching and is_instance_valid(node) and node.get_parent()==game.region_root and spec in game.current_data.delivery_sites and not game.player.health_component.is_dead and node.position.distance_to(game.player.position)<=PlayerFieldWork.RANGE
func _reason(method: FieldWorkMethod,node: Node2D,spec: DeliverySiteData) -> String:
	if not _valid(node,spec) or method not in spec.methods:return "交付对象已不可用"
	if game.progress.claims.has(spec.id):return "这份委托已经交付"
	for id in spec.required_claims:
		if not game.progress.claims.has(id):return "还需先调查相关线索"
	return ""
func _complete(method: FieldWorkMethod,node: Node2D,spec: DeliverySiteData) -> bool:
	if not _reason(method,node,spec).is_empty():return false
	var supplies:=game.player.skill_manager.combinations.supplies
	supplies.begin_transaction()
	if not supplies.pay(method.material_costs):
		supplies.finish_transaction(false)
		return false
	if not game.progress.claim(spec.id,spec.title,"实际交付："+method.title+"。"+spec.completion_text,[],[]):
		supplies.finish_transaction(false)
		return false
	supplies.grant(spec.rewards)
	game.progress.choices[spec.id]=method.id
	game.builder.mount_available_stations()
	var notify:=supplies.finish_transaction(true)
	if notify.is_valid():notify.call()
	game._save_progress()
	game.ui.notify(spec.completion_text)
	return true
