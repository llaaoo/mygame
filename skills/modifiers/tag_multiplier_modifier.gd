class_name TagMultiplierModifier
extends DamageModifier
## 标签倍率修改器 — 匹配标签时，伤害乘以倍率
## 
## 示例：
##   required_tags = ["fire"] + multiplier = 1.2 → 火焰伤害 +20%
##   required_tags = ["shadow"] + multiplier = 0.7 → 暗影伤害 -30%
## 
## 阶段：MULTIPLY（乘法层），在 FLAT 之后、OVERRIDE 之前

@export var multiplier: float = 1.0              ## 倍率（1.2 = +20%, 0.7 = -30%）


func _init() -> void:
	stage = Stage.MULTIPLY
	priority = 0


func modify(ctx: DamageContext) -> void:
	if not should_apply(ctx):
		return
	ctx.final_damage = int(ceil(ctx.final_damage * multiplier))
