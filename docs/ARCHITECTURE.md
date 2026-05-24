# 🏛️ 项目架构 — 六层边界与工程契约

> **状态**: v2.2  
> **最后更新**: 2026-05-24  
> **替换**: RUNTIME_TOPOLOGY.md (v1.0–v1.5)

---

## 定位

本文档是项目的**最高级架构文件**。定义六层边界的职责、依赖方向、禁止事项、以及当前状态和下一阶段优先级。

所有下层文档（COMBAT_CONTRACTS / WORLD_CONTRACTS / PHYSICS_LAYERS / skill_architecture）都受本文档约束。

---

## 一、六层边界 + 事件总线

```
                      CombatEventBus (唯一事件流)
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
                  Quest     NPCBrain   TriggeredEffect
                (Condition  (AI状态)    (Buff/反应)
                 +Counter)
                     │          │          │
                     └──────────┼──────────┘
                                │
                        PlayerInput
                             ↓
                     gameplay/action/
                     PlayerAction (纯数据)
                     poll_actions() → try_action()
                     ↙    ↓    ↘
               MELEE  CAST  INTERACT/DODGE
                     ↘    ↓    ↙
                     entities/
                     StateMachine (行为执行)
                           ↓
                     world/
                     (MapObject → 交互 → Loot/信号)
                           ↓
                     content/
                     (纯 .tres，零运行时)

        ┌─────────┬─────────┬─────────┬─────────┬─────────┐
        ▼         ▼         ▼         ▼         ▼         ▼
      core    gameplay  entities   world    content     ui
```

| 层 | 职责 | 已实现 |
|----|------|--------|
| **core** | 引擎基础设施（状态机、事件总线、命令总线） | StateMachine, CombatEventBus, CombatExecutor, CommandBus |
| **gameplay** | 游戏规则（Action、战斗、技能、状态、交互、背包、任务） | Action Layer, 6种技能, Modifier管线, Buff系统, 交互框架, Quest系统(设计中) |
| **entities** | Actor + 组件（Player/Enemy/NPC + 组件） | Player(5状态), Enemy(StateChart), NPC(DialogueBalloon), 4个组件 |
| **world** | 空间系统（地图、物体、传送门、表面、空间索引） | 7种WorldObject, 表面系统, 空间索引, 传送门 |
| **content** | 纯数据 .tres（技能数据、物品、状态预设、视觉预设、任务配置） | 技能.tres, 物品.tres, 状态.tres, 视觉.tres, 任务.tres(规划中) |
| **ui** | HUD / 菜单 / 背包面板 / 技能栏 / 对话气球 / 任务追踪 | HUD, InventoryPanel, SkillBar, DialogueBalloon, QuestTracker(规划中) |

### 核心原则：事件驱动统一

```
World Event → EventBus → Quest / NPCBrain / TriggeredEffect
```

三套系统监听同一事件流。Quest 本质是 "Condition + Counter" 的 Triggered System。
QuestManager 极小 — 只做 `for quest in active: quest.on_event(ev)`，不认识任务类型。

### 依赖方向（铁律）

```
content  ← 被所有层引用（只读数据）
world    → entities（通过 WorldSpatialIndex 查询）
gameplay → entities（通过 CombatExecutor 修改）
core     ← 被所有层使用
ui       → 只读所有层
```

**禁止反向**。**禁止系统互相引用**（Quest ↔ Dialogue 通过 EventBus 通信，不直调）。

---

## 二、核心层 (core/)

```
core/
├── state/
│   ├── state.gd
│   └── state_machine.gd
├── game_runtime.gd
├── command_bus.gd
└── runtime_command.gd
```

---

## 三、玩法层 (gameplay/)

```
gameplay/
├── action/                          ← ✅ Action Layer
│   └── player_action.gd
│
├── abilities/                       ← 技能系统
│   ├── archetypes/
│   ├── data/
│   ├── manager/
│   ├── registry/
│   ├── runtime/
│   ├── modifiers/
│   ├── conditions/
│   └── triggered_effect.gd
│
├── quest/                           ← 🔜 Quest 系统
│   ├── data/
│   │   ├── quest_data.gd
│   │   ├── quest_stage.gd
│   │   ├── objective.gd
│   │   └── reward.gd
│   ├── runtime/
│   │   ├── quest_runtime.gd
│   │   ├── objective_runtime.gd
│   │   └── quest_manager.gd
│   ├── objectives/
│   │   ├── kill_objective.gd
│   │   ├── interact_objective.gd
│   │   └── reach_region_objective.gd
│   ├── rewards/
│   │   ├── give_item_reward.gd
│   │   └── open_door_reward.gd
│   └── ui/
│       ├── quest_tracker.gd
│       └── quest_journal.gd
│
├── status/
│   ├── buff.gd
│   └── buff_manager.gd
│
├── inventory/
│   ├── inventory.gd
│   └── equipment_manager.gd
│
└── interaction/
    ├── simulation_runtime.gd
    ├── surface_manager.gd
    ├── surface_reaction.gd
    └── propagation_scheduler.gd
```

