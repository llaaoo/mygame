class_name AwakeningSiteService
extends RefCounted
## Trial claims record evidence; ActorMagicState alone grants casting and charges costs.
var game: CampaignGame
func _init(owner_game: CampaignGame) -> void: game=owner_game

func mount(spec: AwakeningSiteData) -> void:
	var node:=game._add_interaction(spec.title,spec.pos,Callable(),"mechanism")
	node.set_meta("awakening_site",spec)
	node.callback=inspect.bind(node,spec)

func inspect(node: ExplorationInteractable,spec: AwakeningSiteData) -> void:
	if not _valid(node,spec): return
	var original:=spec.accept_method if game.progress.claims.has(spec.trial_claim) else spec.trial_method
	if not original: return
	var method:=original.duplicate(true) as FieldWorkMethod
	var accepting:=original==spec.accept_method
	if accepting: method.title="明确接受永久代价：生命上限 -%d / 体力上限 -%s"%[spec.permanent_hp_cost,str(spec.permanent_stamina_cost)]
	var methods: Array[FieldWorkMethod]=[method]
	var signature:=spec.fingerprint()
	var guide:=spec.description+"\n\n试感不授予法力，也不扣除永久属性。试感后可以离开，主线不要求接受觉醒；日后仍可返回。"
	if accepting: guide+="\n明确接受后，永久降低生命上限 %d、体力上限 %s，并建立 %d 基础法力容量；当前法力不会补满，完成后会逐渐恢复。本版没有重修或撤销途径；开始后仍可在完成前取消，只有成功完成才结算。"%[spec.permanent_hp_cost,str(spec.permanent_stamina_cost),spec.mana_base]
	game.player.field_work.inspect(node,spec.title,methods,_reason.bind(node,spec,signature),_complete.bind(node,spec,signature),guide)

func _valid(node: Node2D,spec: AwakeningSiteData) -> bool:
	return is_instance_valid(game) and is_instance_valid(game.player) and game.ready_for_play and not game._switching and spec!=null and is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion() and node.get_parent()==game.region_root and game.current_data!=null and spec in game.current_data.awakening_sites and node.get_meta("awakening_site",null)==spec and not game.player.health_component.is_dead

func reason(method: FieldWorkMethod,node: Node2D,spec: AwakeningSiteData) -> String:
	if not spec: return "试感台定义已不可用。"
	return _reason(method,node,spec,spec.fingerprint())

func _reason(method: FieldWorkMethod,node: Node2D,spec: AwakeningSiteData,signature: Array) -> String:
	if not _valid(node,spec) or signature!=spec.fingerprint() or not spec.validation_errors().is_empty(): return "试感台已不可用，请重新调查。"
	if not _method_matches(method,spec): return "未知的试感方式。"
	if node.global_position.distance_to(game.player.global_position)>PlayerFieldWork.RANGE: return "请靠近试感台后再开始。"
	var ray:=PhysicsRayQueryParameters2D.create(game.player.global_position,node.global_position,1)
	if not game.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return "视线被遮挡，无法隔墙试感。"
	if game.session.has_hostiles_near("player",game.player.position): return "附近仍有敌人，先确保安全再试感。"
	var missing:=game.progress.condition_query.claims_reason(spec.required_claims)
	if not missing.is_empty(): return missing
	if game.progress.claims.has(spec.id): return "这处觉醒已经完成，不会再次扣除永久代价。"
	if not game.player.actor_context or not game.player.actor_context.magic: return "当前角色无法进行觉醒。"
	var domain_reason: String=game.player.actor_context.magic.awakening_reason(game.player,spec.permanent_hp_cost,spec.permanent_stamina_cost,spec.mana_base)
	if not domain_reason.is_empty(): return domain_reason
	if method.id==spec.trial_method.id and game.progress.claims.has(spec.trial_claim): return "试感已经完成；是否接受永久代价仍由你决定。"
	if method.id==spec.accept_method.id and not game.progress.claims.has(spec.trial_claim): return "先完成现场试感，再决定是否接受永久代价。"
	return ""

func _method_matches(method: FieldWorkMethod,spec: AwakeningSiteData) -> bool:
	if not method: return false
	var original: FieldWorkMethod=spec.trial_method if method.id==spec.trial_method.id else spec.accept_method if method.id==spec.accept_method.id else null
	if not original: return false
	var actual:=method.fingerprint();var expected:=original.fingerprint()
	# Only the explicit acceptance copy's presentation title can differ.
	actual[1]=expected[1]
	return actual==expected and method.animation_id==original.animation_id

func _complete(method: FieldWorkMethod,node: Node2D,spec: AwakeningSiteData,signature: Array) -> bool:
	if not _reason(method,node,spec,signature).is_empty(): return false
	if method.id==spec.trial_method.id:
		if not game.progress.claim(spec.trial_claim,"试感完成："+spec.title,"已亲自在试感台站定，感受到尚未开启的法力。没有扣除永久属性，也尚未获得施法资格；可离开继续主线，日后返回决定。",[],[]): return false
		game._save_progress()
		game.ui.notify("试感完成：尚未觉醒、未扣永久属性。可离开继续旅程；再次调查才会显示接受永久代价的选项。")
		return true
	# Pure evidence write precedes domain notifications/save observers. A rejected
	# domain commit has no side effects, so restore this unannounced receipt exactly.
	var journal_size:=game.progress.journal.size()
	if not game.progress.claim(spec.id,"觉醒："+spec.title,"亲自完成试感后，明确接受永久代价：生命上限 -%d、体力上限 -%s，建立 %d 基础法力。本版不可重修。"%[spec.permanent_hp_cost,str(spec.permanent_stamina_cost),spec.mana_base],[],[]): return false
	var accepted: OperationResult=game.player.actor_context.magic.awaken(game.player,spec.id,spec.permanent_hp_cost,spec.permanent_stamina_cost,spec.mana_base)
	if not accepted.accepted:
		game.progress.claims.erase(spec.id)
		game.progress.journal.resize(journal_size)
		return false
	game._save_progress()
	game.ui.notify("觉醒完成：永久代价已结算，基础法力容量已开启；当前法力会逐渐恢复，重复调查不会再次扣除。")
	return true
