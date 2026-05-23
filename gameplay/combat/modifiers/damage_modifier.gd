class_name DamageModifier
extends Resource
## 伤害修改器 — Pipeline 中的一个节点
## 
## 每个子类覆写 modify() 来改变 DamageContext.final_damage
## 
## ── 阶段化执行（核心升级） ──
## 伤害不是算出来的，是一层层改出来的。
## 阶段保证执行顺序，消除隐式顺序依赖：
##   FLAT → MULTIPLY → OVERRIDE → FINAL
## 
## 设计原则：
##   - 纯数据驱动：所有参数 @export，可存为 .tres
##   - 标签匹配：通过 required_tags / ignored_tags 控制应用范围
##   - 无状态：每次 modify() 独立执行
##   - 阶段隔离：同阶段内按 priority 排序

## ── 执行阶段（关键） ──
enum Stage {
	FLAT,        ## 加法层：属性缩放、固定加成（+10, +int*0.5）
	MULTIPLY,    ## 乘法层：标签倍率、百分比Buff（*1.2 fire, *1.5 rage）
	OVERRIDE,    ## 覆盖层：规则级覆写（火免→0、必暴、无敌）
	FINAL,       ## 最终层：钳制、暴击倍率、后处理
}

## 此 modifier 所属阶段
@export var stage: Stage = Stage.MULTIPLY

## 阶段内优先级（越大越后执行，默认 0）
@export var priority: int = 0

## ── 控制字段 ──

## 需要匹配的标签（空 = 对所有技能生效）
@export var required_tags: Array[String] = []

## 排除的标签（优先级高于 required_tags）
@export var ignored_tags: Array[String] = []

## 是否启用
@export var enabled: bool = true


## ── 核心方法（子类覆写） ──

func modify(ctx: DamageContext) -> void:
	pass


## ── 管线辅助 ──

## 判断是否应该应用到该 context
func should_apply(ctx: DamageContext) -> bool:
	if not enabled:
		return false
	# 排除优先
	if ctx.has_any_tag(ignored_tags):
		return false
	# 有 required 则必须匹配
	if not required_tags.is_empty():
		return ctx.has_any_tag(required_tags)
	return true
