# 🏛️ 项目架构 — 六层边界与工程契约

> **状态**: v2.3  
> **最后更新**: 2026-05-24  
> **替换**: RUNTIME_TOPOLOGY.md (v1.0–v1.5)

---

## 定位

本文档是项目的**最高级架构文件**。定义六层边界的职责、依赖方向、禁止事项、以及当前状态和下一阶段优先级。

所有下层文档（COMBAT_CONTRACTS / WORLD_CONTRACTS / PHYSICS_LAYERS / skill_architecture）都受本文档约束。

---

## 一、六层边界 + 事件总线 + NPC 五层

### 全局事件总线

```
                      CombatEventBus (唯一事件流)
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
                  Quest     NPCBrain   TriggeredEffect
                (Condition  (AI决策)    (Buff/反应)
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
```

### NPC 五层架构（关键分层）

```
WorldTime (全局事实: 几点/白天黑夜)
    ↓
NPCBrain (决策: "现在该干什么" — 只读Schedule，不移动不播动画)
    ↓
Task (意图: "去铁匠铺工作" — MoveToTask/WanderTask/IdleTask)
    ↓
Action (行为: "怎么去" — MoveAction/UseAction/InteractAction)
    ↓
StateMachine (执行: 动画/移动/Tween — 禁止读WorldTime/选行为)
```

| 层 | 职责 | 禁止 |
|----|------|------|
| **WorldTime** | 全局时钟 0-24h | 不控制 NPC |
| **NPCBrain** | 读 Schedule → 选 Task | 不移动、不播动画、不攻击 |
| **Task** | 目标意图（MoveTo/Sleep/Work） | 不直接控制动画 |
| **Action** | 行为执行（Move/Use/Interact） | — |
| **StateMachine** | 动画/移动/Tween/死亡 | 禁止读 WorldTime/Quest/Schedule |

### Enemy vs NPC 根本区别

| | Enemy | NPC |
|------|------|------|
| 模式 | 反应式 AI | 生活式 AI |
| 驱动 | 玩家距离 | Schedule（时间） |
| 无玩家时 | 原地待机 | 持续执行日程 |
| 架构 | StateChart 直接驱动 | Schedule→Task→Action→FSM |

```
Enemy: Idle → Chase → Attack  (只对玩家反应)
NPC:   06:00 Wake → 08:00 Work → 18:00 Eat → 22:00 Sleep  (独立生活)
```

### 依赖方向（铁律）+ FSM 铁律

```
content  ← 被所有层引用（只读数据）
world    → entities（通过 WorldSpatialIndex 查询）
gameplay → entities（通过 CombatExecutor 修改）
core     ← 被所有层使用
ui       → 只读所有层
```

**禁止反向**。**禁止系统互相引用**。

**FSM 铁律**: FSM 永远不允许直接选行为、读 WorldTime、读 Quest、改 Schedule。FSM 只能执行动画/移动/Tween/受击/死亡。

### 最终收敛结构

```
World (Time + Quest + EventBus + Relationship + Crime)
    │
NPC (Brain + Schedule + Task + Action + FSM)
    │
Combat (Executor + Modifier + Event + EffectGraph)
    │
Action Layer (Move/Attack/Use/Interact/Cast — Player/NPC/Boss 统一)
```

---

## 二、核心层 (core/)

```
core/
├── state/
│   ├── state.gd
│   └── state_machine.gd
├── event/
│   └── combat_event.gd
├── game_runtime.gd
├── command_bus.gd
└── runtime_command.gd
```

---

## 三、玩法层 (gameplay/)

```
gameplay/
├── action/                          ← ✅ Action Layer (Player)
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
├── quest/                           ← ✅ Quest P1-P3
│   ├── data/
│   │   ├── quest_data.gd
│   │   ├── quest_stage.gd
│   │   └── objective.gd
│   ├── runtime/
│   │   ├── quest_runtime.gd
│   │   └── quest_manager.gd
│   ├── objectives/
│   │   ├── kill_objective.gd
│   │   └── interact_objective.gd
│   └── ui/
│       └── quest_tracker.gd
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
│   ├── enemy.gd               # StateChart (反应式AI)
└── pickups/
```

