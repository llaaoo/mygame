class_name PlayerCastingController
extends Node

var player: Player
var aiming_sources: Dictionary = {}
var _charging_source: String = ""       ## 正在蓄力的槽位
var _charge_power: float = 0.0          ## 当前蓄力倍率
var _charge_skill: SkillData = null     ## 正在蓄力的技能数据
var _channeling_source: String = ""     ## 正在引导的槽位
var _channel_payload_signature := 0
var _channel_empower := false
var _channel_revision := -1
var _charge_revision := -1
var _channel_skill: SkillData = null    ## 正在引导的技能
var _channel_mana_total := 0.0
var _channel_timer: float = 0.0         ## tick 累加器
var _aim_line: Line2D = null
var _aim_dot: Sprite2D = null
var _aim_distance: float = 60.0
var _aim_ground_targeted := false
var _aim_ring: Line2D
var _ring_radius := -1.0
var _aim_refresh := 0.0

func aimed_source() -> String:
	# Dictionary insertion order follows the latest pressed source. Releasing one
	# source falls back to any other source that is still being held.
	return str(aiming_sources.keys().back()) if not aiming_sources.is_empty() else ""

func _init(actor: Player) -> void:
	player = actor

func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)

func _setup_aim_indicator() -> void:
	_aim_line = Line2D.new()
	_aim_line.name = "AimLine"
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1, 1, 1, 0.5)
	_aim_line.z_index = 20
	_aim_line.visible = false
	player.add_child(_aim_line)

	_aim_dot = Sprite2D.new()
	_aim_dot.name = "AimDot"
	_aim_dot.texture = load("res://content/art/placeholders/aim_dot.png")
	_aim_dot.scale = Vector2(0.08, 0.08)
	_aim_dot.modulate = Color(1, 1, 1, 0.6)
	_aim_dot.z_index = 20
	_aim_dot.visible = false
	player.add_child(_aim_dot)
	_aim_ring = Line2D.new()
	_aim_ring.name = "GroundTargetArea"
	_aim_ring.width = 1.5
	_aim_ring.z_index = 19
	_aim_ring.visible = false
	player.add_child(_aim_ring)

func _charge_source_matches(source: String) -> bool:
	return source == _charging_source or (
		_charging_source.begins_with("slot_") and source.begins_with("slot_") and
		_charging_source.trim_prefix("slot_").to_int() == source.trim_prefix("slot_").to_int())

func _begin_charge(source: String, skill: SkillData) -> void:
	_charging_source = source
	_charge_revision=player.skill_manager.shortcuts.revision(source)
	_charge_skill = skill
	_charge_power = 0.0
	show_aim(source, skill)
	print("⏳ [Charge] 开始蓄力: %s (%.1fs 满蓄)" % [skill.display_name, skill.charge_duration])

func _cancel_charge() -> void:
	if _charging_source != "":
		print("⏹️ [Charge] 取消蓄力: %s" % _charge_skill.display_name if _charge_skill else "?")
	_charging_source = ""
	_charge_skill = null
	_charge_power = 0.0

func _begin_channel(source: String, skill: SkillData, empower := false) -> void:
	_channeling_source = source
	_channel_revision=player.skill_manager.shortcuts.revision(source)
	_channel_skill = skill
	_channel_empower=empower
	_channel_payload_signature = _payload_signature(skill)
	_channel_timer = 0.0
	_channel_mana_total = 0.0
	show_aim(source, skill)
	print("🌀 [Channel] 开始引导: %s (MP %.0f/s)" % [skill.display_name, skill.channel_mp_per_sec])

func _cancel_channel() -> void:
	if _channeling_source != "":
		print("⏹️ [Channel] 停止引导: %s" % _channel_skill.display_name if _channel_skill else "?")
	_channeling_source = ""
	_channel_skill = null
	_channel_timer = 0.0
	_channel_mana_total = 0.0

func _payload_signature(skill: SkillData) -> int:
	var supplies:=player.skill_manager.combinations.supplies
	var choice:=player.skill_manager.selection_for_source(_channeling_source)
	return hash(choice) if not choice.is_empty() else hash([supplies.selected.get(skill.get_id(),""),supplies.prepared_uids.get(skill.get_id(),""),supplies.modifiers.get(skill.get_id(),"")])

