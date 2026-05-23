# 🏛️ 项目架构 — 六层边界与工程契约

> **状态**: v2.0 已固化  
> **最后更新**: 2026-05-23  
> **替换**: RUNTIME_TOPOLOGY.md (v1.0–v1.5)

---

## 定位

本文档是项目的**最高级架构文件**。定义六层边界的职责、依赖方向、禁止事项、以及下一阶段优先级。

所有下层文档（COMBAT_CONTRACTS / WORLD_CONTRACTS / PHYSICS_LAYERS / skill_architecture）都受本文档约束。

---

## 一、六层边界

```
                        PlayerInput
                             ↓
                     gameplay/action/
                     ActionExecutor
                     ↙    ↓    ↘
               combat   abilities   interaction
                     ↘    ↓    ↙
                     entities/
                     (Actor + Components)
                           ↓
                     world/
                     (Region → Objects → Surface)
                           ↓
                     content/
                     (纯 .tres，零运行时)

        ┌─────────┬─────────┬─────────┬─────────┬─────────┐
        ▼         ▼         ▼         ▼         ▼         ▼
      core    gameplay  entities   world    content     ui
```

| 层 | 职责 | 不允许知道 |
|----|------|-----------|
| **core** | 引擎基础设施（状态机、事件总线、命令总线、调试、标签、注册表） | gameplay / world |
| **gameplay** | 游戏规则（战斗、技能、状态、交互、背包、AI） | 地图 chunk、空间坐标 |
| **entities** | Actor + 组件（Player/Enemy/NPC + Health/Mana/Combat 组件） | 地图流式加载 |
| **world** | 空间系统（地图、区域、物体、传送门、表面、导航、空间索引） | modifier pipeline |
| **content** | 纯数据 .tres（技能数据、物品、状态预设、视觉预设、掉落表） | 任何运行时代码 |
| **ui** | HUD / 菜单 / 背包面板 / 技能栏 | 直接修改任何 Runtime 状态 |

### 依赖方向（铁律）

```
content  ← 被所有层引用（只读数据）
world    → entities（通过 WorldSpatialIndex 查询）
gameplay → entities（通过 CombatExecutor 修改）
core     ← 被所有层使用
ui       → 只读所有层
```

**禁止反向**：`gameplay` 不能依赖 `world`，`entities` 不能依赖 `content`。

---

## 二、核心层 (core/)

```
core/
├── event/                  # 事件系统
│   ├── combat_event.gd
│   ├── combat_event_bus.gd
│   └── combat_scope.gd
├── command/                # 跨 Runtime 命令总线
│   ├── command_bus.gd
│   └── runtime_command.gd
├── state/                  # 状态机
│   ├── state.gd
│   └── state_machine.gd
├── debug/                  # 调试工具
│   └── (CombatDebugger, CombatTrace, CombatDebugUI)
├── tags/                   # 标签系统
├── registry/               # 通用注册表
└── utils/                  # 工具函数
```

**core 是长期稳定的基础设施。不该频繁变更。**

---

## 三、玩法层 (gameplay/)

```
gameplay/
├── action/                 ← 下一阶段：统一行为入口
│   ├── action.gd
│   ├── action_executor.gd
│   ├── cast_skill_action.gd
│   ├── melee_attack_action.gd
│   ├── interact_action.gd
│   ├── use_item_action.gd
│   └── pickup_action.gd
│
├── combat/
│   ├── combat_executor.gd  # 唯一世界写入口
│   ├── combat_phase.gd
│   ├── triggered_effect.gd
│   ├── modifiers/
│   ├── conditions/
│   ├── on_hit/             # OnHitApplyStatus, OnHitFireBonus
│   ├── on_kill/            # OnKillBonusExp
│   └── on_armor/           # OnIceArmorExpire
│
├── abilities/
│   ├── archetypes/         # .tscn 行为模板
│   ├── runtime/            # SkillExecutor, Projectile, PersistentAOE
│   ├── visuals/            # VisualData .gd 类
│   ├── loadout/            # SkillLoadout
│   ├── registry/           # SkillPool
│   ├── manager/            # SkillManager
│   └── effect_graph/       # EffectGraph 节点
│
├── status/
│   ├── buff.gd
│   ├── buff_manager.gd
│   └── (burning.tres 等在 content/)
│
├── inventory/
│   ├── inventory.gd
│   ├── equipment_manager.gd
│   └── data/               # ItemData, EquipmentData (运行时类)
│
└── interaction/
    ├── surface_manager.gd
    ├── surface_reaction.gd
    ├── reaction_rule.gd
    ├── surface_scheduler.gd
    └── propagation_scheduler.gd
```

### Action Layer — 统一行为入口（下一阶段核心收敛）

**当前问题**：行为入口分裂——
- `Player → SkillExecutor`（技能）
- `Player → CombatComponent`（近战）
- `Player → InteractionSystem`（交互）

**收敛方向**：
```
PlayerInput → Action → ActionExecutor → Skill / Combat / Interaction
```

所有玩家行为统一走 Action，不直调子系统。

---

## 四、实体层 (entities/)

```
entities/
├── components/             # 共享组件
│   ├── health_component.gd
│   ├── combat_component.gd
│   ├── mana_component.gd
│   └── stats_component.gd
├── player/
│   ├── player.tscn
│   ├── player.gd
│   └── states/             # Idle/Move/Attack/Dodge/Skill
├── enemy/
│   ├── enemy.tscn
│   ├── enemy.gd
│   └── states/             # Idle/Chase/Attack
├── npc/
└── pickups/                # HealthPickup, ManaPickup
    ├── pickup.gd           # 基类
    └── health_pickup.gd
```

