class_name LevelUpUI
extends CanvasLayer
## 升级属性分配界面 — 显示在升级时，允许分配属性点

## ── 信号 ──
signal allocation_confirmed
signal allocation_cancelled

## ── 引用 ──
var stats_component: StatsComponent = null

## ── 待确认的分配（stat_name → 增量） ──
var _pending: Dictionary = {}

## ── 节点引用 ──
@onready var _background: ColorRect = $Background
@onready var _panel: Panel = $Panel
@onready var _level_label: Label = $Panel/MarginContainer/MainVBox/LevelLabel
@onready var _points_label: Label = $Panel/MarginContainer/MainVBox/PointsLabel
@onready var _derived_label: RichTextLabel = $Panel/MarginContainer/MainVBox/DerivedStatsLabel
@onready var _confirm_button: Button = $Panel/MarginContainer/MainVBox/ConfirmButton
@onready var _effect_flash: ColorRect = $LevelUpEffect/FlashRect
@onready var _effect_label: Label = $LevelUpEffect/LevelUpText

## 属性行引用 {stat_name: {value_label, preview_label, minus_btn, plus_btn}}
var _stat_rows: Dictionary = {}

const STAT_NAMES: Array[String] = ["strength", "intelligence", "agility", "endurance"]
const STAT_DISPLAY: Dictionary = {
	"strength":     {"icon": "💪", "name": "力量"},
	"intelligence": {"icon": "🧠", "name": "智力"},
	"agility":      {"icon": "🏃", "name": "敏捷"},
	"endurance":    {"icon": "🛡️", "name": "耐力"},
}


func _ready() -> void:
	hide()
	_setup_stat_rows()
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _input(event: InputEvent) -> void:
	# 面板显示时只拦截键盘输入，保留鼠标给 UI 按钮
	if visible and event is InputEventKey:
		get_viewport().set_input_as_handled()


func setup(comp: StatsComponent) -> void:
	stats_component = comp
	# 注意: 不在此处连接 leveled_up 信号，由 HUD 统一管理调用


## ── 绑定节点引用 ──

func _setup_stat_rows() -> void:
	for stat_name in STAT_NAMES:
		var row = _panel.get_node_or_null("MarginContainer/MainVBox/StatRow_%s" % stat_name.capitalize())
		if not row:
			continue
		_stat_rows[stat_name] = {
			"value_label": row.get_node("ValueLabel"),
			"preview_label": row.get_node("PreviewLabel"),
			"minus_btn": row.get_node("MinusBtn"),
			"plus_btn": row.get_node("PlusBtn"),
		}
		_stat_rows[stat_name]["plus_btn"].pressed.connect(_on_plus.bind(stat_name))
		_stat_rows[stat_name]["minus_btn"].pressed.connect(_on_minus.bind(stat_name))


## ── 升级回调 ──

func _on_level_up(new_level: int) -> void:
	_pending.clear()
	_level_label.text = "🎉 升级！ Lv.%d" % new_level
	_refresh_all()
	_show_with_effect()


## ── 显示 / 隐藏 ──

func _show_with_effect() -> void:
	show()

	# 重置特效元素
	_effect_flash.modulate.a = 0.7
	_effect_flash.visible = true
	_effect_label.modulate.a = 1.0
	_effect_label.scale = Vector2(0.3, 0.3)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)

	var tween := create_tween()
	tween.set_parallel(true)

	# 闪光快速淡出
	tween.tween_property(_effect_flash, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_effect_flash.set_visible.bind(false)).set_delay(0.6)

	# LEVEL UP 文字弹出
	tween.tween_property(_effect_label, "scale", Vector2(1.2, 1.2), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(_effect_label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tween.tween_property(_effect_label, "scale", Vector2(1.5, 1.5), 0.4).set_delay(0.6)

	# 面板淡入
	var pt := create_tween()
	pt.tween_property(_panel, "modulate:a", 1.0, 0.35).set_delay(0.3).set_ease(Tween.EASE_OUT)
	pt.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.35).set_delay(0.3).set_ease(Tween.EASE_OUT)


func _hide() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.2)
	tween.tween_callback(hide).set_delay(0.2)


## ── 按钮回调 ──

func _on_plus(stat_name: String) -> void:
	if not stats_component:
		return
	if _total_pending() >= stats_component.attribute_points:
		return
	_pending[stat_name] = _pending.get(stat_name, 0) + 1
	_refresh_all()


