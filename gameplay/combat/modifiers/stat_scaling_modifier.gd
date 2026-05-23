class_name StatScalingModifier
extends DamageModifier
## 属性缩放修改器 — 用 caster 的主属性放大伤害
## 
## 公式: final_damage += caster.stats.{stat} * effective_ratio
## 
## 阶段：FLAT（加法层），保证在乘法之前执行

## ── 配置 ──
@export var stat_name: String = "magic_damage"   ## StatsComponent 上的属性名
@export var ratio: float = 1.0                    ## 缩放系数 fallback（技能自身的 damage_scaling 优先）


func _init() -> void:
	stage = Stage.FLAT
	priority = 0


func modify(ctx: DamageContext) -> void:
	if not should_apply(ctx):
		return

	var stats := ctx.caster.get_node_or_null("StatsComponent")
	if not stats:
		return

	var stat_value: float = stats.get(stat_name) if stat_name in stats else 0.0

	# 优先用技能的 damage_scaling，没有则用 modifier 自身的 ratio
	var effective_ratio := ratio
	if ctx.skill and ctx.skill.damage_scaling != 0.0:
		effective_ratio = ctx.skill.damage_scaling

	ctx.final_damage += int(stat_value * effective_ratio)