**坚持 Hybrid Component Architecture**，不纯 ECS。
Godot 不适合 pure ECS — 调试地狱、Inspector 消失、编辑器不可视。

---

## 五、世界层 (world/)

```
world/
├── maps/
│   └── overworld.tscn
├── regions/
│   └── burning_forest/
│       ├── burning_forest.tscn
│       ├── region_data.tres        ← 区域定义
│       ├── region_rules.tres       ← 区域规则
│       ├── spawn_table.tres        ← 敌人生成表
│       └── weather.tres            ← 天气（预留）
├── portals/
│   ├── portal.tscn
│   ├── portal.gd
│   └── portal_shape.tres
├── objects/                ← WorldObject 体系（最优先投资）
│   ├── world_object.gd           # 基类
│   ├── destructible_object.gd    # 可破坏物
│   ├── interactable_object.gd    # 可交互物
│   ├── switch_object.gd          # 开关
│   ├── door_object.gd            # 门
│   ├── loot_container.gd         # 容器/宝箱
│   ├── oil_barrel.tscn
│   ├── wooden_crate.tscn
│   ├── wooden_fence.tscn
│   └── ice_wall.tscn
├── surfaces/
├── navigation/
├── spatial/
│   ├── world_spatial_index.gd
│   └── world_state_manager.gd
└── generation/             # 关卡生成（预留）
```

### WorldObject 体系

**这是下一阶段最优先的投资方向。** 未来 70% 内容生产靠 WorldObject，不是技能系统。

所有可放置的世界物体继承 `world_object.gd`，统一接口：Damageable / Interactable / Persistent / Taggable。

### 区域驱动世界

每个 Region 是独立的 `.tscn` + `.tres` 包。非 open world，而是区域驱动（Skyrim / Elden Ring 模式）。

---

## 六、内容层 (content/)

```
content/
├── abilities/              # 技能数据 .tres（火球、冰甲、烈焰风暴…）
│   ├── fireball_data.tres
│   ├── ice_armor_data.tres
│   └── flame_storm_data.tres
├── items/                  # 物品数据 .tres
│   └── examples/
├── status/                 # 状态数据 .tres（burning, frozen, wet…）
│   ├── burning.tres
│   └── frozen.tres
├── enemies/                # 敌人数据 .tres（预设、掉落表）
├── loot/                   # 掉落表
├── regions/                # 区域数据（spawn_table, weather…）
├── surfaces/               # 表面数据
├── visuals/                # 视觉预设（颜色、粒子、大小）
│   ├── fire_visual.tres
│   ├── shadow_visual.tres
│   └── ice_aoe_visual.tres
└── dialogue/               # 对话数据（预留）
```

### Content vs Gameplay — 最关键边界

```
gameplay/abilities/runtime/   ← 「火球怎么飞」
content/abilities/             ← 「火球伤害多少、什么颜色」
```

**Content 是纯数据，零运行时代码。**
新增技能 = 新建 `content/abilities/xxx.tres`，不改 Runtime。

---

## 七、下一阶段优先级

| 优先级 | 任务 | 理由 |
|--------|------|------|
| 🔴 P0 | **WorldObject 体系** | 70% 内容生产靠它 |
| 🟡 P1 | **Action Layer 收敛** | 行为入口不能分裂 |
| 🟢 P2 | **Region System** | 区域驱动世界 |
| ⚪ 不做 | 技能系统继续抽象 | 已经够了（12 条契约 + Modifier + EffectGraph） |
| ⚪ 不做 | 纯 ECS | Godot 不适合 |

---

## 八、停止线

**不要再扩展的方向**：
- 新技能类型 / Modifier / Condition / GraphNode / 事件类型
- 新表面状态（现有 5 个已覆盖所有需求）
- AbilityNode / BehaviorTree / DSL（为了抽象而抽象）

**应该投入的方向**：
- WorldObject 基类 + 子类体系
- Action Layer 行为入口统一
- Region 数据驱动（spawn_table, region_rules）
- 内容验证场景（完整地牢 / 城镇 / 野外区域）

---

## 九、与下层文档的关系

```
ARCHITECTURE.md (本文档 — 最高级)
    │
    ├──► COMBAT_CONTRACTS.md (CombatRuntime 内部 12 条契约)
    ├──► WORLD_CONTRACTS.md  (WorldRuntime 内部 9 条契约)
    ├──► PHYSICS_LAYERS.md   (11 层物理标准)
    └──► skill_architecture.md (技能内容生产方式)
```

- ARCHITECTURE.md 定义**层之间**的边界
- COMBAT/WORLD CONTRACTS 定义**层内部**的规则
- PHYSICS_LAYERS 定义碰撞层分配
- skill_architecture.md 定义内容生产方式

---

## 十、工程判断标准

| 不是 | 而是 |
|------|------|
| 系统有多高级 | 能否低成本产出内容 |
| 功能多少 | 三个验证场景是否通过 |
| Modifier 数量 | 设计师能否 2 小时配一个地牢 |

> **Runtime 是「怎么运行」，Content 是「有什么内容」。只要这条边界不混，项目后期就不会崩。**