### Quest 系统 — 设计中

**核心约束**：
- QuestManager 极小 — 只做 `for q in active: q.on_event(ev)`
- Objective 不用 enum，用类继承（KillObjective / InteractObjective）
- Reward 不用写死，用类继承（GiveItemReward / OpenDoorReward）
- Quest 与 Dialogue 不互相引用，通过 EventBus 通信
- Quest 配置全部用 .tres 纯数据，禁止 quest 脚本

**数据流**：
```
CombatEventBus.on_event(ev)
    → QuestManager._on_event(ev)
    → for quest in active_quests:
        quest.current_stage.objective.on_event(ev)
        if objective.completed:
            stage.complete → reward.apply() → next_stage
```

### Action Layer — ✅ 已实现

**数据流**：
```
Input.xxx() → poll_actions() → PlayerAction[] → try_action(action) → StateMachine
```

---

## 四、实体层 (entities/)

```
entities/
├── components/
│   ├── health_component.gd
│   ├── combat_component.gd
│   ├── mana_component.gd
│   └── stats_component.gd
├── player/
│   ├── player.tscn
│   ├── player.gd
│   └── states/
├── enemy/
│   ├── enemy.tscn
│   ├── enemy.gd
└── pickups/
```

**Enemy 状态机**：已迁移到 godot_state_charts（StateChart → CompoundState "Brain" → AtomicState Idle/Chase/Attack）。

---

## 五、世界层 (world/)

已有 7 种 WorldObject（OilBarrel / Door / Switch / Chest / SpikeTrap / PressurePlate / NPC）+ BreakableWall。详见 [WORLD_CONTRACTS.md](./WORLD_CONTRACTS.md)。

---

## 六、内容层 (content/)

```
content/
├── items/
│   ├── player_inventory.tres
│   └── examples/
├── visuals/
│   ├── fire_visual.tres
│   ├── shadow_visual.tres
│   └── ...
└── quests/                    ← 规划中
    ├── main/
    └── side/
```

### Content vs Gameplay — 最关键边界

```
gameplay/abilities/runtime/   ← 「火球怎么飞」
gameplay/quest/runtime/        ← 「任务怎么推进」
content/visuals/               ← 「火球什么颜色」
content/quests/                ← 「任务目标是什么」
```

---

## 七、当前状态 & 下一阶段优先级

| 状态 | 任务 | 说明 |
|:--:|------|------|
| ✅ | WorldObject 体系 | 7 种物体 + 交互框架 |
| ✅ | Action Layer 收敛 | 5 state 统一走 poll_actions/try_action |
| ✅ | Enemy StateChart 迁移 | godot_state_charts |
| 🔜 | **Quest 系统 P1** | QuestData + QuestRuntime + Kill/Interact Objective |
| 🔜 | Region System | 区域驱动世界 |
| 🔜 | Quest 系统 P2 | Reward + Quest UI + 地图标记 |
| ⚪ 不做 | 技能系统继续抽象 | 已经够了 |
| ⚪ 不做 | Quest Script DSL | 用 .tres 纯数据 |

---

## 八、停止线

**不要再扩展的方向**：
- 新技能类型 / Modifier / Condition / GraphNode
- AbilityNode / BehaviorTree / DSL / Quest Script
- Quest ↔ Dialogue 互相引用

**应该投入的方向**：
- Quest 系统 P1（纯数据驱动任务）
- 用现有积木搭可玩关卡
- Content Pipeline（设计师 2 小时配一个地牢 + 任务链）

---

## 九、工程判断标准

| 不是 | 而是 |
|------|------|
| 系统有多高级 | 能否低成本产出内容 |
| 功能多少 | 三个验证场景是否通过 |
| 任务类型枚举多少 | 一个 .tres 配一个任务够不够快 |

> **Runtime 是「怎么运行」，Content 是「有什么内容」。Quest 不是脚本，是数据。**