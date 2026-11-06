class_name SurvivalService
extends Node
## Scene adapter for provisions, live work and the single persistent needs model.
var game: CampaignGame
var needs := SurvivalNeeds.new()
var _loaded_vitals: Dictionary = {}
var _awaiting_vitals := false
var _notice_tier := ""
var _ui_time := 0.0
var _save_time := 0.0
var supplies: CastingSupplies:
	get: return game.player.skill_manager.combinations.supplies

func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)
	game.player.skill_manager.cast_committed.connect(_on_cast)
	game.player.combat_component.melee_started.connect(func(): exert(.12))

func restore(data: Dictionary) -> void:
	needs.restore(data)
	_loaded_vitals = data.duplicate(true)
	_awaiting_vitals = true
	apply_recovery()

func serialize() -> Dictionary:
	var data := needs.serialize()
	data["hp"] = game.player.health_component.hp
	data["mp"] = game.player.mana_component.mp
	return data

func tick(delta: float) -> void:
	if not game.ready_for_play or game._switching or game.get_tree().paused or game.player.health_component.is_dead: return
	needs.tick(delta, game.player.stats_component.effective_stat("endurance"), game.is_at_base())
	apply_recovery()
	_ui_time += delta
	_save_time += delta
	if _ui_time >= .25:
		_ui_time = 0
		game.ui.set_survival_status(status_line() + ("\n" + timers_line() if not timers_line().is_empty() else ""))
		var tier := str(needs.nutrition <= 20) + str(needs.hydration <= 20) + str(needs.fatigue >= 60) + str(needs.fatigue >= 85)
		if tier != _notice_tier:
			if not _notice_tier.is_empty(): game.ui.notify(status_line() + "\nN查看补给、恢复变化和休整。")
			_notice_tier = tier
	if _save_time >= 30:
		_save_time = 0
		game._queue_save()

func apply_recovery() -> void:
	NeedsRecovery.apply(game.player,needs)

func exert(amount: float) -> void:
	needs.exert(amount, game.player.stats_component.effective_stat("endurance"))
	apply_recovery()

func _on_cast(plan: CastPlan) -> void:
	exert(plan.cost * .06)

func camp_arrival(hp: int, mp: int, was_dead: bool) -> void:
	if _awaiting_vitals:
		hp = int(_loaded_vitals.get("hp", game.player.health_component.max_hp))
		mp = int(_loaded_vitals.get("mp", game.player.mana_component.max_mp))
		was_dead = hp <= 0
		_loaded_vitals.clear()
		_awaiting_vitals = false
	if was_dead:
		needs.nutrition = maxf(needs.nutrition, 35)
		needs.hydration = maxf(needs.hydration, 35)
		needs.fatigue = minf(needs.fatigue, 60)
		needs.meal_remaining = 0
		needs.meal = ""
		needs.water_remaining = 0
		needs.tea_remaining = 0
		hp = maxi(1, game.player.health_component.max_hp / 2)
		mp = game.player.mana_component.max_mp / 2
	game.player.health_component.hp = clampi(hp, 1, game.player.health_component.max_hp)
	game.player.mana_component.mp = clampi(mp, 0, game.player.mana_component.max_mp)
	game.player.health_component.health_changed.emit(game.player.health_component.hp, game.player.health_component.max_hp)
	game.player.mana_component.notify_changed()
	apply_recovery()
	game.ui.set_survival_status(status_line() + ("\n" + timers_line() if not timers_line().is_empty() else ""))

func timers_line() -> String:
	var parts: Array[String] = []
	if needs.meal_remaining > 0: parts.append("食物%.0fs" % needs.meal_remaining)
	if needs.water_remaining > 0: parts.append("饮水%.0fs" % needs.water_remaining)
	if needs.tea_remaining > 0: parts.append("茶%.0fs" % needs.tea_remaining)
	return " · ".join(parts)

