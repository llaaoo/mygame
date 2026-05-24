# 项目改进点清单

> 生成日期: 2026-05-24  
> 最后更新: 2026-05-24  
> 范围: 排除 `addons/` 与 `godot_state_charts_examples/`  
> 目的: 记录当前项目结构、代码现状与 `docs/` 架构契约之间的差距，作为后续迭代输入。

---

## 完成进度

| 条目 | 状态 |
|------|:--:|
| P0.1 CombatExecutor HP 权威 | ✅ |
| P0.2 CommandBus 领域路由 | ✅ |
| P0.3 WorldState/Respawn 生命周期 | ✅ |
| P1.1 SimulationRuntime 调度收敛 | ✅ |
| P1.2 物理层核对 | ✅ |
| P1.3 Action Layer 统一 | ✅ |
| P1.4 文档路径同步 | ⬜ |
| P2.1 场景验证 | 🔄 burning_forest 有雏形 |
| P2.2 README | ⬜ |
| P2.3 坏资源/孤儿文件清理 | ✅ |

---

## 当前项目总体判断

项目已经具备较完整的 Godot 4 ARPG 原型骨架，核心目录分层清晰：

- `core/`: Runtime 根、命令总线、事件总线、状态机、调试追踪。
- `gameplay/`: 技能、战斗、状态、背包、任务、交互模拟。
- `entities/`: 玩家、敌人、NPC、组件、拾取物。
- `world/`: 地图、世界物体、NPC 日程、空间索引、世界状态。
- `content/`: 物品、任务、视觉配置等 `.tres` 内容数据。
- `ui/`: HUD、背包、升级、技能栏等表现层。
- `tests/` 和 `tools/`: 基础验证脚本与历史迁移/修复工具。

整体方向与 `docs/ARCHITECTURE.md` 的六层边界基本一致；`main.tscn` 已挂载 `GameRuntime / WorldRuntime / SimulationRuntime`，多个组件也已改为向 `SimulationRuntime` 注册 `tick()`。这说明项目已经从“节点直接互调”的原型，开始向 Runtime 架构迁移。

当前主要问题不是“缺少更多系统”，而是若干权威入口尚未真正闭合：CommandBus、CombatExecutor、WorldStateManager、SimulationRuntime 都已经存在，但实际调用链仍混有直接调用、SceneTree 查询、裸事件发射和旧路径残留。继续扩展新系统前，应优先收敛这些边界。

---

## 与架构契约的主要差异

### 1. Runtime 边界未完全闭合

契约要求跨 Runtime 通信统一走 `CommandBus`，但当前代码中 `CommandBus` 主要由 `GameRuntime` 创建和调度，实际业务命令生产/消费还很少。

证据：

- `core/game_runtime.gd` 已创建 `CommandBus` 并在 `_process()` 中调用 `dispatch()`。
- `core/command/command_bus.gd` 的 `_dispatch_one()` 对 `cmd.target` 只有占位逻辑，定向路由尚未实现。
- `world/world_runtime.gd` 订阅了 `DESTROYED / RESPAWN_REQUEST / CHUNK_LOAD_REQUEST`，但项目中缺少对应完整生产链。
- `gameplay/interaction/simulation_runtime.gd` 暂未订阅 `SURFACE_CHANGE` 等命令。

影响：

- 文档中的 `GameRuntime -> CommandBus -> Combat/World/Simulation` 还没有成为真实主链。
- 新增世界模拟、表面传播、重生、区域切换时，容易重新退回节点互调。

### 2. HP 修改权威不一致

契约要求 `CombatExecutor` 是 HP 修改和战斗事件的唯一权威入口。但当前多处代码是先 `CombatExecutor.report_hit()`，随后直接调用目标 `take_damage()`。

证据：

- `gameplay/abilities/runtime/projectile.gd` 命中后直接 `body.take_damage(damage)` / `target.take_damage(damage)`。
- `gameplay/abilities/archetypes/persistent_aoe.gd` AoE 命中后直接 `take_damage()`。
- `entities/components/combat_component.gd` 近战命中后直接 `target.take_damage(attack_damage)`。
- `entities/enemy/enemy.gd` 敌人近战直接 `player.take_damage(attack_damage)`。
- `world/object/spike_trap.gd` 陷阱 tick 直接 `body.take_damage(damage)`。
- `world/object/map_object.gd` 破坏 AoE 中同时调用 `CombatExecutor.report_hit()` 和 `t.take_damage()`。

影响：

- 事件、伤害应用、trace、TriggeredEffect、Buff/DOT 的权威来源分裂。
- 后续接入 CommandBus、回放、联网或统一调试时，会出现重复伤害或漏事件风险。

### 3. WorldState / Respawn 生命周期未打通

