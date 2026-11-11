class_name DamageNumber
extends Node2D
## 浮动伤害/治疗数字 — 上浮 + 淡出 → 自毁
##
## 用法: DamageNumber.spawn(world, text, color, world_pos, scale)

const FLOAT_HEIGHT: float = 50.0
const DURATION: float = 0.7
const FADE_START: float = 0.55

var _label: Label = null
static var _offset_sequence := 0


func _ready() -> void:
	_label = Label.new()
	_label.name = "Label"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.z_index = 100
	add_child(_label)


## 配置并启动动画
func configure(text: String, color: Color, scale_mod: float = 1.0) -> void:
	if not _label:
		_label = Label.new()
		add_child(_label)

	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.015, 0.95))
	_label.add_theme_constant_override("outline_size", 2)
	GameUIStyle.apply_font_size(_label,int(16 * scale_mod))

	_play_anim()


func _play_anim() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# 上浮
	tween.tween_property(self, "position:y", position.y - FLOAT_HEIGHT, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 淡出（延迟开始）
	var fade_tween := create_tween()
	fade_tween.tween_interval(FADE_START)
	fade_tween.tween_property(self, "modulate:a", 0.0, DURATION - FADE_START).set_ease(Tween.EASE_IN)

	# 自毁
	tween.tween_callback(queue_free).set_delay(DURATION)


## ── 静态工厂方法 ──

## 伤害数字
static func spawn_damage(parent: Node, amount: int, world_pos: Vector2, is_crit: bool = false) -> void:
	var color: Color = Color(1, 0.2, 0.2, 1)  # 红色
	var scale: float = clampf(1.0 + amount * 0.02, 1.0, 2.0)
	var text: String = str(amount)

	if is_crit:
		color = Color(1, 0.75, 0.1, 1)  # 金色
		scale *= 1.4
		text = str(amount) + "!"

	_spawn(parent, text, color, world_pos, scale)


## 治疗数字
static func spawn_heal(parent: Node, amount: int, world_pos: Vector2) -> void:
	_spawn(parent, "+" + str(amount), Color(0.3, 1, 0.4, 1), world_pos, 1.0)


## 闪避文字
static func spawn_miss(parent: Node, world_pos: Vector2) -> void:
	_spawn(parent, "MISS", Color(0.6, 0.6, 0.6, 1), world_pos, 0.8)


## 内部生成
static func _spawn(parent: Node, text: String, color: Color, world_pos: Vector2, scale: float) -> void:
	var dn := DamageNumber.new()
	dn.name = "DamageNumber"
	# Cosmetic staggering never advances gameplay randomness.
	_offset_sequence+=1
	var point := world_pos + Vector2((_offset_sequence*7)%25-12,(_offset_sequence*5)%17-8)
	dn.position = parent.to_local(point) if parent is Node2D else point
	parent.add_child(dn)
	dn.configure(text, color, scale)

static func spawn_reaction(parent: Node, title: String, world_pos: Vector2) -> void:
	_spawn(parent, title, Color(0.55, 0.88, 1.0), world_pos, 0.9)
