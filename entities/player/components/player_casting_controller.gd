class_name PlayerCastingController
extends Node

var player: Player
var aiming_sources: Dictionary = {}
var cancel_aim: bool = false
var _charging_source: String = ""       ## 正在蓄力的槽位
var _charge_power: float = 0.0          ## 当前蓄力倍率
var _charge_skill: SkillData = null     ## 正在蓄力的技能数据
var _channeling_source: String = ""     ## 正在引导的槽位
var _channel_skill: SkillData = null    ## 正在引导的技能
var _channel_mana_total := 0.0
var _channel_timer: float = 0.0         ## tick 累加器
var _aim_line: Line2D = null
var _aim_dot: Sprite2D = null
var _aim_distance: float = 60.0

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

func _charge_source_matches(source: String) -> bool:
	return source == _charging_source or (
		_charging_source.begins_with("slot_") and source.begins_with("slot_") and
		_charging_source.trim_prefix("slot_").to_int() == source.trim_prefix("slot_").to_int())

func _begin_charge(source: String, skill: SkillData) -> void:
	_charging_source = source
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

func _begin_channel(source: String, skill: SkillData) -> void:
	_channeling_source = source
	_channel_skill = skill
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

func _channel_tick(mana_cost: int) -> bool:
	if not _channel_skill:
		return false
	var ctx := CastContext.simple(player, player.get_mouse_direction(), _channel_skill)
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

	if not _aim_dot or not _aim_dot.visible:
		return
	if _aim_line.visible:
		var dir := player.get_mouse_direction()
		_aim_line.points = PackedVector2Array([Vector2.ZERO, dir * _aim_distance])
		_aim_dot.global_position = player.global_position + dir * _aim_distance
	else:
		_aim_dot.global_position = player.global_position

func show_aim(_source: String, skill: SkillData) -> void:
	if not skill or not _aim_line or not _aim_dot:
		return
	if player.skill_manager.combinations and player.skill_manager.combinations.handles(skill):
		skill = player.skill_manager.combinations.preview(skill, player, Input.is_key_pressed(KEY_SHIFT)).skill

	var color := _aim_color(skill.skill_type)

	match skill.skill_type:
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
			_aim_dot.scale = Vector2(skill.aoe_radius / 80.0, skill.aoe_radius / 80.0)
			_aim_dot.visible = true

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
	if _aim_line: _aim_line.visible = false
	if _aim_dot: _aim_dot.visible = false

func cancel_all() -> void:
	_cancel_charge()
	_cancel_channel()
	aiming_sources.clear()
	hide_aim()
