class_name LowHpTriggerData
extends Resource
## 低血量触发器配置 — 纯数据，描述血量低于阈值时做什么
##
## 示例 .tres:
##   hp_threshold = 0.3
##   cast_skill_id = "shadow_step"
##   target_mode = GenericTriggeredCast.TargetMode.ESCAPE
##   cooldown = 15.0

@export var hp_threshold: float = 0.3           ## 触发阈值 (0.3 = 30%)
@export var cast_skill_id: String = ""           ## 技能池中的技能 ID
@export var target_mode: int = 0                 ## GenericTriggeredCast.TargetMode 枚举值
@export var cooldown: float = 15.0               ## 冷却秒数