func _on_minus(stat_name: String) -> void:
	var cur: int = _pending.get(stat_name, 0)
	if cur <= 0:
		return
	_pending[stat_name] = cur - 1
	if _pending[stat_name] == 0:
		_pending.erase(stat_name)
	_refresh_all()


func _on_confirm_pressed() -> void:
	if not stats_component:
		return

	# 应用所有待确认的分配
	for stat_name in _pending:
		for _i in range(_pending[stat_name]):
			stats_component.spend_attribute_point(stat_name)

	_pending.clear()
	allocation_confirmed.emit()
	_hide()


## ── 计算 ──

func _total_pending() -> int:
	var total := 0
	for v in _pending.values():
		total += v
	return total


## ── 刷新显示 ──

func _refresh_all() -> void:
	if not stats_component:
		return

	var remaining := stats_component.attribute_points - _total_pending()
	_points_label.text = "可用属性点: %d" % remaining

	# 更新每个属性行
	for stat_name in STAT_NAMES:
		var row = _stat_rows.get(stat_name)
		if not row:
			continue
		var current_val: int = stats_component.get(stat_name)
		var pending_val: int = _pending.get(stat_name, 0)
		var new_val := current_val + pending_val

		row["value_label"].text = str(current_val)
		row["preview_label"].text = "→ %d" % new_val

		# 预览高亮
		if pending_val > 0:
			row["preview_label"].add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			row["preview_label"].add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		# 按钮状态
		row["plus_btn"].disabled = (remaining <= 0)
		row["minus_btn"].disabled = (pending_val <= 0)

	# 更新派生属性预览
	_refresh_derived_preview()

	# 确认按钮状态
	_confirm_button.disabled = (_total_pending() <= 0)
	_confirm_button.text = "确认分配 (%d点)" % _total_pending() if _total_pending() > 0 else "跳过"


func _refresh_derived_preview() -> void:
	if not stats_component:
		return

	# 计算临时属性值（当前 + 待确认）
	var s: int = stats_component.strength + (_pending.get("strength", 0) as int)
	var i: int = stats_component.intelligence + (_pending.get("intelligence", 0) as int)
	var a: int = stats_component.agility + (_pending.get("agility", 0) as int)
	var e: int = stats_component.endurance + (_pending.get("endurance", 0) as int)

	var hp_bonus: int = e * 5
	var phys_dmg: int = s * 2
	var magic_dmg: int = i * 2
	var speed_bonus: float = a * 3.0

	var lines: Array[String] = ["━━ 派生属性预览 ━━"]

	# 对比当前值
	var cur_hp: int = stats_component.endurance * 5
	var cur_phys: int = stats_component.strength * 2
	var cur_magic: int = stats_component.intelligence * 2
	var cur_speed: float = stats_component.agility * 3.0

	if hp_bonus != cur_hp:
		lines.append("❤️ 生命加成: %d → %s" % [cur_hp, _colored(hp_bonus, cur_hp)])
	else:
		lines.append("❤️ 生命加成: %d" % hp_bonus)

	if phys_dmg != cur_phys:
		lines.append("⚔️ 物理伤害: %d → %s" % [cur_phys, _colored(phys_dmg, cur_phys)])
	else:
		lines.append("⚔️ 物理伤害: %d" % phys_dmg)

	if magic_dmg != cur_magic:
		lines.append("🔮 魔法伤害: %d → %s" % [cur_magic, _colored(magic_dmg, cur_magic)])
	else:
		lines.append("🔮 魔法伤害: %d" % magic_dmg)

	if speed_bonus != cur_speed:
		lines.append("💨 移速加成: %.0f → %s" % [cur_speed, _colored_float(speed_bonus, cur_speed)])
	else:
		lines.append("💨 移速加成: %.0f" % speed_bonus)

	_derived_label.clear()
	for line in lines:
		_derived_label.append_text(line + "\n")


func _colored(new_val: int, old_val: int) -> String:
	if new_val > old_val:
		return "[color=#4dff4d]%d[/color]" % new_val
	return str(new_val)


func _colored_float(new_val: float, old_val: float) -> String:
	if new_val > old_val:
		return "[color=#4dff4d]%.0f[/color]" % new_val
	return "%.0f" % new_val
