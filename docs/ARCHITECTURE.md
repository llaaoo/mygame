# 🏛️ 项目架构 — 六层边界与工程契约

> **状态**: v2.1 进行中  
> **最后更新**: 2026-05-24  
> **替换**: RUNTIME_TOPOLOGY.md (v1.0–v1.5)

---

## 定位

本文档是项目的**最高级架构文件**。定义六层边界的职责、依赖方向、禁止事项、以及当前状态和下一阶段优先级。

所有下层文档（COMBAT_CONTRACTS / WORLD_CONTRACTS / PHYSICS_LAYERS / skill_architecture）都受本文档约束。

---

## 一、六层边界

```
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
| **gameplay** | 游戏规则（Action、战斗、技能、状态、交互、背包） | Action Layer, 6种技能, Modifier管线, Buff系统, 交互框架 |
| **entities** | Actor + 组件（Player/Enemy/NPC + 组件） | Player(5状态), Enemy(3种), NPC, 4个组件 |
| **world** | 空间系统（地图、物体、传送门、表面、空间索引） | 7种WorldObject, 表面系统, 空间索引, 传送门 |
| **content** | 纯数据 .tres（技能数据、物品、状态预设、视觉预设） | 技能.tres, 物品.tres, 状态.tres, 视觉.tres |
| **ui** | HUD / 菜单 / 背包面板 / 技能栏 / 对话气球 | HUD, InventoryPanel, SkillBar, DialogueBalloon |

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
│   └── player_action.gd             # 6 种 Type (纯数据 RefCounted)
│
├── abilities/                       ← 技能系统
│   ├── archetypes/
│   ├── data/                        # SkillData + .tres
│   ├── manager/
│   ├── registry/                    # SkillPool
│   ├── runtime/                     # SkillExecutor, Projectile, PersistentAOE
│   ├── modifiers/                   # FLAT→MULTIPLY→OVERRIDE→FINAL
│   ├── conditions/
│   └── triggered_effect.gd
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

### Action Layer — ✅ 已实现

**数据流**：
```
Input.xxx() → poll_actions() → PlayerAction[] → try_action(action) → StateMachine
```

- `PlayerAction`：6 种 Type（MOVE / MELEE / CAST_PRESS / CAST_RELEASE / DODGE / INTERACT）
- `poll_actions()`：每帧从 Input 生成 Action 数组（纯函数，无副作用）
- `try_action()`：验证 + 路由到 StateMachine
- 5 个 state（idle/move/attack/skill/dodge）统一调用 `entity.poll_actions()`

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
│   ├── player.gd              # Action Layer + 交互 + 瞄准
│   └── states/                # Idle/Move/Attack/Dodge/Skill
├── enemy/
│   ├── enemy.tscn
│   ├── enemy.gd
│   └── states/                # Idle/Chase/Attack
├── npc/
└── pickups/
    ├── pickup.gd
    ├── health_pickup.tscn
    └── mana_pickup.tscn
```

**坚持 Hybrid Component Architecture**，不纯 ECS。

---

## 五、世界层 (world/)

```
world/
├── maps/
│   └── overworld.tscn
├── object/                    ← WorldObject 体系 ✅
│   ├── map_object.gd          # 基类（Damageable/Persistent/Taggable）
│   ├── map_object_data.gd     # 纯数据 Resource
│   ├── interactable.gd        # 交互接口（Callback 模式）
│   ├── signal_receiver.gd     # 信号接收接口
│   ├── switch.gd              # 开关（Interactable → target.receive_signal）
│   ├── door.gd                # 门（MapObject + SignalReceiver）
│   ├── chest.gd               # 宝箱（MapObject + Interactable + LootTable）
│   ├── spike_trap.gd          # 地刺（Area2D, 周期性伤害）
│   ├── pressure_plate.gd      # 压力板（Area2D, body进入→信号）
│   ├── npc.gd                 # NPC（Interactable + DialogueBalloon）
│   ├── dialogue_balloon.gd    # 自定义对话气球
│   ├── npc_dialogue.gd        # 旧对话数据兼容
│   ├── portal.gd              # 传送门
│   ├── oil_barrel.tscn        # 油桶（爆炸+表面）
│   ├── wooden_crate.tscn      # 木箱
│   ├── breakable_wall.tscn    # 可破坏墙
│   └── breakable_wall_data.tres
├── doors/
│   ├── door.tscn
│   ├── door_data.tres
│   └── door_shape.tres
├── switches/
│   ├── switch.tscn
│   └── pressure_plate.tscn
├── traps/
│   ├── spike_trap.tscn
│   └── trap_shape.tres
├── loot/
│   ├── chest.tscn
│   ├── loot_table.gd
│   └── loot_entry.gd
├── npcs/
│   ├── npc_villager.tscn
│   └── villager_dialogue.tres
├── portal.tscn
├── world_runtime.gd
├── world_spatial_index.gd
└── world_state_manager.gd
```