**Enemy**: godot_state_charts 驱动（Idle→Chase→Attack），反应式 AI。
**NPC**: Schedule → NPCBrain → Task → FSM 五层架构（生活式 AI）。

---

## 五、世界层 (world/)

```
world/
├── time/                       ← ✅ NPC Schedule P1
│   └── world_time.gd           # 全局 24h 时钟
├── markers/                    ← ✅ NPC Schedule P1
│   ├── world_marker.gd         # 地图锚点
│   └── marker_registry.gd      # marker_id → 位置
├── npcs/                       ← ✅ NPC Schedule P1
│   ├── npc_brain.gd            # 决策层
│   ├── npc_schedule.gd         # 日程 Resource
│   ├── schedule_entry.gd       # 日程条目 Resource
│   ├── move_to_task.gd         # 移动到 Marker
│   └── npc_villager.tscn       # 村民场景
├── object/                     ← WorldObject 体系
│   ├── map_object.gd / map_object_data.gd
│   ├── interactable.gd / signal_receiver.gd
│   ├── switch.gd / door.gd / chest.gd
│   ├── spike_trap.gd / pressure_plate.gd
│   ├── npc.gd (DialogueNPC) / dialogue_balloon.gd
│   ├── portal.gd
│   └── oil_barrel.tscn / breakable_wall.tscn / ...
├── maps/overworld.tscn
├── doors/ / switches/ / traps/ / loot/
└── world_runtime.gd / world_spatial_index.gd / world_state_manager.gd
```

---

## 六、内容层 (content/)

```
content/
├── items/   (player_inventory.tres, examples/)
├── visuals/ (fire_visual.tres, shadow_visual.tres...)
└── quests/  (kill_enemies_quest.tres)
```

---

## 七、当前状态 & 下一阶段优先级

| 状态 | 任务 | 说明 |
|:--:|------|------|
| ✅ | WorldObject 体系 | 7 种物体 + 交互框架 |
| ✅ | Action Layer (Player) | 5 state 统一走 poll_actions/try_action |
| ✅ | Enemy StateChart | godot_state_charts |
| ✅ | **Quest P1-P3** | Kill/Interact Objective + 多阶段 + QuestTracker |
| ✅ | **NPC Schedule P1** | WorldTime + Marker + Schedule + MoveToTask |
| 🔜 | Action Layer 统一 | Move/Use/Attack Action — Player/NPC/Boss 共享 |
| 🔜 | NPC Schedule P2 | WanderTask / SleepTask / WorkTask |
| 🔜 | Region System | 区域驱动世界 |
| ⚪ 不做 | 技能系统继续抽象 | 已经够了 |
| ⚪ 不做 | 行为树 / GOAP / Planner | 用 Schedule + Task 模式 |

---

## 八、停止线

**不要再扩展的方向**：
- 新技能类型 / Modifier / Condition / GraphNode
- AbilityNode / BehaviorTree / DSL / Quest Script / GOAP / Planner
- FSM 读 WorldTime / Quest / Schedule

**应该投入的方向**：
- Action Layer 统一（Player/NPC/Boss 共享 Action）
- NPC Schedule P2（Wander/Sleep/Work）
- Content Pipeline（设计师 2 小时配一个地牢 + 任务链 + NPC 日程）

---

## 九、工程判断标准

| 不是 | 而是 |
|------|------|
| 系统有多高级 | 能否低成本产出内容 |
| 功能多少 | NPC 是否持续生活而非玩家靠近才激活 |
| AI 复杂度 | WorldTime + Schedule 是否让世界"活起来" |

> **Runtime 是「怎么运行」，Content 是「有什么内容」。FSM 只执行，不决策。**