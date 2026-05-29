# 项目改进点清单

> 生成日期: 2026-05-24  
> 最后更新: 2026-05-30
> 范围: 排除 `addons/` 与 `godot_state_charts_examples/`  
> 目的: 记录当前项目结构、代码现状与 `docs/` 架构契约之间的差距，作为后续迭代输入。

---

## 完成进度

| 条目 | 状态 |
|------|:--:|
| P0.1 CombatExecutor HP 权威 | ✅ 已完成 |
| P0.2 CommandBus 领域路由 | ✅ 已完成 |
| P0.3 WorldState/Respawn 生命周期 | ✅ 已完成 |
| P1.1 SimulationRuntime 调度收敛 | ✅ 已完成 |
| P1.2 物理层核对 | ✅ 已完成 |
| P1.3 Action Layer 统一 | ✅ 已完成 |
| P1.4 文档路径同步 | 🔄 本文档已更新，其他文档仍需跟进 |
| P2.1 场景验证 | ✅ 三条冒烟链已完成，综合场景仍可扩展 |
| P2.2 README | ⬜ 根目录仍缺 README |
| P2.3 坏资源/孤儿文件清理 | ✅ 已完成 |

---

## 当前项目总体判断

项目已经具备较完整的 Godot 4.6 ARPG 原型骨架，核心目录分层清晰：

- `core/`: Runtime 根、命令总线、事件总线、状态机、调试追踪、存档。
- `gameplay/`: 技能、战斗、状态、背包、任务、交互模拟。
- `entities/`: 玩家、敌人、Boss、NPC、组件、拾取物。
- `world/`: 地图、世界物体、陷阱、机关、NPC 日程、空间索引、世界状态。
- `content/`: 技能视觉、Boss、物品、任务、召唤物、触发器等 `.tres` 内容数据。
- `ui/`: HUD、背包、升级、技能栏、技能池、Boss 血条、浮动伤害数字。
- `tests/` 和 `tools/`: 基础验证脚本与历史迁移/修复工具。

当前项目已经越过 P0 架构收敛阶段：`GameRuntime / CommandBus / WorldRuntime / SimulationRuntime / CombatExecutor` 均已进入真实调用链。`CombatExecutor.report_hit()` 已成为命中后事件与扣血入口；`MapObject` 销毁会通过 `world/destroyed` 命令进入 `WorldRuntime`，再转发 `simulation/surface_change` 与 `world/respawn_request`；`SimulationRuntime` 负责表面变化、AOE 伤害、重生队列与统一 tick。

当前主要问题已不再是“权威链路未闭合”，而是文档、测试和内容验证需要跟上代码：本文件、`PROJECT_ANALYSIS.md` 与 `INDEX.md` 已完成本次校准，其他契约文档后续仍需持续核对。

---

## 已完成的关键链路

### 1. 火球打爆油桶链路

当前链路：

1. 火系命中通过 `CombatExecutor.report_hit()` 写入 `_last_hit_tags`。
2. `MapObject._emit_destroyed_command()` 读取火系标签并发出 `RuntimeCommand.TYPE_DESTROYED`。
3. `WorldRuntime._on_destroyed_command()` 更新 `WorldStateManager`，并发出 `RuntimeCommand.TYPE_SURFACE_CHANGE`。
4. `SimulationRuntime._on_surface_change_command()` 生成表面、应用标签并处理 AOE 伤害。

代表文件：

- `gameplay/combat/combat_executor.gd`
- `world/object/map_object.gd`
- `world/world_runtime.gd`
- `gameplay/interaction/simulation_runtime.gd`

### 2. 陷阱伤害链路

当前链路：

1. `SpikeTrap.tick()` 由 `SimulationRuntime` 统一驱动。
2. 陷阱按 `player` / `enemy` group 查找目标，并用距离检测确认命中。
3. 命中通过 `CombatExecutor.report_hit()` 进入统一伤害入口。

代表文件：

- `world/object/spike_trap.gd`
- `gameplay/combat/combat_executor.gd`
- `gameplay/interaction/simulation_runtime.gd`

### 3. WorldState / Respawn 生命周期

当前链路：

1. `MapObject` 销毁时发出 `world/destroyed`。
2. `WorldRuntime` 更新 `WorldStateManager`。
3. 有 `respawn_time` 的对象会转发 `world/respawn_request` 到 `SimulationRuntime`。
4. `RespawnScheduler` 到期后恢复状态，当前加载对象通过 `restore_state()` 恢复表现和碰撞。

代表文件：

- `world/object/map_object.gd`
- `world/world_runtime.gd`
- `world/state/world_state_manager.gd`
- `gameplay/interaction/respawn_scheduler.gd`

---

## 与架构契约仍存在的差异

### 1. 文档状态落后于代码

现状：

- `docs/PROJECT_ANALYSIS.md` 已校准为 P0 Runtime 主链完成后的状态。
- `docs/INDEX.md` 已修正日期和版本，并纳入 `PROJECT_IMPROVEMENTS.md`。
- 其他契约文档仍需要在后续维护中继续核对“当前结构”和“目标结构”的边界。

