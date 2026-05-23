# 技能系统架构设计文档

> 版本: v1.3 | 日期: 2026-05-23
>
> **文档层级**: 本文档定义**技能内容生产**方式。Runtime 间边界见 [RUNTIME_TOPOLOGY](./RUNTIME_TOPOLOGY.md)，战斗内部契约见 [COMBAT_CONTRACTS](./COMBAT_CONTRACTS.md)，世界模拟契约见 [WORLD_CONTRACTS](./WORLD_CONTRACTS.md)。

---

## 核心原则

### 1. Skill = Data Composition, not Scene

技能本质是三个维度的组合：

```
Skill = Runtime Archetype + Payload + Visual Profile
```

- **Runtime Archetype**: 行为模型（怎么飞、怎么命中）
- **Payload**: 负载（伤害/Buff/召唤/表面生成）
- **Visual Profile**: 表现层（贴图/粒子/颜色/音效）

❌ 错误: 一个技能 = 一个 Scene 文件
✅ 正确: 200 个技能 = 5 个 Runtime Archetype + 200 个 .tres 配置

### 2. Scene = 行为模型，不是技能身份

只有"存在于世界中"才需要 Scene：
- 有位置 ✅
- 有生命周期 ✅
- 会被碰撞/查询 ✅
- 会被看到 ✅

| SkillType | 需要 Scene? | Archetype |
|-----------|------------|-----------|
| PROJECTILE | ✅ | linear_projectile |
| AOE | ✅ | persistent_aoe |
| BUFF | ❌ | 纯状态修改 |
| DASH | ❌ | 纯位移 |
| HEAL | ❌ | 数值修改 |
| SUMMON | ✅ | summon_entity (未来) |

### 3. Scene 数量与技能数量解耦

```
技能数: 200+
Scene 数: < 10
```

新增技能 = 创建 `.tres` 文件 + 填入配置。不应新增任何 Scene / Class / Runtime。

---

## 当前架构 (v1.3)

### 文件结构

```
res://skills/
├── archetypes/                    # Runtime 行为模板（< 10 个）
│   ├── linear_projectile.tscn     # 直线投射物
│   └── persistent_aoe.tscn        # 持久范围效果
│
├── data/                          # SkillData .tres（200+ 个）
│   ├── fireball_data.tres
│   ├── shadow_bolt_data.tres
│   ├── flame_storm_data.tres
│   └── ...
│
└── visuals/                       # 表现层 Resource (未来)
    └── projectile_visual_data.gd

res://runtime/combat/skills/
├── runtime/
│   ├── skill_executor.gd          # _ARCHETYPE_SCENES 映射 + execute()
│   ├── projectile.gd              # setup(skill, caster, dir) 驱动
│   ├── skill_instance.gd          # 冷却包装
│   └── cast_context.gd
├── data/
│   └── skill_data.gd              # 纯数据 Resource
├── manager/
│   └── skill_manager.gd
├── modifiers/                     # 伤害管线
└── conditions/                    # 条件判断
```

### SkillData 关键字段

```gdscript
# 行为
@export var archetype: String           # "linear_projectile" / "persistent_aoe"
@export var skill_type: SkillType       # PROJECTILE / AOE / BUFF / DASH

# 数值
@export var damage: int
@export var damage_scaling: float
@export var cooldown: float
@export var mp_cost: int

# 视觉（未来收敛为 ProjectileVisualData）
@export var projectile_color: Color
@export var projectile_scale: float
@export var projectile_texture: Texture2D
@export var aoe_color: Color
@export var aoe_radius: float
@export var aoe_lifetime: float

# 标签（Modifier 匹配）
@export var tags: Array[String]         # ["fire", "shadow", "aoe"]
```

### SkillExecutor._ARCHETYPE_SCENES

```gdscript
const _ARCHETYPE_SCENES := {
    "linear_projectile": "res://skills/archetypes/linear_projectile.tscn",
    "persistent_aoe":     "res://skills/archetypes/persistent_aoe.tscn",
}
```

### setup() 模式

