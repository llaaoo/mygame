# 🧠 Runtime Topology — 运行时拓扑与边界契约

> **状态**: 已固化  
> **版本**: 1.0  
> **最后更新**: 2025-07  
> **适用范围**: 整个项目运行时架构

---

## 定位

本文档是 **COMBAT_CONTRACTS.md** 和 **WORLD_CONTRACTS.md** 的上层宪法。

如果 Combat Contracts 是「战斗系统怎么做」，World Contracts 是「世界系统怎么做」，那么 Runtime Topology 回答的是：

> **「这些系统如何共存而不互相吞噬」**

---

## 一、五大 Runtime 边界

```
                         GameRuntime
                              │
        ┌──────────┬──────────┼──────────┬──────────┐
        ▼          ▼          ▼          ▼          ▼
    Combat      World     Simulation     UI        Save
    Runtime     Runtime    Runtime     Runtime    Runtime
```

### 1. CombatRuntime — 纯计算

| 属性 | 值 |
|------|-----|
| 职责 | 伤害计算、技能执行、Modifier 管线、事件发射、条件判定 |
| 输入 | `CastRequest` / `HitRequest` / `DamageRequest` |
| 输出 | `CombatResult` / `CombatEvent` |
| 状态 | `_phase`（阶段机）、`_cooldowns`、`_chain_count` |
| 禁止 | 地图逻辑、AI 行为、世界状态修改 |

**CombatRuntime 只做计算，不做世界控制。**

```
✅ CombatExecutor.report_hit(args) → DamageResult
❌ CombatExecutor 中调用 WorldStateManager
❌ CombatExecutor 中调用 SurfaceManager
```

### 2. WorldRuntime — 状态一致性

| 属性 | 值 |
|------|-----|
| 职责 | 维护 WorldState 一致性、MapObject 生命周期、SceneTree 同步 |
| 输入 | `DestroyedEvent` / `RespawnRequest` / `ChunkLoadRequest` |
| 输出 | `WorldStateDelta` |
| 状态 | `_object_states: Dictionary`（真实状态） |
| 禁止 | 伤害计算、AI 调度、技能逻辑 |

**WorldRuntime 的真实状态在 WorldStateManager 中。SceneTree 只是当前加载窗口的表现。**

```
✅ WorldStateManager.set_destroyed(id) → 更新字典 → 通知 SceneTree 更新 sprite
❌ SceneTree 上直接改 MapObject 的 HP
❌ 从 SceneTree 遍历获取世界状态
```

### 3. SimulationRuntime — 统一调度

| 属性 | 值 |
|------|-----|
| 职责 | 统一驱动所有持续世界行为 |
| 输入 | 时钟 tick |
| 输出 | 分派到各 Scheduler |
| 状态 | 调度队列 |

**内部 Scheduler：**

```
SimulationRuntime
├── SurfaceScheduler       # 表面状态倒计时 → 过期/传播
├── PropagationScheduler   # 传播队列处理（每帧 N 个 job）
├── RespawnScheduler       # 可破坏物重生倒计时
├── WeatherScheduler       # 天气变化（预留）
└── TimeScheduler          # 昼夜循环（预留）
```

**❌ 禁止每个系统自己 `_process()`：**

```gdscript
# 禁止
SurfaceManager._process(delta)     # 独立 tick
PropagationQueue._process(delta)   # 独立 tick
RespawnTimer._process(delta)       # 独立 tick
```

**✅ 统一调度：**

```gdscript
# SimulationRuntime._process(delta)
func _process(delta):
    _surface_scheduler.tick(delta)
    _propagation_scheduler.tick(delta)
    _respawn_scheduler.tick(delta)
    # 调度顺序显式、可审计、可暂停
```

### 4. UIRuntime — 表现

| 属性 | 值 |
|------|-----|
| 职责 | HUD、菜单、技能栏、背包、对话框 |
| 输入 | 用户输入 + Runtime 事件（只读） |
| 输出 | 无（不修改任何 Runtime 状态） |
| 禁止 | 直接修改 Combat/World/Simulation 状态 |

**UI 只观察，不控制。**

### 5. SaveRuntime — 持久化

| 属性 | 值 |
|------|-----|
| 职责 | 序列化/反序列化 WorldState + PlayerState + 进度 |
| 输入 | `SaveRequest` / `LoadRequest` |
| 输出 | 文件 I/O |
| 禁止 | 游戏逻辑 |

---

## 二、Runtime Message Contract（最关键）

### ❌ 禁止：Runtime 直接互相调用

```gdscript
# 禁止
SurfaceManager.spawn_fire()         # World 直接调 Simulation
PropagationQueue.trigger()          # World 直接调 Simulation
WorldStateManager.save()            # 任意系统直接调 Save
CombatExecutor.report_hit()         # World 直接调 Combat
CombatEventBus.emit()              # 任意系统直接调事件总线
```

### ✅ 正确：统一 CommandBus

```
System A
    │
    ▼
CommandBus.emit(RuntimeCommand)
    │
    ▼
System B._on_command(cmd)
```

