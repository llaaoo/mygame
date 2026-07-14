# 技能系统架构设计文档

> 版本: v2.0 | 日期: 2026-07-14
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

## 当前架构 (v2.0)

### 文件结构（v2.5 更新）

> 旧路径: `res://skills/` → 新: `res://gameplay/abilities/`  
> 旧路径: `res://runtime/combat/skills/` → 新: `res://gameplay/abilities/` + `res://gameplay/combat/`

```
res://gameplay/abilities/
├── archetypes/                    # Runtime 行为模板（< 10 个）
│   ├── linear_projectile.tscn     # 直线投射物
│   └── persistent_aoe.tscn        # 持久范围效果
│
├── data/                          # SkillData .tres（200+ 个）
│   ├── fireball_data.tres
│   ├── shadow_bolt_data.tres
│   ├── synergies/                 # 跨法术联动配置
│   ├── trees/                     # 五系法术目录与精通节点
│   ├── upgrades/                  # 可复用强化方向
│   └── ...                        # 当前共 30 个法术
│
├── runtime/                       # 运行时
│   ├── skill_executor.gd          # _ARCHETYPE_SCENES 映射 + execute()
│   ├── projectile.gd              # setup(skill, caster, dir) 驱动
│   ├── skill_instance.gd          # 冷却包装
│   ├── skill_synergy_resolver.gd  # 状态条件与额外伤害联动
│   └── cast_context.gd
│
├── manager/
│   └── skill_manager.gd
│
├── registry/                      # SkillPool
├── loadout/                       # SkillLoadout
└── visuals/                       # 表现层 Resource

res://gameplay/combat/
├── combat_executor.gd             # 唯一控制流入口
├── combat_phase.gd                # 阶段锁
├── modifiers/                     # 伤害管线
├── conditions/                    # 条件判断
├── triggered_effect.gd
└── effect_graph/                  # 效果图
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

# 展示与精通树
@export var icon_atlas_index: int
@export var description: String
@export var mechanics: String
@export var school: SkillMastery.School
@export var tier: int
@export var role: String

# 投射物与持续范围行为
@export var projectile_count: int
@export var projectile_spread_degrees: float
@export var projectile_pierce: int
@export var homing_strength: float
@export var aoe_tick_interval: float
@export var aoe_max_hits_per_target: int

# 视觉（未来收敛为 ProjectileVisualData）
@export var projectile_color: Color
@export var projectile_scale: float
@export var projectile_texture: Texture2D
@export var aoe_color: Color
@export var aoe_radius: float
@export var aoe_lifetime: float

# 标签（Modifier 匹配）
@export var tags: Array[String]         # ["fire", "shadow", "aoe"]

# 局内强化（SkillUpgrade .tres）
@export var upgrades: Array[Resource]
@export var synergies: Array[Resource]
```

### 局内强化与运行时副本

每个 `SkillUpgrade` 仍是纯配置资源，包含强化 ID、分支、最大等级、前置条件、附加标签和 `modifiers` 字典。当前还支持多重投射、散射、贯穿、追踪、飞行时间、AoE 脉冲间隔和单目标命中次数，因此数量、穿透、追踪、频次可以和威力、效率等通用方向自由组合。

```gdscript
# gameplay/abilities/data/upgrades/power.tres
id = "power"
branch = "威力"
max_rank = 3
modifiers = {
    "damage.multiplier": 0.2,
    "visual_scale.multiplier": 0.05,
}
```

强化只应用到 `SkillInstance.data` 的深复制运行时变体。`SkillInstance.base_data` 始终指向原始 `.tres`，因此同一技能在不同槽位可以拥有不同构筑，且不会污染资源缓存或下一局。`SkillManager.serialize_skill_state()` 保存槽位、技能 ID 和强化等级，现有版本化存档会自动持久化并恢复该状态。

局内奖励由 `RunManager` 从当前已装备技能的可用强化动态生成，每个房间在仍有可选强化时至少提供一张强化卡。新增技能只需：

1. 创建 `<skill_id>_data.tres`，完整配置 archetype、visual、tags 和 upgrades。
2. 将 ID 加入 `Player.PLAYER_SKILL_IDS` 以注册到玩家技能池。
3. 将 ID 加入 `RunManager.SKILL_REWARD_IDS`；奖励名称、定位和机制说明直接从 `SkillData` 读取。
4. 将 ID 登记到对应 `trees/<school>_tree.tres`，并保证 `school`、`tier` 与目录一致。

### 五系法术目录（30）

| 学派 | 法术 |
|------|------|
| 毁灭（15） | 火球术、余烬齐射、日耀长枪、熔岩池、余烬球、烈焰风暴、闪电箭、雷鸣球、雷暴领域、静电新星、毒云、疫病穿刺、剧毒爆发、瘴气环、蓄力火球 |
| 召唤（3） | 召唤骷髅、召唤余烬精灵、召唤苔岩魔像 |
| 恢复（2） | 潮汐灵球、辉光圣盾 |
| 变化（7） | 寒霜枪、冰河之眼、冰霜护盾、冰风暴、冰爆、白灾暴雪、奥术突进 |
| 幻术（3） | 暗影弹、暗影步、相位闪现 |

技能树以学派精通等级解锁法术：T1/Lv.1、T2/Lv.5、T3/Lv.10、T4/Lv.20、T5/Lv.30。`SkillTreeUI` 同时展示法术图标、层级、解锁等级、精通经验和可购买节点；`SkillPoolUI` 允许浏览全部法术，但只允许装备已解锁法术。

### 状态联动

`SkillSynergyData` 是纯配置资源，由 `SkillSynergyResolver` 订阅 `CombatEventBus.ON_HIT` 后执行。额外伤害统一通过 `CombatExecutor.report_bonus_damage()`，状态消耗通过目标 `BuffManager`，不会绕过战斗权威入口。

当前内置联动：

- 融化：火焰命中冻结目标，造成额外伤害并消耗冻结。
- 蒸汽爆裂：冰或水命中燃烧目标，造成额外伤害并扑灭燃烧。
- 导电：闪电命中潮湿目标，造成额外伤害。
- 毒焰引爆：火焰命中中毒目标，造成高额额外伤害并消耗中毒。
- 腐影：暗影命中中毒目标，造成可重复触发的额外伤害。

### SkillExecutor._ARCHETYPE_SCENES

```gdscript
const _ARCHETYPE_SCENES := {
    "linear_projectile": "res://gameplay/abilities/archetypes/linear_projectile.tscn",
    "persistent_aoe":     "res://gameplay/abilities/archetypes/persistent_aoe.tscn",
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