契约要求 `WorldStateManager` 持有真实世界状态，SceneTree 只是表现层。但当前 MapObject 销毁后主要更新自身状态，没有形成完整的 Runtime 命令和重生队列闭环。

证据：

- `world/object/map_object.gd` 中 `_on_destroyed()` 只发本地 `destroyed` 信号，没有发 `RuntimeCommand DESTROYED`。
- `gameplay/interaction/respawn_scheduler.gd` 有 `enqueue()` 和 `tick()`，但未发现 MapObject 销毁后接入该队列。
- `world/world_runtime.gd` 的 `_on_chunk_load_request()` 仍是空实现。
- `world/state/world_state_manager.gd` 可以保存和恢复状态，但区域/Chunk 生命周期尚未统一驱动。

影响：

- `respawn_time`、切场景恢复、Dormant/Abstracted 激活模型可能与文档不一致。
- 可破坏物在卸载/重进后的真实状态存在漂移风险。

### 4. SimulationRuntime 已部分接管 tick，但仍有分散点

已经完成的部分：

- `HealthComponent`、`ManaComponent`、`BuffManager`、`SkillManager`、`DialogueNPC`、`SpikeTrap` 已注册到 `SimulationRuntime`。
- `SurfaceScheduler`、`PropagationScheduler`、`RespawnScheduler` 由 `SimulationRuntime.tick()` 驱动。

仍需收敛：

- `world/time/world_time.gd` 仍独立 `_process()` 推进时间。
- `world/regions/burning_forest/burning_forest.gd` 仍独立 `_process()` 处理 ESC 返回。
- `world/spatial/world_spatial_index.gd` 有 `set_surface_manager()`，但 `SimulationRuntime.setup_dependencies()` 未注入 `_surface_manager`，导致 `query_surface()` 相关接口实际不可用。

影响：

- 调度顺序、暂停、低频/高频分组和未来 Dormant 模式仍难以统一审计。

### 5. Action Layer 处于双轨过渡

文档要求 Player/NPC/Enemy/Boss 逐步共享 Action 体系。当前已有 `gameplay/action/action.gd` 与 `ActionResolver`，Enemy 和 Player 都出现了通用 Action 入口，但 Player 仍保留旧 `PlayerAction`。

证据：

- `entities/player/player.gd` 同时存在 `poll_universal_actions()/resolve_action()` 和旧 `poll_actions()/try_action()`。
- `gameplay/action/player_action.gd` 仍在使用。
- `world/npcs/npc_brain.gd` 已能生成 `Action`，但执行仍直接启动 `MoveToTask`，未完全走统一 Action 执行链。

影响：

- Player、NPC、Enemy 的行为入口还没有完全同构。
- 后续添加 Boss 或复杂 NPC 行为时，会继续产生多套行为路由。

### 6. 物理层迁移不完整

`docs/PHYSICS_LAYERS.md` 定义了 11 层标准，当前项目部分节点已迁移，但仍存在旧值和不一致配置。

证据：

- Player / Enemy 根节点已使用 `ACTOR` 层和 `WORLD_STATIC | ACTOR` mask。
- Projectile 使用 `PROJECTILE` 层，但 mask 包含 `ACTOR`，与文档中 `WORLD_STATIC | HURTBOX | SURFACE` 的定义不完全一致。
- 多个 MapObject 的 `HitArea` 使用 `collision_layer = 8`、`collision_mask = 20`，需要按当前层表重新核对语义。
- 部分旧工具脚本仍写死旧碰撞值。

影响：

- Hitbox/Hurtbox/Projectile/Interaction/Surface 的检测边界不够稳定。
- 后续新增场景物、陷阱、拾取物时，容易复制旧配置。

### 7. 文档路径与实际目录漂移

实际项目采用 `core/`、`gameplay/`、`entities/`、`world/`、`content/` 等目录；部分文档仍保留旧的目标结构或迁移前路径。

证据：

- `docs/COMBAT_CONTRACTS.md` 仍大量引用 `res://skills/`、`res://systems/`、`res://components/`、`res://items/`。
- `docs/skill_architecture.md` 仍以 `res://skills/` 和 `res://runtime/combat/skills/` 描述技能结构。
- `docs/RUNTIME_TOPOLOGY.md` 的“最终收敛版”以 `res://runtime/` 为目标结构，但当前实际代码仍分散在 `core/`、`gameplay/`、`world/`。
- `docs/INDEX.md` 与 `docs/PROJECT_ANALYSIS.md` 使用了未来日期 `2026-07-14`，与当前日期 `2026-05-24` 不一致。

影响：

- 新人或后续维护者会难以判断“这是当前事实”还是“目标结构”。
- 迁移工具和文档可能误导后续改动。