**RuntimeCommand 类型：**

```gdscript
# RuntimeCommand (Resource)
type: String              # "HIT" / "DESTROYED" / "SURFACE_CHANGE" / "RESPAWN" / "CHUNK_LOAD"
source: String            # 发起 Runtime 名称
target: String            # 目标 Runtime 名称（或 "*" 广播）
payload: Dictionary       # 数据
```

### 具体流程示例：火球命中油桶

```
❌ 错误链（直接调用）:
Projectile → OilBarrel.explode() → Surface.spawn_fire() → Propagation.spread()

✅ 正确链（CommandBus）:
Projectile
  → CommandBus.emit(HIT_REQUEST {source: "combat", target: oil_barrel, damage: 25})
      │
      ├─► CombatRuntime.on_hit_request()
      │     → compute damage → report_hit → emit(DAMAGE_RESULT)
      │
      ├─► WorldRuntime.on_damage_result()
      │     → oil_barrel.take_damage() → HP=0 → emit(DESTROYED {id: "oil_barrel_03"})
      │
      └─► SimulationRuntime.on_destroyed()
            → enqueue surface change (oil → burning, radius=120)
            → enqueue propagation job (spread fire, depth=0)
```

### CommandBus 规则

| 规则 | 说明 |
|------|------|
| 谁产生事件，谁 emit | Projectile 产 HIT_REQUEST，WorldRuntime 产 DESTROYED |
| 谁处理，谁 subscribe | CombatRuntime 订阅 HIT_REQUEST，SimulationRuntime 订阅 DESTROYED |
| 不跨级调用 | WorldRuntime 不能直接调 CombatExecutor.report_hit() |
| 异步 | CommandBus 不保证同帧处理（队列化，类似 Propagation BFS） |

---

## 三、世界激活三级模型

```
┌────────────────────────────────────────────┐
│              Activation Levels               │
├────────────────────────────────────────────┤
│                                              │
│  ┌──────────┐    ┌──────────┐    ┌────────┐│
│  │ Loaded   │    │ Dormant  │    │Abstract││
│  │          │    │          │    │        ││
│  │ SceneTree│    │ 只有     │    │ 只有   ││
│  │ 完整存在  │    │ WorldState│   │ 统计   ││
│  │ 全模拟   │    │ 不渲染   │    │ 结果   ││
│  │          │    │          │    │        ││
│  │ 玩家 2   │    │ 玩家离开 │    │ 极远   ││
│  │ Chunk    │    │ 3分钟    │    │ 区域   ││
│  └──────────┘    └──────────┘    └────────┘│
│       │               │               │     │
│       ▼               ▼               ▼     │
│   实时 tick        定时 tick        事件驱动  │
│   (每帧)          (每 5 秒)       (仅在查询时)│
│                                              │
└────────────────────────────────────────────┘
```

### Loaded（玩家附近 2 Chunk 半径）

- SceneTree 完整存在
- 所有系统全 tick
- Surface 活跃、Propagation 活跃
- ~200 个 MapObject 上限

### Dormant（已访问但远离）

- SceneTree **已卸载**
- WorldStateManager 保留状态
- 只 tick：Respawn 倒计时（低频，每 5 秒）
- 不 tick：Surface、Propagation
- 玩家返回时：从 WorldState 重建 SceneTree

### Abstracted（未访问 / 极远）

- 完全不加载
- 不 tick
- 仅在查询时返回统计结果
- 例如：「北山贼营地」→ 3 天后被狼群摧毁 → 玩家到达时直接呈现最终结果

---

## 四、内容能力验证标准

系统架构的好坏不取决于它有多高级，而取决于：

> **「能否低成本地产出内容」**

### 三个验证场景

#### 场景 A：完整地牢

必须能在一个 SubMap 中完成：

- [ ] 入口 Portal（显式过渡）
- [ ] 3-5 场战斗（Enemy + 技能）
- [ ] 2 个机关（可破坏冰墙 + 导电水面）
- [ ] 1 个宝箱（Interactable + Loot）
- [ ] Boss（高 HP + 特殊技能）
- [ ] 可破坏场景物（木箱阵列 + 油桶链式反应）
- [ ] 表面交互（燃烧地面 + 冰面）
- [ ] 地图状态持久化（出地牢再进，破坏物保持）

**验证标准**：一个设计师能在 2 小时内配置完成，无需改代码。

#### 场景 B：完整城镇

必须能在一个 Overworld Chunk 中完成：

- [ ] 室内过渡（OverlayMap 或 SubMap）
- [ ] NPC（Dialog 暂不要求，但 Interactable 要支持）
- [ ] 门（状态切换：开/关）
- [ ] 商店（Interactable → 调用 UIRuntime）
- [ ] 世界状态（村民白天在集市，晚上在屋内 — 预留 SimulationRuntime 驱动）

**验证标准**：放置一个 NPC + 门 + 室内场景，只改 .tres 和 .tscn，不改 .gd。

#### 场景 C：完整野外区域

必须能在 Overworld 中完成：