### WorldObject 体系 ✅ 已实现

**7 种 WorldObject**：

| 类型 | 接口 | 说明 |
|------|------|------|
| OilBarrel | MapObject | 破坏连锁爆炸 + 表面生成 |
| Door | MapObject + SignalReceiver | 开关驱动，可破坏 |
| Switch | Interactable | 按E → 自动扫描兄弟节点发信号 |
| Chest | MapObject + Interactable + LootTable | 按E → 随机掉落 |
| SpikeTrap | Area2D | 进入后周期性伤害 |
| PressurePlate | Area2D | body进入/离开 → 自动信号 |
| NPC | Interactable + DialogueBalloon | 按E → 对话气球 |
| BreakableWall | MapObject | 纯碰撞阻挡，可破坏 |

**交互框架**：
- `Interactable`：`set_callback(cb)` 模式（Godot 4 不支持 `obj.method = callable`）
- `SignalReceiver`：`receive_signal(signal_id)` — Switch/PressurePlate 驱动 Door
- 玩家按 E → `poll_actions()` 生成 INTERACT → `try_action()` → `_try_interact()` 扫描最近 Interactable

---

## 六、内容层 (content/)

```
content/
├── items/
│   ├── player_inventory.tres
│   └── examples/              # iron_helmet, leather_armor, iron_boots
└── visuals/
    ├── fire_visual.tres
    ├── fire_aoe_visual.tres
    ├── shadow_visual.tres
    ├── ice_aoe_visual.tres
    ├── projectile_visual_data.gd
    └── aoe_visual_data.gd
```

### Content vs Gameplay — 最关键边界

```
gameplay/abilities/runtime/   ← 「火球怎么飞」
content/visuals/               ← 「火球什么颜色」
content/items/                 ← 「物品什么属性」
```

**Content 是纯数据，零运行时代码。**

---

## 七、UI 层 (ui/)

```
ui/
├── hud.tscn
├── hud.gd
├── inventory_panel.tscn
└── (SkillBar, SkillPoolUI, DialogueBalloon 由代码构建)
```

---

## 八、当前状态 & 下一阶段优先级

| 状态 | 任务 | 说明 |
|:--:|------|------|
| ✅ | **WorldObject 体系** | 7 种物体 + 交互框架 + 对话气球 |
| ✅ | **Action Layer 收敛** | 5 state 统一走 poll_actions/try_action |
| ✅ | **v2.0 目录迁移** | 六层目录对应关系已部署 |
| 🔜 | **Region System** | 区域驱动世界（dungeon 关卡） |
| 🔜 | **Loot Pipeline** | 掉落表 → 物品实例化链路 |
| 🔜 | **Content Pipeline** | 快速量产 dungeon/野外/Boss 内容 |
| ⚪ 不做 | 技能系统继续抽象 | 已经够了 |
| ⚪ 不做 | 纯 ECS | Godot 不适合 |

---

## 九、停止线

**不要再扩展的方向**：
- 新技能类型 / Modifier / Condition / GraphNode / 事件类型
- 新表面状态（现有 5 个已覆盖所有需求）
- AbilityNode / BehaviorTree / DSL（为了抽象而抽象）

**应该投入的方向**：
- 用现有积木搭可玩关卡（dungeon / 野外 / Boss 房）
- Loot Pipeline（掉落表 → 物品实例化 → 背包）
- Content Pipeline（设计师 2 小时配一个地牢）

---

## 十、与下层文档的关系

```
ARCHITECTURE.md (本文档 — 最高级)
    │
    ├──► COMBAT_CONTRACTS.md (CombatRuntime 内部 12 条契约)
    ├──► WORLD_CONTRACTS.md  (WorldRuntime 内部 9 条契约)
    ├──► PHYSICS_LAYERS.md   (11 层物理标准)
    └──► skill_architecture.md (技能内容生产方式)
```

---

## 十一、工程判断标准

| 不是 | 而是 |
|------|------|
| 系统有多高级 | 能否低成本产出内容 |
| 功能多少 | 三个验证场景是否通过 |
| Modifier 数量 | 设计师能否 2 小时配一个地牢 |

> **Runtime 是「怎么运行」，Content 是「有什么内容」。只要这条边界不混，项目后期就不会崩。**