影响：

- 新人或后续维护者会难以判断哪些是当前事实，哪些是历史债务。
- 旧结论可能误导后续实现，把已经完成的 P0 链路重复设计一遍。

### 2. SimulationRuntime 仍有合理例外和少量分散点

已完成：

- `SurfaceScheduler`、`PropagationScheduler`、`RespawnScheduler` 由 `SimulationRuntime.tick()` 驱动。
- `HealthComponent`、`ManaComponent`、`BuffManager`、`SkillManager`、`DialogueNPC`、`SpikeTrap` 等已注册到 `SimulationRuntime`。
- `SimulationRuntime.setup_dependencies()` 已向 `WorldSpatialIndex` 注入 `SurfaceManager`。

仍需明确：

- `Player._process()` 仍负责瞄准、蓄力、引导和输入相关状态，这更像 Player 本地控制例外，应在文档里标注为合理例外。
- `Projectile._physics_process()` 和 `SummonEntity._physics_process()` 仍由 Godot 物理循环驱动，属于移动/碰撞物理例外。
- `world/regions/burning_forest/burning_forest.gd` 仍有区域级 `_process()` 输入处理，后续可迁移到输入/区域 Runtime。

### 3. Action Layer 仍保留迁移期兼容层

已完成：

- Player 和 Enemy 均已有通用 `Action` / `ActionResolver` 路径。
- Enemy StateChart 已改为“状态感知 + 产生/执行 Action”的结构。

仍需明确：

- `gameplay/action/player_action.gd` 和 `Player.poll_actions()/try_action()` 仍作为旧兼容 API 存在。
- NPC 日程仍偏 Task 驱动，尚未完全统一到 Action 执行链。

### 4. 内容验证仍可扩展

已完成的三条冒烟验证：

- 火球打爆油桶 -> 表面生成/燃烧反应。
- 玩家踩陷阱 -> 通过 `CombatExecutor.report_hit()` 扣血。
- 可重生 MapObject -> `WorldState` / `RespawnScheduler` 闭环。

仍可补充：

- 小型地牢：门、开关、地刺、宝箱、油桶、surface、propagation、quest 联动。
- 村庄：NPC Schedule、Marker、Dialogue、Quest、Interact 协同。
- 野外热点：可破坏物阵列、油桶连锁、区域切换后状态恢复。

### 5. README 仍缺失

根目录当前没有 `README.md`。建议补一份面向开发者和设计者的入口文档，包含运行方式、目录结构、文档导航、测试方式和当前已验证链路。

---

## P0 改进点：权威链路收敛

### P0.1 CombatExecutor HP 权威

状态：✅ 已完成。

当前事实：

- `CombatExecutor.report_hit()` 负责事件发射与扣血。
- `CombatExecutor._apply_damage()` 是内部扣血入口。
- `HealthComponent.take_damage()`、`MapObject.take_damage()` 等保留为 Damageable 接收端接口。
- 陷阱、投射物、近战、AOE、DOT 等命中源应只调用 `CombatExecutor.report_hit()`。

后续维护要求：

- 新增命中源时不得在 `report_hit()` 后再次直接调用 `take_damage()`。
- `rg "take_damage\\("` 结果中，接收端实现和 `CombatExecutor` 内部调用是允许项；命中源裸调需要审查。

### P0.2 CommandBus 领域路由

状态：✅ 已完成。

当前事实：

- `RuntimeCommand` 已定义 `world/destroyed`、`simulation/surface_change`、`world/respawn_request`。
- `CommandBus.subscribe_for_target()` 已支持 target 订阅。
- `CommandBus._dispatch_one()` 已按订阅 target 过滤。
- `MapObject -> WorldRuntime -> SimulationRuntime` 的销毁/表面/重生链路已经走 CommandBus。

后续维护要求：

- 新增跨 Runtime 调用时优先定义 domain-prefixed command type。
- 不要把 `CommandBus` 退化成无 target 语义的全局事件总线。

### P0.3 WorldState / Respawn 生命周期

状态：✅ 已完成。

当前事实：

- `MapObject._emit_destroyed_command()` 会携带 `object_id`、`state_data`、位置、重生时间和破坏效果数据。
- `WorldRuntime` 更新 `WorldStateManager` 并转发重生请求。
- `SimulationRuntime` 接收重生请求并加入 `RespawnScheduler`。
- MapObject 恢复时会调用 `_restore_collision()` 恢复 Body / HitArea 碰撞。

后续维护要求：

- `respawn_time = -1 / 0 / >0` 的语义需要在内容制作规范里保持稳定。
- 区域/Chunk 加载恢复仍需在更完整的地图生命周期里继续验证。

---

## P1 改进点：架构收敛

### P1.1 SimulationRuntime 调度收敛

状态：✅ 主体已完成。

保留改进：