func status_line() -> String:
	return "饱食%.0f · 饮水%.0f · 疲劳%.0f%s" % [needs.nutrition, needs.hydration, needs.fatigue, " · 疲惫" if needs.fatigue >= 85 else " · 困倦" if needs.fatigue >= 60 else ""]

func description() -> String:
	var recovery := needs.recovery()
	var text := status_line() + "\n\n远征中饱食约每15秒下降1，饮水每10秒下降1；疲劳随时间、施法和近战积累。耐力10以上每点降低2%消耗，最多30%。营地需要消耗为四分之一，不积累时间疲劳。暂停和离线不消耗。\n"
	text += "饱食或饮水≤20，相应自然回复降为35%；疲劳60/85时准备×1.15/1.25，85时两种自然回复再减半。不会额外扣生命，也不封锁近战、闪避或返程。\n"
	text += "当前生命自然回复×%.2f、额外%.1f/秒；法力×%.2f、额外%.1f/秒；疲劳准备×%.2f。仍遵守受伤/施法后的原回复延迟。\n" % [recovery.health_multiplier, recovery.health_bonus, recovery.mana_multiplier, recovery.mana_bonus, needs.preparation_multiplier()]
	if needs.meal_remaining > 0: text += "食物：%s %.0f秒\n" % [supplies.title(needs.meal), needs.meal_remaining]
	if needs.water_remaining > 0: text += "饮水恢复：%.0f秒\n" % needs.water_remaining
	if needs.tea_remaining > 0: text += "醒神茶：%.0f秒\n" % needs.tea_remaining
	text += "\n水袋共%d/%d份：饮用水%d，未净化水%d。\n" % [SurvivalCatalog.water_count(supplies), SurvivalCatalog.WATER_CAPACITY, supplies.count("clean_water"), supplies.count("dirty_water")]
	text += "普通魔法水面可洗毒，但不是可随取的饮用水。标记水源才可装水；未净化水需要炭屑过滤并煮沸。冰阻塞取水，电水危险，污染会让清水变浑。回廊排污泵修好后改善原水源。\n\n烹饪可用炭屑，或先对锅旁火位施放火花，借实际燃烧节省燃料。净水仍需1炭屑过滤。营地炉灶常燃。N查看补给，营地篝火主动休整；返营和读档不自动补满。"
	return text

func show_page() -> void:
	if game.session and game.session.supply_page.is_valid():
		game.session.supply_page.call()
		return
	var recovery := needs.recovery()
	var text := status_line() + "\n" + timers_line() + "\n\n"
	var demands: Array[String] = []
	if needs.nutrition <= 20: demands.append("饱食不足：食品可改善生命回复")
	if needs.hydration <= 20: demands.append("饮水不足：饮水可改善法力回复")
	if needs.fatigue >= 60: demands.append("疲劳影响准备：茶或休整可缓解")
	text += "；".join(demands) if not demands.is_empty() else "当前需求稳定，可按下一场遭遇选择补给。"
	text += "\n额外恢复：生命%.1f/秒，法力%.1f/秒（受原回复延迟约束）。\n使用补给需要站定，移动或受伤会打断，成功才消费。\n\n可用补给\n" % [recovery.health_bonus, recovery.mana_bonus]
	var buttons: Array[Dictionary] = []
	for id in SurvivalCatalog.FOODS:
		if supplies.count(id) < 1: continue
		text += "%s ×%d · %s\n" % [supplies.title(id), supplies.count(id), SurvivalCatalog.FOODS[id].text]
		buttons.append({"title": "使用：" + supplies.title(id), "callback": begin_eating.bind(id)})
	if buttons.is_empty(): text += "没有可直接使用的补给。可寻找已发现的水源、采集点、锅位或返回营地整备。\n"
	text += "\n原料：谷粮%d · 苦叶%d · 水袋%d/%d\n" % [supplies.count("grain"), supplies.count("herb"), SurvivalCatalog.water_count(supplies), SurvivalCatalog.WATER_CAPACITY]
	buttons.append({"title": "详细规则与休整说明", "callback": show_rules})
	if supplies.count("dirty_water") > 0: buttons.append({"title": "倒掉未净化水", "callback": begin_discard})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("远征补给 · 饮食与休整", text, buttons)

