class_name PlayerAction
extends RefCounted
## 玩家意图 — 纯数据，不执行任何逻辑
##
## 由 Player._poll_actions() 每帧从 Input 产生
## 由各 State 根据自身规则决定如何响应


enum Type {
	MOVE,          ## 移动方向（direction 有效）
	MELEE,         ## 近战攻击
	CAST_PRESS,    ## 技能按下（开始瞄准）
	CAST_RELEASE,  ## 技能释放（松手）
	DODGE,         ## 闪避
	INTERACT,      ## 按 E 交互
}


var type: Type
var skill_source: String = ""  ## "left" / "right" / "slot_0"~"slot_3"
var direction: Vector2 = Vector2.ZERO