func _channel_tick(mana_cost: int) -> bool:
	if not _channel_skill or not _is_equipped(_channeling_source, _channel_skill):
		return false
	if not _channel_skill.operation_id.is_empty() and _payload_signature(_channel_skill)!=_channel_payload_signature: return false
	var ctx := CastContext.simple(player, player.get_mouse_direction(), _channel_skill)
	ctx.empower=_channel_empower
	ctx.selection=player.skill_manager.selection_for_source(_channeling_source)
	ctx.binding_revision=_channel_revision
	return player.skill_manager.use_channel_tick(_channeling_source, player, ctx, mana_cost)

func cast_hand_charged(hand: String, charge_power: float) -> bool:
	var ctx := CastContext.simple(player, player.get_mouse_direction(), player._get_skill_for_source(hand))
	ctx.charge_power = charge_power
	return player.skill_manager.use_hand_with_context(hand, player, ctx)

func cast_slot_charged(idx: int, charge_power: float) -> bool:
	var ctx := CastContext.simple(player, player.get_mouse_direction(), player._get_skill_for_source("slot_%d" % idx))
	ctx.charge_power = charge_power
	return player.skill_manager.use_slot_with_context(idx, player, ctx)

func tick(delta: float) -> void:
	if player.health_component.is_dead:
		cancel_all()
		return
	if _charge_skill and (not _is_equipped(_charging_source, _charge_skill) or player.skill_manager.shortcuts.revision(_charging_source)!=_charge_revision):
		cancel_source(_charging_source)
	if _channel_skill and (not _is_equipped(_channeling_source, _channel_skill) or player.skill_manager.shortcuts.revision(_channeling_source)!=_channel_revision):
		cancel_source(_channeling_source)
	_aim_refresh -= delta
	if _aim_refresh <= 0 and not aiming_sources.is_empty():
		_aim_refresh = .1
		var source := aimed_source()
		var instance := player.skill_manager.get_instance(source)
		if instance: show_aim(source, instance.data)
	# 蓄力累加
	if _charging_source != "" and _charge_skill:
		_charge_power = minf(1.0, _charge_power + delta / maxf(0.001, _charge_skill.charge_duration))
		# 更新瞄准指示器大小反映蓄力进度
		if _aim_dot and _aim_dot.visible:
			_aim_dot.scale = Vector2(0.08, 0.08) * (0.5 + _charge_power * 1.0)

	# 引导 tick
	if _channeling_source != "" and _channel_skill:
		_channel_timer += delta
		var interval := maxf(0.001, _channel_skill.channel_tick_interval)
		while _channel_skill and _channel_timer + 0.000001 >= interval:
			_channel_timer = maxf(0, _channel_timer - interval)
			var total := _channel_mana_total + maxf(0, _channel_skill.channel_mp_per_sec) * interval * CastCostPolicy.mana_multiplier(_channel_skill, player)
			var cost := ceili(total - 0.000001) - ceili(_channel_mana_total - 0.000001)
			if not _channel_tick(cost):
				_cancel_channel()
				aiming_sources.clear()
				hide_aim()
				break
			_channel_mana_total = total

	var plan := player.skill_manager.combinations.pending
	if not plan.is_empty() and plan.has_target_position and plan.skill.skill_type == SkillData.SkillType.AOE:
		var radius := plan.skill.aoe_visual.radius if plan.skill.aoe_visual else plan.skill.aoe_radius
		var color := plan.skill.aoe_visual.color if plan.skill.aoe_visual else _aim_color(plan.skill.skill_type)
		show_ground_area(plan.target_position, radius, color)
	elif not _aim_dot or not _aim_dot.visible or not _aim_ground_targeted:
		if _aim_ring: _aim_ring.hide()
	if not _aim_dot or not _aim_dot.visible:
		return
	if _aim_line.visible:
		var dir := player.get_mouse_direction()
		var point := CastContext.ground_point(player, player.get_global_mouse_position(), _aim_distance) if _aim_ground_targeted else player.global_position + dir * _aim_distance
		_aim_line.points = PackedVector2Array([Vector2.ZERO, player.to_local(point)])
		_aim_dot.global_position = point
		if _aim_ground_targeted:
			show_ground_area(point, _ring_radius, _aim_dot.modulate)
	else:
		_aim_dot.global_position = player.global_position