func show_rules() -> void:
	game.ui.show_panel("远征补给 · 详细规则", description(), [{"title": "返回补给", "callback": show_page}, {"title": "继续探索", "callback": game.ui.close_modal}])

func method(id: String, title: String, duration: float, costs: Dictionary = {}) -> FieldWorkMethod:
	var result := FieldWorkMethod.new()
	result.id = id
	result.title = title
	result.duration = duration
	result.material_costs = costs.duplicate()
	return result

func begin_eating(id: String) -> void:
	if not SurvivalCatalog.FOODS.has(id): return
	game.ui.close_modal()
	var option := method("eat:" + id, "使用" + supplies.title(id), SurvivalCatalog.FOODS[id].seconds, {id: 1})
	_open(game.player, [option], "使用期间战斗继续，受伤或移动会取消；成功才消费。" + SurvivalCatalog.FOODS[id].text)
	game.player.field_work.start_selected()

func begin_discard() -> void:
	game.ui.close_modal()
	var option := method("discard", "倒掉全部未净化水", .6, {"dirty_water": supplies.count("dirty_water")})
	_open(game.player, [option], "先倒掉浑水，才有空间重新装水。")
	game.player.field_work.start_selected()

func mount(spec: SurvivalStationData) -> void:
	var node := game.builder._add_interaction(spec.title, spec.pos, Callable(), "mechanism" if spec.kind in ["cook", "water"] else "note")
	node.set_meta("survival_station", spec)
	node.callback = inspect.bind(node, spec)
	if spec.kind == "cook":
		var marker := Label.new()
		marker.text = "干柴火位：火花点燃"
		marker.position = spec.heat_offset + Vector2(-70, -30)
		marker.add_theme_font_size_override("font_size", 11)
		node.add_child(marker)
		if not spec.lit:
			SurfaceManager.instance.apply_area(node.global_position + spec.heat_offset, 0, [], "伙房干柴", "oiled", 3600)

func mount_rest(node: ExplorationInteractable) -> void:
	node.set_meta("survival_rest", true)
	node.callback = inspect_rest.bind(node)

func inspect_field_rest(node: ExplorationInteractable) -> void:
	_open(node, [method("rest:short", "野外短休3秒：生命+40/法力+30/疲劳-25", 3)], "短休消耗饱食5、饮水10；敌人、移动和其他动作仍会打断。不提供粗食或充分休整。旁边锅位仍需燃料或实际火源。")

func field_rest_available(node: Node2D) -> bool:
	var id := str(node.get_meta("survival_field_rest", ""))
	for facility in game.current_data.facilities:
		if facility.id == id and facility.service == "outpost" and game.progress.claims.has(id): return true
	return false

func inspect_rest(node: ExplorationInteractable) -> void:
	_open(node, [method("rest:short", "短休3秒：生命+40/法力+30/疲劳-25", 3), method("rest:full", "充分休整6秒：恢复生命法力/疲劳归零", 6), method("basic", "营地粗食2秒：饱食与饮水至少60", 2)], "短休消耗饱食5、饮水10；充分休整消耗饱食20、饮水25。粗食不产生物品或额外恢复Buff，补给耗尽时仍可整备。")

