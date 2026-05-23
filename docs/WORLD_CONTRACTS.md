# 🌍 World Contracts — 世界模拟运行时契约

> **状态**: 已固化  
> **版本**: 1.6  
> **最后更新**: 2026-05-24  
> **适用范围**: `res://world/` `res://entities/components/`

---

## 🏛️ 架构定位

世界系统是一个 **可持续运行的世界模拟内核**。它不是「大场景 + 一些可破坏物」，而是战斗系统的**空间化延伸**。

**与 Combat Contracts 的关系**: 本契约是 COMBAT_CONTRACTS.md 的平行文档。两条契约体系通过以下共享基础设施正交：

```
        ┌──────────────┐
        │ CombatExecutor│  ← 唯一 HP 修改入口
        └──────┬───────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
 角色 HP    地图 HP    技能伤害
(HealthComp) (MapObject) (Modifier管线)
               │
        ┌──────┴───────┐
        │WorldSpatialIndex│ ← 统一空间查询
        └──────────────┘
```

---

## CONTRACT 0: MapObject 不是角色

### MapObject 允许的四个接口

| 接口 | 职责 | 已实现 |
|------|------|--------|
| `Damageable` | 有 HP，可被 CombatExecutor 修改 | OilBarrel, BreakableWall, Door, Chest, WoodenCrate, WoodenFence |
| `Interactable` | 可按 E 键触发（非战斗交互） | Switch, Chest, NPC |
| `Persistent` | 状态需持久化（WorldStateManager 管理） | Door, Chest |
| `Taggable` | 有 `tags` 数组，参与 InteractionSystem | 所有 MapObject |

### 已实现的 WorldObject 类型（7 种）

| 类型 | 基类 | 特有接口 |
|------|------|---------|
| OilBarrel | MapObject | 破坏AOE + 表面生成 |
| BreakableWall | MapObject | 纯碰撞阻挡 |
| Door | MapObject + SignalReceiver | 开关驱动，可破坏 |
| Chest | MapObject + Interactable | LootTable 随机掉落 |
| Switch | Node2D + Interactable | 按E → 扫描兄弟节点发信号 |
| PressurePlate | Area2D | body进入/离开 → 自动信号 |
| SpikeTrap | Area2D | 周期性 CombatExecutor.report_hit |
| NPC | Node2D + Interactable | DialogueBalloon 对话 |

### ❌ 禁止添加

| 禁止接口 | 原因 |
|----------|------|
| `Buffable` | Buff 属于角色系统，MapObject 不需要属性修改 |
| `AI` | 世界物体不思考 |
| `AbilityUser` | 世界物体不释放技能 |
| `Inventory` | 宝箱的库存是 `Interactable` 的数据，不是世界物体自己的组件 |
| `StatsComponent` | 力量/敏捷/智力对木箱无意义 |
| `ManaComponent` | 世界物体不消耗法力 |

**原则**: MapObject 是**场景的一部分**，不是**角色的子类**。世界物体 ≠ 角色。

---

## CONTRACT 1: 只有 CombatExecutor 可修改 HP

### ✅ 合法

```gdscript
# MapObject 被技能命中
InteractionSystem.resolve(skill, map_object)
  → CombatExecutor.report_hit(source=skill, target=map_object, damage=...)
    → map_object.take_damage(amount)  # Damageable 接口
```

### ❌ 禁止

```gdscript
map_object.hp -= 10              # 禁止
map_object.take_damage(10)       # 绕过 Executor 禁止
surface_burning.apply_damage()   # 禁止：表面系统不产生伤害
propagation.recurse_damage()     # 禁止：传播不直接修改 HP
```

**规则**: MapObject 的 HP 修改路径 = 技能的 HP 修改路径 = 角色的 HP 修改路径。唯一一条链路。

---

## CONTRACT 2: 表面系统只产生状态变化，不产生伤害

### ✅ 合法

```gdscript
# SurfaceManager 的职责
var reaction = ReactionRule.match(current_state, skill.tags)
if reaction:
    cell.state = reaction.result_state   # "wet" → "frozen"
    cell.remaining = reaction.duration
    # 不修改任何 HP
```