- [ ] 2×2 Chunk 流式加载
- [ ] 交互热点区域（Tier A + B + C 全覆盖）
- [ ] 低密度过渡区（只有 Tier A）
- [ ] 环境传播（火蔓延到油桶链，玩家引爆一个炸一片）
- [ ] Chunk 卸载后返回 → Dormant 恢复正确

**验证标准**：在野外放 20 个可破坏物 + 3 个热点区域，运行稳定（无崩溃、无泄露、无状态不一致）。

---

## 五、当前进度与停止线

### 已完成 ✅

- CombatRuntime：核心计算链路完整（12 条契约）
- WorldRuntime 设计：9 条契约
- 三层地图模型设计
- MapObject 接口界定
- 表面状态机设计
- 传播队列设计

### 停止线 ⛔

**不要再做：**

- 新技能类型
- 新 Modifier
- 新 Condition
- 新 GraphNode
- 新事件类型
- 新表面状态（当前 5 个已足够）

**应该做：**

- 实现 WorldSpatialIndex（地基）
- 实现 MapObject 基类 + 生命周期
- 实现 CommandBus（Runtime 通信）
- 实现 SimulationRuntime 调度器
- 完成「场景 A：完整地牢」验证

### 工程判断标准

| 不是 | 而是 |
|------|------|
| 系统有多高级 | 能否低成本产出内容 |
| 功能多少 | 三个验证场景是否通过 |
| Modifier 数量 | 设计师能否 2 小时配一个地牢 |
| 元素种类 | 5 种状态是否已覆盖所有交互需求 |

---

## 六、文件结构（最终收敛版）

```
res://runtime/
├── game_runtime.gd              # 顶层 GameRuntime (Autoload)
├── command_bus.gd               # RuntimeCommand 总线 (Autoload)
├── runtime_command.gd           # RuntimeCommand Resource
│
├── combat/
│   └── (现有 res://systems/ + res://skills/ 迁移引用)
│
├── world/
│   ├── world_runtime.gd         # WorldRuntime 入口
│   ├── world_state_manager.gd   # 真实世界状态
│   ├── world_spatial_index.gd   # 统一空间查询
│   │
│   ├── map/
│   │   ├── map_base.gd
│   │   ├── overworld_map.gd
│   │   ├── sub_map.gd
│   │   └── overlay_map.gd
│   │
│   ├── chunk/
│   │   ├── map_chunk.gd
│   │   └── chunk_loader.gd
│   │
│   ├── object/
│   │   ├── map_object.gd        # 4 接口基类
│   │   └── map_object_data.gd
│   │
│   └── interaction/
│       ├── interaction_system.gd
│       ├── reaction_rule.gd
│       ├── propagation_queue.gd
│       ├── surface_manager.gd
│       └── surface_data.gd
│
├── simulation/
│   ├── simulation_runtime.gd    # 统一调度器
│   ├── surface_scheduler.gd
│   ├── propagation_scheduler.gd
│   ├── respawn_scheduler.gd
│   └── time_scheduler.gd        # 预留
│
├── ui/
│   └── ui_runtime.gd            # UI 协调器（预留）
│
└── save/
    └── save_runtime.gd          # 持久化（预留）
```

### 依赖方向（铁律）

```
simulation/  ──→  world/ (命令式)
world/       ──→  combat/ (通过 CommandBus)
combat/      ──→  (无依赖，纯计算)
ui/          ──→  (只读所有 Runtime)
save/        ──→  world/ + combat/ (只读状态)
```

**禁止反向**：`combat/` 不能依赖 `world/`，`world/` 不能依赖 `simulation/`。

---

## 🔴 反模式速查（运行时级别）

| 反模式 | 正确做法 |
|--------|---------|
| CombatExecutor 中调 WorldStateManager | Combat 只输出 DamageResult，World 订阅 |
| SurfaceManager 自己 `_process()` | SimulationRuntime 统一 tick |
| WorldRuntime 直接 `CombatExecutor.report_hit()` | 通过 CommandBus 发 HIT_REQUEST |
| SceneTree 遍历获取世界状态 | WorldStateManager 是真实状态源 |
| 所有 Chunk 全时模拟 | Loaded / Dormant / Abstracted 三级 |
| 每个系统独立 `_process()` | SimulationRuntime 统一调度 |
| 全地图均匀可交互 | 三层密度 + 交互热点 |
| 追求「全世界可交互」 | 追求「20 个高质量交互区域」 |
| Runtime 之间直接互相调用 | CommandBus 异步命令 |
| 新增表面状态或元素类型 | 用现有 5 状态覆盖，不够再讨论 |

---

## 🤝 与下级契约的关系

```
RUNTIME_TOPOLOGY.md (本文档)
    │
    ├──► COMBAT_CONTRACTS.md (CombatRuntime 内部契约)
    │
    └──► WORLD_CONTRACTS.md (WorldRuntime 内部契约)
```

- Runtime Topology 定义 **Runtime 之间** 的边界
- Combat/World Contracts 定义 **Runtime 内部** 的规则
- 任何跨 Runtime 调用 = 违反本文档 = 必须通过 CommandBus