func inspect(node: ExplorationInteractable, spec: SurvivalStationData) -> void:
	if not _available(node, spec): return
	game.progress.claims["seen." + spec.id] = true
	game._queue_save()
	var options: Array[FieldWorkMethod] = []
	var guide := ""
	match spec.kind:
		"cook":
			guide = "点燃锅旁干柴可省1炭屑燃料；净水的过滤炭屑仍需。避开燃烧格，在锅80范围内操作。火源失效会取消，不额外收料。营地常燃；茶与汤需记录。"
			for id in SurvivalCatalog.RECIPES:
				var recipe: Dictionary = SurvivalCatalog.RECIPES[id]
				options.append(method("cook:" + id, "过滤并煮沸" if id == "purify" else "制作" + supplies.title(recipe.output), 3, cooking_cost(id, node, spec)))
		"water":
			var water := water_quality(node, spec)
			var count := maxi(0, SurvivalCatalog.WATER_CAPACITY - SurvivalCatalog.water_count(supplies))
			options.append(method("fill:" + water + ":" + str(count), "水源暂不可取" if water == "blocked" else "装水袋：" + supplies.title(water) + " ×" + str(count), 1.5))
			guide = "冰面需先融化，导电需先消退或断路。污染会产生未净化水。水袋满时可在N饮用或倒掉浑水。"
		"forage":
			options.append(method("harvest", "采集：" + supplies.describe_cost(spec.harvest), 2))
			guide = "采后需要240秒实际游戏时间再生；休整、切区、读档、重置遭遇均不立即补货。暂停与离线不推进。"
	_open(node, options, guide, spec)

func _open(node: Node2D, options: Array[FieldWorkMethod], guide: String, spec: SurvivalStationData = null) -> void:
	game.player.field_work.inspect(node, "远征补给", options, _reason.bind(node, spec), _complete.bind(node, spec), guide)

func _available(node: Node2D, spec: SurvivalStationData) -> bool:
	if game._switching or game.player.health_component.is_dead or not is_instance_valid(node) or not node.is_inside_tree(): return false
	if node == game.player: return spec == null
	return node.get_parent() == game.region_root and ((spec != null and node.has_meta("survival_station") and node.get_meta("survival_station") == spec and spec in game.current_data.survival_stations) or (spec == null and ((game.is_at_base() and node.get_meta("survival_rest", false)) or field_rest_available(node))))

func has_heat(node: Node2D, spec: SurvivalStationData) -> bool:
	return spec.lit or SurfaceManager.instance.surface_at(node.global_position + spec.heat_offset).get("state", "dry") == "burning"

func cooking_cost(id: String, node: Node2D, spec: SurvivalStationData) -> Dictionary:
	var costs: Dictionary = SurvivalCatalog.RECIPES[id].inputs.duplicate()
	if not has_heat(node, spec): costs["charcoal"] = int(costs.get("charcoal", 0)) + 1
	return costs

func water_quality(node: Node2D, spec: SurvivalStationData) -> String:
	var state: String = SurfaceManager.instance.surface_at(node.global_position).get("state", "dry")
	if state == "poisoned": return "dirty_water"
	if state in ["frozen", "electrified", "burning", "steam", "oiled"]: return "blocked"
	return "clean_water" if spec.clean or (not spec.cleaned_by_claim.is_empty() and game.progress.claims.has(spec.cleaned_by_claim)) else "dirty_water"