### ❌ 禁止

```gdscript
# SurfaceManager 中绝对禁止
entity.take_damage(5)          # 禁止
CombatExecutor.report_hit()    # 禁止（除非通过 InteractionSystem）
ctx.final_damage += 10         # 禁止
```

### 伤害如何发生？

```
SurfaceManager: "这个格子现在是 burning"
         ↓
InteractionSystem._tick(): "站在 burning 上的物体会持续受火伤"
         ↓
CombatExecutor.report_hit(source=surface_burning, target=entity, damage=tick_damage)
```

**原则**: Surface 声明状态。InteractionSystem 解释状态 → 转化为伤害事件。谁声明、谁解释、谁执行，三者分离。

---

## CONTRACT 3: 传播必须队列化（BFS），禁止递归

### ❌ 禁止的递归模式

```gdscript
func propagate(source, depth):
    for target in find_nearby(source):
        apply_damage(target)
        propagate(target, depth + 1)  # 禁止！栈爆炸 / 不可控
```

### ✅ 正确的队列模式

```gdscript
# PropagationQueue
var _jobs: Array[PropagationJob]

func enqueue(source, target, depth, damage):
    if depth > MAX_DEPTH: return
    _jobs.append(PropagationJob.new(source, target, depth, damage))

func _process(delta):
    var processed = 0
    while _jobs.size() > 0 and processed < MAX_JOBS_PER_TICK:
        var job = _jobs.pop_front()
        _execute_job(job)
        processed += 1
```

### 防火墙

| 限制 | 值 | 说明 |
|------|-----|------|
| `MAX_PROPAGATION_DEPTH` | 4 | 最大传播代数 |
| `MAX_JOBS_PER_TICK` | 8 | 每帧最多处理的传播作业数 |
| `MAX_QUEUE_SIZE` | 64 | 队列最大容量（超出丢弃） |
| `PROPAGATION_DECAY` | 0.5 | 每代伤害衰减系数 |

**原则**: 传播是**世界模拟**，不是函数调用。必须可中断、可限速、可观察。

---

## CONTRACT 4: 表面系统用状态，不用元素枚举

### ❌ 禁止的元素表模式

```
fire + water = steam
steam + ice = ???
oil + fire + water = ???
...
```
指数爆炸，不可维护。

### ✅ 正确的状态迁移模式

**有限状态** (5 个)：
```
dry → burning  (火技能命中)
dry → wet      (水/冰技能命中)
dry → oiled    (油技能命中)
wet → frozen   (冰技能命中 wet)
oiled → burning (火技能命中 oiled)
burning → dry  (水技能命中 / 自然超时)
frozen → wet   (自然超时)
```

**ReactionRule (Resource)**：
```gdscript
required_state: String         # "wet" | "burning" | "frozen" | "oiled" | "dry"
required_tags: Array[String]   # ["fire"] | ["ice"] | ["lightning"]
result_state: String           # "burning" | "frozen" | "dry"
effect_spawn: PackedScene      # 可选：蒸汽云、冰碎片
duration: float                # 新状态的持续时间
```

**禁止无限制添加状态**。新增一个表面状态 = 完整重新审计所有 ReactionRule。当前 5 个状态已覆盖所有必要交互。

---

## CONTRACT 5: WorldSpatialIndex 是所有空间查询的唯一入口

### 层模型

```
                  世界系统层
              ┌─────────────────┐
              │WorldSpatialIndex │  ← 统一空间层（每个地图实例一个）
              └────────┬────────┘
                       │
    ┌──────┬──────┬────┼────┬──────┬──────┐
    ▼      ▼      ▼    │    ▼      ▼      ▼
  Combat AI    Prop.  │  Loot  Surf.  Portal
                       │
              所有系统空间查询都走 Index
```

### 接口

```gdscript
# WorldSpatialIndex (每个地图实例一个)
func query_radius(pos: Vector2, radius: float) -> Array[MapObject]
func query_cell(cell: Vector2i) -> Array[MapObject]
func query_tags(pos: Vector2, radius: float, tags: Array[String]) -> Array[MapObject]
func query_surface(cell: Vector2i) -> SurfaceData
func get_surface_cells_in_radius(pos: Vector2, radius: float) -> Array[Vector2i]
func register(obj: MapObject) -> void
func unregister(obj: MapObject) -> void
```

