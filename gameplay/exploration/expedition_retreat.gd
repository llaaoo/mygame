class_name ExpeditionRetreat
extends RefCounted
var game: MVPGame
func _init(owner_game: MVPGame) -> void: game = owner_game
func begin() -> void:
	game.ui.close_modal()
	if not reason().is_empty():
		game.ui.notify(reason())
		return
	var option := FieldWorkMethod.new()
	option.id = "retreat"
	option.title = "撤回营地"
	option.duration = 3
	var methods: Array[FieldWorkMethod] = [option]
	game.player.field_work.inspect(game.player, "现场撤离", methods, func(_m): return reason(), _complete, "站定3秒，受伤、移动、施法或攻击会打断；E或Esc取消。不收材料，生命法力保持。")
	game.player.field_work.start_selected()
func reason() -> String:
	if game._switching or not game.ready_for_play or game.region_id == "camp" or game.player.health_component.is_dead: return "当前无需或无法撤离"
	return ""
func _complete(_method: FieldWorkMethod) -> bool:
	if not reason().is_empty(): return false
	game.request_travel("camp")
	return true