func _reason(option: FieldWorkMethod, node: Node2D, spec: SurvivalStationData) -> String:
	if not _available(node, spec) or node.global_position.distance_to(game.player.global_position) > PlayerFieldWork.RANGE: return "补给点已不可用"
	var parts := option.id.split(":")
	match parts[0]:
		"eat":
			if node != game.player or parts.size() != 2 or not SurvivalCatalog.FOODS.has(parts[1]) or option.material_costs != {parts[1]: 1}: return "食物配置已变化"
		"discard":
			if node != game.player or supplies.count("dirty_water") <= 0 or option.material_costs != {"dirty_water": supplies.count("dirty_water")}: return "没有可倒掉的未净化水"
		"cook":
			if not spec or spec.kind != "cook" or parts.size() != 2 or not SurvivalCatalog.RECIPES.has(parts[1]): return "烹饪配置无效"
			var recipe: Dictionary = SurvivalCatalog.RECIPES[parts[1]]
			if not str(recipe.unlock).is_empty() and not game.progress.claims.has(recipe.unlock): return "尚未学会：在档案室寻找醒神茶，在回廊寻找炖汤记录"
			if option.material_costs != cooking_cost(parts[1], node, spec): return "火源已变化，请重新选择，未扣材料"
		"fill":
			if not spec or spec.kind != "water" or parts.size() != 3: return "水源配置无效"
			var quality := water_quality(node, spec)
			if quality == "blocked": return "水源冻结、导电或被其他介质覆盖，暂不可取水"
			if quality != parts[1]: return "水质已变化，请重新查看"
			var count := SurvivalCatalog.WATER_CAPACITY - SurvivalCatalog.water_count(supplies)
			if count <= 0 or count != int(parts[2]): return "水袋容量已变化或已满，N可饮用或倒掉浑水"
		"harvest":
			if not spec or spec.kind != "forage": return "采集点已失效"
			if needs.harvests.has(spec.id): return "尚在再生：%.0f秒" % needs.harvests[spec.id]
		"rest", "basic":
			if not game.is_at_base() or not node.get_meta("survival_rest", false):
				if not field_rest_available(node) or option.id != "rest:short": return "需要营地篝火；前哨仅可短休"
			if parts[0] == "rest" and (parts.size() != 2 or parts[1] not in ["short", "full"]): return "未知休整方式"
		_:
			return "未知补给操作"
	if parts[0]=="eat": return "" if supplies.can_pay_combat(option.material_costs) else "先把食物移入随身口袋"
	return "" if supplies.can_pay(option.material_costs) else "材料不足"

func _complete(option: FieldWorkMethod, node: Node2D, spec: SurvivalStationData) -> bool:
	if not _reason(option, node, spec).is_empty(): return false
	var parts := option.id.split(":")
	supplies.begin_transaction()
	if not supplies.pay(option.material_costs,option.id.begins_with("eat:")):
		supplies.finish_transaction(false)
		return false
	var outputs: Dictionary={}
	if parts[0]=="cook": outputs={SurvivalCatalog.RECIPES[parts[1]].output:1}
	elif parts[0]=="fill": outputs={parts[1]:int(parts[2])}
	elif parts[0]=="harvest": outputs=spec.harvest
	var before: Dictionary={}
	for key in outputs: before[key]=supplies.count(key)
	supplies.grant(outputs)
	for key in outputs:
		if supplies.count(key)-before[key]!=outputs[key]:
			supplies.finish_transaction(false)
			game.ui.notify("空间不足，未消耗材料。")
			return false
	match parts[0]:
		"eat":
			needs.consume(parts[1])
			var buffs := game.player.get_node("BuffManager") as BuffManager
			if parts[1] == "tea": buffs.remove_status("poison")
			if parts[1] == "dirty_water": buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
		"harvest":
			needs.harvests[spec.id] = 240.0
		"basic":
			needs.nutrition = maxf(needs.nutrition, 60)
			needs.hydration = maxf(needs.hydration, 60)
		"rest":
			var full := parts[1] == "full"
			needs.nutrition = maxf(0, needs.nutrition - (20 if full else 5))
			needs.hydration = maxf(0, needs.hydration - (25 if full else 10))
			needs.fatigue = 0 if full else maxf(0, needs.fatigue - 25)
			if full:
				var hp := game.player.health_component.hp
				var mp := game.player.mana_component.mp
				game._restore_player()
				game.player.health_component.recovered.emit(float(maxi(0, game.player.health_component.hp - hp)), "rest")
				game.player.mana_component.recovered.emit(float(maxi(0, game.player.mana_component.mp - mp)), "rest")
			else:
				game.player.heal(40, "rest")
				game.player.restore_mp(30, "rest")
	var notify := supplies.finish_transaction(true)
	apply_recovery()
	if notify.is_valid(): notify.call()
	game._save_progress()
	game.ui.set_survival_status(status_line() + ("\n" + timers_line() if not timers_line().is_empty() else ""))
	game.ui.notify("完成：" + option.title + "\n" + status_line())
	return true
