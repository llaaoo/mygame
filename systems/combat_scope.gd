class_name CombatScope
extends RefCounted
## 战斗作用域 — 控制事件/效果的传播范围
## 
## 原则：
##   - SKILL_SCOPE：仅单次技能执行内有效，技能结束即销毁
##   - BATTLE_SCOPE：单场战斗内有效，战斗结束即销毁  
##   - GLOBAL_SCOPE：全局永久，需要显式移除

enum Scope {
	SKILL,          ## 单次技能（fireball cast → hit → done）
	BATTLE,         ## 单场战斗（buff aura 持续到战斗结束）
	GLOBAL,         ## 全局（装备/天赋永久效果）
}