### ❌ 禁止

```gdscript
# 任何系统不得直接遍历场景树
for child in get_tree().get_nodes_in_group("map_object"):  # 禁止
get_overlapping_bodies()                                    # 禁止用于世界查询
distance_to() 遍历                                          # 禁止
```

**原则**: 空间查询是一种**基础设施**，不是每个系统各自实现的工具函数。

---

## CONTRACT 6: WorldState 是真实状态，SceneTree 是表现层

```
┌─────────────────────────────────────────────────┐
│              WorldStateManager                    │
│                                                   │
│  _object_states: Dictionary[String, ObjectState]  │
│  {                                                │
│    "crate_12": { state: DESTROYED, destroyed_at } │
│    "barrel_03": { state: RESPAWNING, until }      │
│    "ice_wall_01": { state: INTACT }               │
│  }                                                │
│                                                   │
│  这是真实状态。SceneTree 只是它的视觉表现。        │
└─────────────────────────────────────────────────┘
```

### 生命周期状态机

```
INTACT ──(HP≤0)──► DESTROYED ──(倒计时结束)──► RESPAWNING ──(重生)──► INTACT
                     │                            │
                     │ (respawn_time=-1)          │ 不可交互
                     ▼                            ▼
                 永久消失                     倒计时结束
                                             → INTACT
```

### 关键规则

- 进入 SubMap 时：WorldStateManager 数据**保留**，SceneTree 上的 MapObject **卸载**
- 回到 Overworld 时：从 WorldStateManager **恢复**所有持久状态，重建 SceneTree
- `respawn_time = 0`：切场景时重生（在 `_on_scene_loaded` 中恢复 INTACT）
- `respawn_time = -1`：永久消失（状态永不被清除）

---

## CONTRACT 7: 交互密度是设计资源

### ❌ 禁止

```
全地图均匀分布可交互物体
每平方米一个可破坏物
所有物体都有全套 ReactionRule
```

### ✅ 正确

三层交互密度：

| 密度等级 | 区域类型 | 物体密度 | 交互复杂度 |
|----------|---------|---------|-----------|
| **低** | 野外/过渡区 | 稀疏（草、零星木桶） | Tier A 标签匹配 |
| **中** | 城镇/营地 | 中等（摊贩、火把、水面） | Tier A + B 传播 |
| **高** | 地牢/机关区 | 密集（油桶阵列、导电水、冰墙） | Tier A + B + C 表面 |

**原则**: 不是「全世界可交互」。高密度交互是关卡设计的手工资源，必须由设计师**有意识地放置**。

---

## CONTRACT 8: 文件夹所有权

```
world/
  maps/
    overworld.tscn
  object/
    map_object.gd                 # MapObject 基类
    map_object_data.gd            # MapObjectData Resource
    interactable.gd               # Interactable 接口 (Callback模式)
    signal_receiver.gd            # SignalReceiver 接口
    switch.gd                     # 开关
    door.gd                       # 门 (MapObject + SignalReceiver)
    chest.gd                      # 宝箱 (MapObject + Interactable + LootTable)
    spike_trap.gd                 # 地刺
    pressure_plate.gd             # 压力板
    npc.gd                        # NPC + DialogueBalloon
    dialogue_balloon.gd           # 自定义对话气球
    portal.gd                     # 传送门
    npc_dialogue.gd               # 旧对话兼容
  doors/
  switches/
  traps/
  loot/
    loot_table.gd                 # 掉落表 Resource
    loot_entry.gd                 # 掉落条目 Resource
  npcs/
  world_runtime.gd
  world_spatial_index.gd
  world_state_manager.gd

gameplay/
  action/
    player_action.gd              # Action Layer (6 Type)
  interaction/
    simulation_runtime.gd
    surface_manager.gd
    surface_reaction.gd
    propagation_scheduler.gd
```

### 依赖方向（单向）