- 在文档中明确 Player 输入、Projectile 物理、SummonEntity 物理是例外路径。
- 区域级输入处理后续迁移出区域 `_process()`。
- 为统一调度补充一份“谁由 SimulationRuntime tick，谁由 Godot 物理循环驱动”的清单。

### P1.2 物理层核对

状态：✅ 已完成。

保留改进：

- 后续新增场景物、陷阱、投射物、拾取物时继续以 `PHYSICS_LAYERS.md` 为准。
- 可以增加 `.tscn` 碰撞层扫描脚本作为回归检查。

### P1.3 Action Layer 统一

状态：✅ 主体已完成。

保留改进：

- 将 `PlayerAction` 明确标记为迁移期兼容层。
- NPC Task 与 Action 的关系需要在 `ARCHITECTURE.md` 或 NPC 文档中补充说明。

### P1.4 文档路径同步

状态：🔄 进行中。

本次已修复：

- `PROJECT_IMPROVEMENTS.md` 已更新为当前真实状态。

仍需修复：

- `PROJECT_ANALYSIS.md` 已删除旧的 P0 未完成结论。
- `INDEX.md` 已修正日期、版本，并加入 `PROJECT_IMPROVEMENTS.md`。
- 其他契约文档如有旧路径，应继续区分“当前结构”和“目标结构”。

---

## P2 改进点：内容验证与工程卫生

### P2.1 场景验证

状态：✅ 三条关键冒烟链已完成。

后续建议：

- 把火球油桶、陷阱伤害、MapObject 重生整理成固定手测清单。
- 有 Godot CLI 后，将三条链路尽量自动化成 smoke tests。

### P2.2 README 与项目入口文档

状态：⬜ 未完成。

建议内容：

- 项目定位和当前玩法。
- Godot 版本和启动方式。
- 目录结构。
- 文档阅读顺序。
- 已验证链路。
- 常见调试入口：CombatDebugger、CommandBus log、Godot MCP。

### P2.3 工程卫生

状态：✅ 已完成。

后续维护：

- 历史迁移脚本保留时应标注适用范围，避免误运行。
- 新增资源后用 Godot 编辑器或脚本检查坏引用。

---

## 当前证据文件

Runtime 主链：

- `main.tscn`
- `core/game_runtime.gd`
- `core/command/command_bus.gd`
- `core/command/runtime_command.gd`
- `world/world_runtime.gd`
- `gameplay/interaction/simulation_runtime.gd`

Combat / HP 权威：

- `gameplay/combat/combat_executor.gd`
- `gameplay/abilities/runtime/projectile.gd`
- `gameplay/abilities/archetypes/persistent_aoe.gd`
- `entities/components/combat_component.gd`
- `entities/enemy/enemy.gd`
- `world/object/spike_trap.gd`
- `world/object/map_object.gd`

World / Simulation：

- `world/state/world_state_manager.gd`
- `world/spatial/world_spatial_index.gd`
- `gameplay/interaction/respawn_scheduler.gd`
- `gameplay/interaction/surface_manager.gd`
- `gameplay/interaction/propagation_scheduler.gd`
- `world/time/world_time.gd`
- `world/regions/burning_forest/burning_forest.gd`

Action / NPC：

- `gameplay/action/action.gd`
- `gameplay/action/action_resolver.gd`
- `gameplay/action/player_action.gd`
- `entities/player/player.gd`
- `entities/enemy/enemy.gd`
- `world/npcs/npc_brain.gd`
- `world/npcs/move_to_task.gd`

文档：

- `docs/INDEX.md`
- `docs/PROJECT_ANALYSIS.md`
- `docs/PROJECT_IMPROVEMENTS.md`
- `docs/RUNTIME_TOPOLOGY.md`
- `docs/COMBAT_CONTRACTS.md`
- `docs/WORLD_CONTRACTS.md`

---

## 建议实施顺序

1. ✅ 修复坏资源引用和明显场景错误。
2. ✅ 明确并实现 CombatExecutor HP 权威。
3. ✅ 补齐 CommandBus target/domain 路由。
4. ✅ 接通 MapObject 销毁、WorldState 更新、RespawnScheduler、SceneTree 表现同步。
5. ✅ 完成 SimulationRuntime 对 WorldTime、SurfaceManager 注入。
6. ✅ 按物理层标准做全项目碰撞配置核对。
7. ✅ 统一 Player/NPC/Enemy 的 Action 执行链主体。
8. 🔄 修正文档路径、日期和 README 状态。
9. 🔄 将三条已完成冒烟链沉淀为固定测试清单。
10. ⬜ 补根目录 README。

---

## 停止线

P0 权威链路已经完成，不再阻塞新功能。但在继续扩展前，应遵守以下停止线：

- 不新增第二套事件总线。
- 不新增第二套 Runtime 调度器。
- 不在命中源里绕过 `CombatExecutor.report_hit()` 直接扣血。
- 不在 Runtime 之间新增未经 `CommandBus` 或明确例外说明的直接调用。
- 不继续扩写过时文档；架构变更后必须同步 `PROJECT_IMPROVEMENTS.md` 和 `INDEX.md`。
