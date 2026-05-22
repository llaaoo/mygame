class_name DamageContext
extends RefCounted
## 伤害管线上下文 — 在 Modifier Pipeline 中流转的数据载体
## 
## 生命周期：
##   1. SkillExecutor 创建，填入 base_damage / final_damage
##   2. 依次传入每个 DamageModifier.modify(ctx)
##   3. final_damage 被逐层修改
##   4. 最终值应用到目标

## ── 伤害值 ──
var base_damage: int = 0           ## 原始基础伤害（不变）
var final_damage: int = 0          ## 最终伤害（被 modifier 逐层修改）

## ── 参与者 ──
var caster: Node2D = null          ## 施法者
var target: Node2D = null          ## 目标

## ── 技能数据 ──
var skill: SkillData = null

## ── 标签（modifier 匹配依据） ──
## 来源：skill.tags + 可被 modifier 动态添加
var tags: Array[String] = []

## ── 元数据（任意 modifier 可读写） ──
## 例如：{"is_crit": true, "element": "fire"}
var meta: Dictionary = {}


## 从 CastContext + SkillData 构造
static func from_cast(skill: SkillData, ctx: CastContext) -> DamageContext:
	var dc := DamageContext.new()
	dc.base_damage = skill.damage
	dc.final_damage = skill.damage
	dc.caster = ctx.caster
	dc.target = ctx.target
	dc.skill = skill
	dc.tags.assign(skill.tags.duplicate() if skill.tags else [])
	return dc


## 是否包含某个标签
func has_tag(tag: String) -> bool:
	return tag in tags


## 是否包含任意标签
func has_any_tag(tag_list: Array[String]) -> bool:
	for t in tag_list:
		if t in tags:
			return true
	return false