```
world/object/        ──→  gameplay/ (CombatExecutor)
world/interaction/   ──→  gameplay/ (CombatExecutor)
world/               ──→  entities/ (Actor + Components)
world/               ──→  content/ (只读 .tres 数据)
``

---

## CONTRACT 9: 防火墙（硬限制）

| 防火墙 | 值 | 位置 |
|--------|-----|------|
| `MAX_PROPAGATION_DEPTH` | 4 | PropagationQueue |
| `MAX_JOBS_PER_TICK` | 8 | PropagationQueue |
| `MAX_QUEUE_SIZE` | 64 | PropagationQueue |
| `SURFACE_STATES` | 5 (dry/wet/burning/frozen/oiled) | SurfaceManager |
| `MAX_SURFACE_CELLS` | 256 | SurfaceManager |
| `SPATIAL_CELL_SIZE` | 64 | WorldSpatialIndex |
| `MAX_QUERY_RESULTS` | 32 | WorldSpatialIndex |

---

## 🔴 反模式速查

| 反模式 | 正确做法 |
|--------|---------|
| MapObject 挂 `StatsComponent` | MapObject 只有 4 个接口 (Damageable/Interactable/Persistent/Taggable) |
| MapObject 挂 `Buffable` | Buff 只属于角色，不属于世界物体 |
| `propagate()` 递归调用 | PropagationQueue BFS |
| SurfaceManager 直接 `take_damage()` | 声明状态 → InteractionSystem 解释 → CombatExecutor 执行 |
| 新增第 6 种表面状态 | 先审计所有 ReactionRule，再讨论是否真正必要 |
| `get_overlapping_bodies()` 查世界物体 | `WorldSpatialIndex.query_radius()` |
| SceneTree 遍历做距离检查 | 走 WorldSpatialIndex |
| 全地图均匀撒可交互物 | 三层密度分区 (低/中/高) |
| 元素组合表 `fire × water × oil` | 状态迁移 `wet + [fire] → dry` |

---

## 📐 扩展指南

### 新增可破坏物类型

```
1. 新建 MapObjectData .tres (tags, max_hp, respawn_time, blocks_path)
2. 创建可视化 .tscn (sprite + Body/StaticBody2D + HitArea/Area2D)
3. 挂载 map_object.gd 脚本
4. 放置在关卡中（手工放置，不要均匀撒）
```

### 新增交互物体（开关/按钮类）

```
1. 新建 Node2D .tscn + 挂载 switch.gd 或自定义脚本
2. 实现 Interactable 接口（set_callback 模式）
3. target 可为空 → 自动扫描兄弟节点找 SignalReceiver
```

### 新增 SignalReceiver（门/机关类）

```
1. 继承 MapObject 或 Node2D
2. 在 _ready() 中创建 SignalReceiver 子节点 + set_callback
3. 实现 _on_signal(signal_id) → 处理 "activate"/"deactivate"/"toggle"
```

### 新增 ReactionRule

```
1. 新建 ReactionRule .tres
2. 设 required_state / required_tags / result_state / duration
3. 加入 InteractionSystem 的 reactions 数组
```

### 新增表面状态（必须审计）

```
1. 确认当前 5 个状态无法覆盖需求
2. 写出新状态与现有 5 状态的完整迁移表
3. 审计所有 ReactionRule 是否有冲突
4. 更新 CONTRACT 9 的 SURFACE_STATES 值
5. 更新本契约
```

---

## 🤝 与 Combat Contracts 的桥接

```
WORLD_CONTRACTS                          COMBAT_CONTRACTS
─────────────────                        ─────────────────
CONTRACT 1 (HP 唯一入口)     ──共享──    CONTRACT 1 (CombatExecutor)
MapObject.Damageable         ──复用──    HealthComponent
InteractionSystem            ──委托──    CombatExecutor.report_hit()
PropagationQueue             ──委托──    CombatExecutor.report_hit()
WorldSpatialIndex            ──正交──    (不涉及)
SurfaceManager               ──正交──    (不涉及)
```

两个契约体系的唯一共享基础设施：**CombatExecutor**。其他所有系统正交。如果出现第三个共享点，需要重新审计。
