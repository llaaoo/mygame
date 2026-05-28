class_name BossData
extends Resource
## Boss 数据 — 纯数据 .tres，描述 Boss "是什么"
## 一个 .tres = 一种 Boss，不新建场景

@export var boss_name: String = "Boss"
@export var max_hp: int = 400
@export var attack_damage: int = 25
@export var detect_range: float = 250.0
@export var move_speed: float = 90.0
@export var attack_cooldown: float = 1.0
@export var color: Color = Color(1, 0.3, 0.1, 1)
@export var scale: float = 0.8

## 阶段技能: [[阈值, 技能ID], ...]
@export var phase_skills: Array[Array] = []

## 主动技能（每隔N秒释放）
@export var active_skill_id: String = ""
@export var active_skill_interval: float = 5.0

## 元素抗性: {"fire": 0.7, "ice": 0.0, ...}  — 0.7 = 70%减伤
@export var resists: Dictionary = {}

## 免疫的组（"fire_immune"等）
@export var immune_groups: Array[String] = []