func show_aim(_source: String, skill: SkillData) -> void:
	if not skill or not _aim_line or not _aim_dot:
		return
	if player.skill_manager.combinations and player.skill_manager.combinations.handles(skill):
		skill = player.skill_manager.preview_source(_source, Input.is_key_pressed(KEY_SHIFT)).skill

	_aim_ground_targeted = skill.ground_targeted
	if not _aim_ground_targeted and _aim_ring:
		_aim_ring.hide()
	var color := skill.aoe_visual.color if skill.skill_type == SkillData.SkillType.AOE and skill.aoe_visual else _aim_color(skill.skill_type)
	if skill.skill_type == SkillData.SkillType.PROJECTILE:
		color = Color(ElementVisuals.color_for(skill.tags), .7)
	elif skill.skill_type == SkillData.SkillType.BUFF and skill.buff_resource:
		color = Color(ElementVisuals.status_color(skill.buff_resource.status_id), .6)

	match skill.skill_type:
		SkillData.SkillType.PROJECTILE:
			_aim_distance = minf(360, skill.projectile_speed * skill.projectile_lifetime)
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.08, 0.08)
			_aim_dot.visible = true

		SkillData.SkillType.BUFF:
			_aim_line.visible = false
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.5, 0.5)
			_aim_dot.visible = true

		SkillData.SkillType.AOE:
			_aim_distance = skill.cast_distance
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			var radius := skill.aoe_visual.radius if skill.aoe_visual else skill.aoe_radius
			_aim_dot.scale = Vector2(radius / 80.0, radius / 80.0)
			_aim_dot.visible = true
			if _aim_ground_targeted:
				show_ground_area(CastContext.ground_point(player, player.get_global_mouse_position(), _aim_distance), radius, color)

		SkillData.SkillType.DASH:
			_aim_distance = skill.dash_distance
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.08, 0.08)
			_aim_dot.visible = true

		_:
			_aim_distance = 60.0
			_aim_line.default_color = color
			_aim_line.visible = true
			_aim_dot.modulate = color
			_aim_dot.scale = Vector2(0.08, 0.08)
			_aim_dot.visible = true

func _aim_color(skill_type: int) -> Color:
	match skill_type:
		SkillData.SkillType.BUFF:       return Color(0.3, 0.7, 1.0, 0.5)
		SkillData.SkillType.AOE:        return Color(1.0, 0.3, 0.1, 0.6)
		SkillData.SkillType.DASH:       return Color(0.3, 1.0, 0.5, 0.6)
		SkillData.SkillType.PROJECTILE: return Color(1.0, 0.5, 0.2, 0.7)
		SkillData.SkillType.SUMMON:     return Color(0.7, 0.4, 1.0, 0.6)
	return Color.WHITE

func hide_aim() -> void:
	if _aim_ring: _aim_ring.hide()
	if _aim_line: _aim_line.visible = false
	if _aim_dot: _aim_dot.visible = false

func _is_equipped(source: String, skill: SkillData) -> bool:
	var slot := player.skill_manager.get_instance(source)
	return slot != null and slot.data == skill


func cancel_source(source: String) -> void:
	if _charge_source_matches(source):
		_cancel_charge()
	if _channeling_source == source:
		_cancel_channel()
	aiming_sources.erase(source)
	if aiming_sources.is_empty():
		hide_aim()


func cancel_all() -> void:
	_cancel_charge()
	_cancel_channel()
	aiming_sources.clear()
	hide_aim()

func show_ground_area(point: Vector2, radius: float, color: Color) -> void:
	if not _aim_ring:
		return
	if not is_equal_approx(_ring_radius, radius):
		_ring_radius = radius
		var points := PackedVector2Array()
		for i in range(49):
			points.append(Vector2.from_angle(float(i) * TAU / 48.0) * radius)
		_aim_ring.points = points
	_aim_ring.default_color = Color(color, 0.7)
	_aim_ring.global_position = point
	_aim_ring.show()