---

## P0 改进点：权威链路收敛

### P0.1 明确并实现 CombatExecutor 的 HP 修改权威

目标：

- 定义 `CombatExecutor.report_hit()` 是否负责实际扣血。
- 若负责，则所有外部命中源不得再直接 `target.take_damage()`。
- 若不负责，则文档需改写为“CombatExecutor 是事件/阶段权威，HealthComponent/MapObject 是扣血接收者”，避免假契约。

建议方向：

- 推荐让 `CombatExecutor.report_hit()` 完成“阶段校验 -> 事件发射 -> 调用 Damageable.take_damage()`”的完整链路。
- `Projectile`、`PersistentAOE`、`CombatComponent`、`Enemy`、`SpikeTrap`、`MapObject` 只发请求，不直接扣血。
- 保留 `HealthComponent.take_damage()` 与 `MapObject.take_damage()` 作为接收端接口，不作为发起端入口。

验收标准：

- `rg "take_damage\\("` 中，除接收端实现、CombatExecutor 内部和测试外，不再出现命中源裸调。
- ON_HIT、ON_DAMAGE、ON_KILL 顺序稳定，trace 不重复。

### P0.2 补齐 CommandBus 主链

目标：

- 让 Runtime 间通信至少覆盖 `HIT_REQUEST`、`DAMAGE_RESULT`、`DESTROYED`、`SURFACE_CHANGE`、`RESPAWN_REQUEST`。
- `CommandBus` 具备明确 target/domain 路由，不再只是按 type 广播。

建议方向：

- 在 `RuntimeCommand` 中定义命令常量或 domain 命名规范，例如 `combat/hit_request`、`world/destroyed`、`simulation/surface_change`。
- `CombatRuntime` 处理 hit/damage 请求，输出结果。
- `WorldRuntime` 处理对象生命周期和状态一致性。
- `SimulationRuntime` 处理 surface/propagation/respawn 调度。

验收标准：

- `world/object/map_object.gd` 不直接访问 `SimulationRuntime._surface_manager`。
- `gameplay/abilities/*` 不直接调用世界状态或表面系统。
- `CommandBus` 的 `target` 有实际过滤或 domain 分发行为。

### P0.3 打通 WorldState / Respawn 生命周期

目标：

- MapObject 销毁、状态保存、重生排队、切场景恢复走统一链路。

建议方向：

- `MapObject._on_destroyed()` 发 `DESTROYED` 命令。
- `WorldRuntime` 更新 `WorldStateManager`，并根据 `respawn_time` 发 `RESPAWN_REQUEST` 或调用 `RespawnScheduler.enqueue()`。
- `RespawnScheduler` 到期后只更新 WorldState，由 WorldRuntime 同步当前加载的 SceneTree 表现。
- 实现或明确删除 `WorldRuntime._on_chunk_load_request()` 的空占位。

验收标准：

- 可破坏物在出入区域后状态一致。
- `respawn_time = -1 / 0 / >0` 三种语义有自动化或手动验证场景。

---

## P1 改进点：架构收敛

### P1.1 完成 SimulationRuntime 调度收敛

目标：

- `WorldTime`、区域输入、NPC/Actor tick、表面状态、传播、重生由统一调度或清晰例外驱动。

建议方向：

- 将 `WorldTime._process()` 改为 `tick(delta)`，由 `SimulationRuntime` 或 `GameRuntime` 显式调用。
- 给 `SimulationRuntime` 暴露只读访问器，例如 `get_surface_manager()`，避免外部访问 `_surface_manager`。
- 在 `setup_dependencies()` 中调用 `spatial_index.set_surface_manager(_surface_manager)`。
- 区域返回逻辑不要放在区域自身 `_process()` 中，可改为 Player/Input Action 或 RegionRuntime 请求。

### P1.2 物理层按文档重新核对

目标：

- 所有 CharacterBody2D、Area2D、StaticBody2D、Pickup、Portal、MapObject 使用 `PHYSICS_LAYERS.md` 定义的层/掩码。

建议方向：

- 建立一份场景碰撞层检查表。
- 更新旧工具脚本或将其标记为历史迁移脚本，避免继续写入旧值。
- 用一个验证脚本扫描 `.tscn` 中的 `collision_layer` / `collision_mask`。

### P1.3 完成 Action Layer 统一

目标：

- Player、Enemy、NPC 后续统一走 `Action -> ActionResolver -> RuntimeRequest/RuntimeExecute`。

建议方向：

- 标记 `PlayerAction` 为迁移期兼容层，逐步把 State 调用切到 `Action`。
- NPCBrain 只生产 `Action`，不直接启动 `MoveToTask`。
- Enemy 的 StateChart 只做状态感知和事件转换，不承担行为执行细节。

### P1.4 同步架构文档路径

目标：

- 区分“当前实际结构”和“目标收敛结构”。

建议方向：

- 在 `COMBAT_CONTRACTS.md`、`skill_architecture.md`、`RUNTIME_TOPOLOGY.md` 中把旧路径更新为当前真实路径，或显式标注为“历史/目标结构”。
- 修正 `docs/INDEX.md`、`docs/PROJECT_ANALYSIS.md` 的未来日期。
- 若后续决定保留本文件，应将 `PROJECT_IMPROVEMENTS.md` 加入 `docs/INDEX.md`。

---

## P2 改进点：内容验证与工程卫生

### P2.1 用场景验证架构能力

目标：

- 不再新增系统，而是用完整内容场景验证系统协作。

建议场景：

- 小型地牢：门、开关、地刺、宝箱、油桶、surface、propagation、quest 联动。
- 村庄：NPC Schedule、Marker、Dialogue、Quest、Interact 协同。
- 野外热点：可破坏物阵列、油桶连锁、区域切换后状态恢复。

验收标准：

- 设计师只改 `.tscn` 和 `.tres` 可以配置内容。
- 不为每个新技能、新机关、新 NPC 行为新增运行时代码。

### P2.2 README 与项目入口文档

目标：

- 根目录 README 应说明当前 Study 项目，而不是插件或迁移残留。

现状说明：

- 本次审计前，根目录 README 内容为 Importality 插件说明。
- 当前工作树中 `README.md` 与 `README.ru.md` 显示为删除状态；是否保留、重建或确认删除，需要后续单独决策。

建议方向：

- 若保留 README，重建为项目介绍、运行方式、目录结构、架构文档入口、测试方式。
- 若删除 README，则同步清理 docs 中关于 README 的旧描述。

### P2.3 清理坏资源引用、孤儿文件和临时文件

已发现问题：

- `entities/pickups/mana_pickup.tscn` 引用旧路径 `res://pickups/mana_pickup_shape.tres`，真实文件在 `entities/pickups/mana_pickup_shape.tres`。
- 存在孤儿 UID：`gameplay/action/action_result.gd.uid`、`tools/fix_collision_layers.gd.uid`。
- 存在临时文件：`world/regions/burning_forest/burning_forest.tscn1894065647.tmp`。
- `tools/` 中多个迁移脚本保留大量旧路径，如 `res://runtime/`、`res://skills/`、`res://components/`。
- `entities/npc/npc.tscn` 将 `entities/npc/npc.gd` 挂在 `Sprite2D` 子节点上，而根节点 `NPC` 没有脚本，疑似场景配置错误。

建议方向：

- 修复真实运行资源引用。
- 删除或归档孤儿 `.uid` 和 `.tmp`。
- 给 `tools/` 增加 README，标注哪些工具过期、哪些仍可运行。
- 修复或移除未使用的旧 NPC 场景，避免与 `world/object/npc.gd` 的 `DialogueNPC` 混淆。

---

## 具体证据文件

核心 Runtime：

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
- `world/npcs/npc_brain.gd`
- `world/npcs/move_to_task.gd`
- `world/object/npc.gd`

工程卫生：

- `entities/pickups/mana_pickup.tscn`
- `entities/pickups/mana_pickup_shape.tres`
- `entities/npc/npc.tscn`
- `tools/`
- `docs/INDEX.md`
- `docs/PROJECT_ANALYSIS.md`

---

## 建议实施顺序

1. ✅ 修复坏资源引用和明显场景错误（P2.3）
2. ✅ 明确 CombatExecutor 是否真正负责扣血（P0.1）
3. ✅ 补齐 CommandBus 的 target/domain 路由（P0.2）
4. ✅ 接通 MapObject 销毁、WorldState 更新、RespawnScheduler、SceneTree 表现同步（P0.3）
5. ✅ 完成 SimulationRuntime 对 WorldTime、SurfaceManager 注入（P1.1）
6. ✅ 按物理层标准做全项目碰撞配置核对（P1.2）
7. ✅ 统一 Player/NPC/Enemy 的 Action 执行链（P1.3）
8. ⬜ 修正文档路径、日期和 README 状态（P1.4 / P2.2）
9. ⬜ 用小型地牢、村庄、野外热点验证（P2.1）

---

## 停止线

在 P0/P1 完成前，不建议继续扩展以下方向：

- 新技能类型。
- 新 Modifier / Condition / GraphNode。
- 新表面状态。
- 行为树、GOAP、Planner 或额外 AI 框架。
- 新事件总线或第二套 Runtime 调度器。

当前优先事项是让已有系统协同运作，而不是继续加系统。

