class_name FlatBonusModifier
extends DamageModifier
## 固定值加成修改器 — 直接加减伤害
## 
## 示例：武器+5伤害、附魔+10火焰伤害
## 
## 阶段：FLAT（加法层），和 StatScalingModifier 同阶段

@export var flat_bonus: int = 0                   ## 固定加成（可为负）


func _init() -> void:
	stage = Stage.FLAT
	priority = 0


func modify(ctx: DamageContext) -> void:
	if not should_apply(ctx):
		return
	ctx.final_damage += flat_bonus
	ctx.final_damage = maxi(1, ctx.final_damage)  # 最低 1 伤害