```gdscript
# Projectile.setup(skill, caster, direction)
func setup(skill: SkillData, caster_node: Node2D, dir: Vector2) -> void:
    speed = skill.projectile_speed
    damage = skill.damage
    sprite.modulate = skill.projectile_color
    sprite.scale = Vector2(skill.projectile_scale, skill.projectile_scale)
```

---

## 发展阶段

### 阶段 1（当前）: Enum + 半数据驱动

- SkillData.archetype 枚举化
- 一个 GenericProjectile Scene
- SkillData 字段驱动视觉

### 阶段 2（中期）: Behavior Object

当逻辑开始明显重复时，将行为拆为独立对象：

```gdscript
projectile.movement = LinearMovement.new()
projectile.hit = ExplodeHit.new()
projectile.lifetime = TimeoutLifetime.new()
```

### 阶段 3（后期）: 完全组件化

Behavior Stack 模式，每个维度可独立组合。只在技能数 > 50 且行为差异明显时进入。

---

## Projectile 行为维度

| 维度 | 策略 |
|------|------|
| MovementBehavior | linear / homing / arc / orbit / stationary |
| HitBehavior | destroy / pierce / explode / chain / stick |
| LifetimeBehavior | timeout / distance / return / persistent |
| CollisionBehavior | enemy_only / world_only / all / bounce |

当前阶段用 `MovementType enum`，不拆子类。

---

## 后续方向

### 优先级 1: Status/Buff Runtime

- burning / frozen / poison / wet / shock / bleeding
- StatManager: apply / remove / tick / query
- 连接: 战斗 × 世界 × 表面 × AI

### 优先级 2: Surface Runtime 深化

- water / oil / fire / ice / poison / electric / smoke / blood
- 生命周期: spread / merge / extinguish / freeze / evaporate
- Surface Query: AI 避火 / 利用水面

### 优先级 3: Skill Augment System

- Split / Pierce / Explode / Chain / Homing
- 组合爆炸: Fireball + Pierce + Split

### 优先级 4: Enemy Combat Brain

- 威胁评估 / 技能选择 / 闪避 / 逃跑

---

## 反模式（禁止）

- ❌ 每个技能一个 Scene 文件
- ❌ 技能命名子类（FireballProjectile, IceProjectile）
- ❌ 不存在的实体也要 Scene
- ❌ 过早进入全组件化
- ❌ SkillData 持有复杂逻辑

## 与其他文档的关系

```
RUNTIME_TOPOLOGY.md
    │  五大 Runtime 边界、CommandBus 通信
    │
    ├── COMBAT_CONTRACTS.md
    │      CombatExecutor 唯一写入口、Modifier 管线、阶段机
    │      技能执行 = SkillExecutor → CombatExecutor → EventBus
    │
    ├── WORLD_CONTRACTS.md
    │      MapObject 接口、表面状态机、传播队列、WorldSpatialIndex
    │      投射物命中 = CombatExecutor.report_hit → WorldState 更新
    │
    └── skill_architecture.md (本文档)
          技能 = 数据组合（Archetype + Payload + Visual）
          Scene = 行为模型，不是技能身份
```

**关键连接点：**

| 本文档概念 | 对应 Runtime 契约 |
|-----------|------------------|
| `SkillExecutor._execute_projectile()` | COMBAT CONTRACT 1: 通过 CombatExecutor 发射 |
| `Projectile.setup()` | COMBAT CONTRACT 9: 伤害全链路唯一路径 |
| `archetype = "linear_projectile"` | RUNTIME TOPOLOGY: SimulationRuntime 统一 tick |
| `tags = ["fire"]` | COMBAT CONTRACT 8: 标签体系 → Modifier 匹配 |
| 表面交互（油+火） | WORLD CONTRACT 2: Surface 只声明状态 |
| AoE 命中多目标 | WORLD CONTRACT 3: 传播 BFS 队列 |

## 正模式（推荐）

- ✅ 新增技能 = 创建 .tres + 填配置
- ✅ Scene = 行为 Archetype
- ✅ SkillData 只是纯数据
- ✅ setup() 注入一切参数
- ✅ 30 分钟完成一个新技能
