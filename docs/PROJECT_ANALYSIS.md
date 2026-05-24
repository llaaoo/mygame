# 📘 项目完整分析文档 — "Study" 项目

> **生成日期**: 2026-07-14  
> **引擎版本**: Godot 4.6.2 (stable) / GDScript 2.0  
> **项目名称**: Study  
> **排除分析**: `addons/`, `godot_state_charts_examples/`

---

## 目录

1. [项目概览](#1-项目概览)
2. [完整目录树](#2-完整目录树)
3. [核心层 (core/)](#3-核心层-core)
4. [玩法层 (gameplay/)](#4-玩法层-gameplay)
5. [实体层 (entities/)](#5-实体层-entities)
6. [世界层 (world/)](#6-世界层-world)
7. [内容层 (content/)](#7-内容层-content)
8. [UI层 (ui/)](#8-ui层-ui)
9. [文档层 (docs/)](#9-文档层-docs)
10. [测试层 (tests/)](#10-测试层-tests)
11. [工具层 (tools/)](#11-工具层-tools)
12. [根目录文件](#12-根目录文件)
13. [架构评估与迭代建议](#13-架构评估与迭代建议)

---

## 1. 项目概览

### 1.1 项目定位

这是一个**中等规模的动作 RPG (ARPG) 原型项目**，2025年7月开始开发，至2026年5月已完成 v2.3 版本。项目具有以下特征：

- **2D 俯视角动作 RPG**（类似《暗黑破坏神》或《伊苏》）
- **六层架构模型**：content → world → entities → gameplay → core → UI
- **数据驱动设计**：技能/物品/Buff/任务全部通过 `.tres` Resource 配置
- **严格的契约体系**：12 条 Combat Contracts + 9 条 World Contracts
- **自制系统**：无第三方战斗/技能/状态插件，全部手写

### 1.2 核心特性

| 系统 | 状态 | 说明 |
|------|------|------|
| 玩家移动/战斗 | ✅ 完成 | 4 方向 WASD + 鼠标瞄准 |
| 技能系统 | ✅ 完成 | 4 类型（PROJECTILE/BUFF/AOE/DASH）+ 数据驱动 |
| 战斗管线 | ✅ 完成 | FLAT→MULTIPLY→OVERRIDE→FINAL 四阶段 Modifier |
| 事件系统 | ✅ 完成 | CombatEventBus + CombatExecutor 唯一写入口 |
| 效果图 | ✅ 完成 | EffectGraph（序列/分支/条件门节点） |
| Buff/状态 | ✅ 完成 | status_id + 叠加规则 + DOT/HOT + 减速 |
| 装备系统 | ✅ 完成 | 7 槽位 + 纸娃娃拖拽 UI |
| 背包系统 | ✅ 完成 | 网格背包 + 堆叠 |
| 属性/升级 | ✅ 完成 | STR/INT/AGI/END + 属性点分配 |
| Quest 任务 | ✅ 完成 | 多阶段 + KillObjective + InteractObjective |
| NPC 日程 | ✅ P1完成 | WorldTime + Schedule + MoveToTask |
| NPC 对话 | ✅ 完成 | DialogueManager 集成 + 自定义对话气球 |
| 表面系统 | ✅ 完成 | 5 状态（dry/wet/burning/frozen/oiled）+ 反应规则 |
| 世界物体 | ✅ 完成 | MapObject 基类 + 7 种物体 |
| 空间索引 | ✅ 完成 | 固定网格分桶 + WorldSpatialIndex |
| 战斗调试器 | ✅ 完成 | CombatDebugger + CombatDebugUI |
| 敌人 AI | ✅ 完成 | StateChart 驱动的反应式 AI |
| 属性系统 | ✅ 完成 | StatsComponent + 派生计算 |
| 掉落物 | ✅ 完成 | 血包/魔包 |
| 传送门 | ✅ 完成 | 场景切换 |
| 开关/压力板/门 | ✅ 完成 | SignalReceiver + Interactable 接口 |
| 宝箱/掉落表 | ✅ 完成 | LootTable + 随机抽取 |
| 油桶连锁爆炸 | ✅ 完成 | AOE + 表面生成 + 反应链 |
| 死亡/重生 | ✅ 完成 | 死亡画面 + 重新加载 |

---

## 2. 完整目录树

```
res://
├── main.tscn                          # 项目主场景入口
├── project.godot                      # 项目配置（输入映射/自动加载/插件）
├── icon.svg / icon.png                # 项目图标
├── LICENSE                            # MIT 许可证
├── README.md / README.ru.md           # 项目 README（实为 Importality 插件说明）
│
├── core/                              # [核心层] — 全项目公用的基础系统
│   ├── game_runtime.gd                # 顶层运行时协调器 (Autoload)
│   ├── input_setup.gd                 # 运行时 InputMap 自动注册
│   ├── state/
│   │   ├── state.gd                   # FSM 状态基类
│   │   └── state_machine.gd           # FSM 状态机
│   ├── event/
│   │   ├── combat_event.gd            # 战斗事件纯数据载体
│   │   ├── combat_event_bus.gd        # 全局发布/订阅事件总线
│   │   └── combat_scope.gd            # 战斗作用域（SKILL/BATTLE/GLOBAL）
│   ├── command/
│   │   ├── command_bus.gd             # 跨 Runtime 异步命令总线
│   │   └── runtime_command.gd         # Runtime 命令纯数据载体
│   └── debug/
│       ├── combat_debugger.gd         # 战斗追踪器（trace 开关）
│       ├── combat_debug_ui.gd         # 战斗调试 UI 面板
│       ├── combat_trace.gd            # 单次技能/命中的完整追踪记录
│       └── combat_trace_event.gd      # 追踪事件条目
│
├── gameplay/                          # [玩法层] — 游戏逻辑系统
│   ├── action/
│   │   └── player_action.gd           # Action Layer — 玩家输入→意图转换
│   ├── abilities/                     # 技能系统（数据+运行时+Archetype）
│   │   ├── data/
│   │   │   ├── skill_data.gd          # SkillData Resource（纯数据）
│   │   │   ├── fireball_data.tres      # 火球
│   │   │   ├── flame_storm_data.tres   # 火焰风暴
│   │   │   ├── ice_armor_data.tres     # 冰甲
│   │   │   ├── ice_explosion_data.tres # 冰爆炸
│   │   │   ├── shadow_bolt_data.tres   # 暗影弹
│   │   │   ├── shadow_step_data.tres   # 暗影步
│   │   │   ├── ice_armor_buff.tres     # 冰甲 Buff
│   │   │   ├── shadow_step_buff.tres   # 暗影步 Buff
│   │   │   ├── burning.tres           # Burning 状态 Buff
│   │   │   ├── frozen.tres            # Frozen 状态 Buff
│   │   │   ├── wet.tres               # Wet 状态 Buff
│   │   │   └── poison.tres            # Poison 状态 Buff
│   │   ├── archetypes/
│   │   │   ├── linear_projectile.tscn  # 直线投射物 Archetype 场景
│   │   │   ├── persistent_aoe.tscn     # 持久 AoE Archetype 场景
│   │   │   └── persistent_aoe.gd      # AoE 实例逻辑
│   │   ├── runtime/
│   │   │   ├── skill_executor.gd      # 核心执行器 + Modifier 管线
│   │   │   ├── skill_instance.gd      # SkillData 运行时包装（冷却）
│   │   │   ├── cast_context.gd        # 施法上下文（纯数据）
│   │   │   ├── damage_context.gd      # 伤害上下文（纯数据）
│   │   │   └── projectile.gd          # 投射物运行时逻辑
│   │   ├── manager/
│   │   │   └── skill_manager.gd       # 技能管理器（装备/冷却/释放）
│   │   ├── registry/
│   │   │   ├── skill_pool.gd          # SkillPool Resource
│   │   │   └── player_skill_pool.tres  # 玩家技能池
│   │   ├── loadout/
│   │   │   ├── skill_loadout.gd       # SkillLoadout Resource
│   │   │   └── default_loadout.tres    # 默认装备表
│   │   ├── visuals/
│   │   │   ├── projectile_visual_data.gd  # ProjectileVisualData Resource
│   │   │   └── aoe_visual_data.gd         # AOEVisualData Resource
│   │   └── effect_graph/
│   │       ├── effect_graph.gd         # EffectGraph（节点树执行引擎）
│   │       ├── effect_graph_context.gd # 图执行上下文
│   │       ├── effect_node.gd          # 效果节点基类
│   │       ├── sequence_node.gd        # 序列节点（依次执行）
│   │       ├── branch_node.gd          # 分支节点（if/else）
│   │       ├── condition_gate_node.gd  # 条件门节点
│   │       ├── callable_node.gd        # Callable 节点
│   │       ├── log_node.gd             # 日志节点
│   │       └── empty_node.gd           # 空/终端节点
│   ├── combat/                        # 战斗核心系统
│   │   ├── combat_executor.gd         # 唯一控制流入口 + 阶段机
│   │   ├── combat_phase.gd            # 战斗阶段锁定义
│   │   ├── triggered_effect.gd        # 触发式效果（事件→条件→执行）
│   │   ├── conditions/
│   │   │   ├── condition.gd           # 条件基类
│   │   │   ├── tag_condition.gd       # 标签条件
│   │   │   ├── skill_tag_condition.gd # 技能标签条件
│   │   │   ├── status_condition.gd    # 状态条件
│   │   │   ├── buff_name_condition.gd # Buff 名称条件
│   │   │   ├── low_hp_condition.gd    # 低血量条件
│   │   │   └── target_type_condition.gd # 目标类型条件
│   │   ├── modifiers/
│   │   │   ├── damage_modifier.gd     # 伤害 Modifier 基类（四阶段）
│   │   │   ├── flat_bonus_modifier.gd# 固定加成 Modifier
│   │   │   ├── stat_scaling_modifier.gd# 属性缩放 Modifier
│   │   │   └── tag_multiplier_modifier.gd # 标签倍率 Modifier
│   │   ├── on_hit/
│   │   │   ├── on_hit_apply_status.gd # ON_HIT → 施加状态
│   │   │   └── on_hit_fire_bonus.gd   # ON_HIT → 火焰加成
│   │   ├── on_kill/
│   │   │   └── on_kill_bonus_exp.gd   # ON_KILL → 额外经验
│   │   └── on_armor/
│   │       └── on_ice_armor_expire.gd # 冰甲过期 → 冰爆
│   ├── status/
│   │   ├── buff.gd                    # Buff/Debuff Resource
│   │   └── buff_manager.gd            # Buff 管理器（施加/过期/叠加）
│   ├── inventory/
│   │   ├── inventory.gd               # 背包 Resource
│   │   ├── equipment_manager.gd       # 装备管理器（7槽位）
│   │   └── data/
│   │       ├── item_data.gd           # ItemData Resource
│   │       └── equipment_data.gd      # EquipmentData Resource
│   ├── quest/                         # 任务系统
│   │   ├── data/
│   │   │   ├── quest_data.gd          # QuestData Resource
│   │   │   ├── quest_stage.gd         # QuestStageData Resource
│   │   │   └── objective.gd           # QuestObjective 基类
│   │   ├── objectives/
│   │   │   ├── kill_objective.gd      # 击杀目标
│   │   │   └── interact_objective.gd  # 交互目标
│   │   ├── runtime/
│   │   │   ├── quest_manager.gd       # 任务管理器
│   │   │   └── quest_runtime.gd       # 任务运行时
│   │   └── ui/
│   │       └── quest_tracker.gd       # 任务追踪 UI
│   └── interaction/                   # 世界交互系统
│       ├── simulation_runtime.gd      # 统一调度器
│       ├── surface_manager.gd         # 表面系统入口
│       ├── surface_data.gd            # SurfaceData Resource
│       ├── surface_reaction.gd        # SurfaceReaction Resource
│       ├── surface_scheduler.gd       # 表面倒计时调度
│       ├── propagation_scheduler.gd   # BFS 传播队列
│       ├── respawn_scheduler.gd       # 重生倒计时调度
│       └── reaction_rule.gd           # 反应规则（旧，被 SurfaceReaction 替代）
│
├── entities/                          # [实体层] — 玩家/敌人/NPC/组件
│   ├── components/
│   │   ├── health_component.gd        # HP 组件（受伤/无敌/自回/死亡）
│   │   ├── combat_component.gd        # 近战攻击组件
│   │   ├── mana_component.gd          # MP 组件（消耗/自回）
│   │   └── stats_component.gd         # 主属性组件（STR/INT/AGI/END + 升级）
│   ├── player/
│   │   ├── player.tscn                # 玩家场景
│   │   ├── player.gd                  # 玩家主脚本（协调器）
│   │   ├── player_shape.tres          # 身体碰撞形状
│   │   ├── player_body_shape.tres     # 备用身体形状
│   │   └── states/
│   │       ├── idle.gd                # 待机状态
│   │       ├── move.gd                # 移动状态
│   │       ├── attack.gd              # 攻击状态
│   │       ├── dodge.gd               # 闪避状态
│   │       └── skill.gd               # 技能释放状态
│   ├── enemy/
│   │   ├── enemy.tscn                 # 敌人场景（StateChart + 属性 + SkillManager）
│   │   ├── enemy.gd                   # 敌人主脚本（StateChart/预设/掉落）
│   │   └── enemy_body_shape.tres      # 身体碰撞形状
│   ├── npc/
│   │   ├── npc.tscn                   # NPC 场景
│   │   └── npc.gd                     # NPC 基类
│   └── pickups/
│       ├── pickup.gd                  # 拾取物基类
│       ├── health_pickup.gd           # 血包拾取
│       ├── health_pickup.tscn         # 血包场景
│       ├── mana_pickup.gd             # 魔包拾取
│       ├── mana_pickup.tscn           # 魔包场景
│       └── mana_pickup_shape.tres     # 魔包碰撞形状
│
├── world/                             # [世界层] — 地图/物体/交互/NPC 日程
│   ├── world_runtime.gd               # WorldRuntime 入口
│   ├── maps/
│   │   └── overworld.tscn             # 主世界地图
│   ├── spatial/
│   │   └── world_spatial_index.gd     # 统一空间查询索引
│   ├── state/
│   │   └── world_state_manager.gd     # 世界状态管理器（持久化）
│   ├── regions/
│   │   └── burning_forest/
│   │       ├── burning_forest.tscn     # 燃烧森林区域
│   │       └── burning_forest.gd      # 燃烧森林区域脚本
│   ├── object/                        # WorldObject 体系（7种）
│   │   ├── map_object.gd             # MapObject 基类
│   │   ├── map_object_data.gd        # MapObjectData Resource
│   │   ├── interactable.gd           # Interactable 接口
│   │   ├── signal_receiver.gd        # SignalReceiver 接口
│   │   ├── switch.gd                 # 开关
│   │   ├── door.gd                   # 门（MapObject + SignalReceiver）
│   │   ├── chest.gd                  # 宝箱（MapObject + Interactable + LootTable）
│   │   ├── portal.gd                 # 传送门（Area2D）
│   │   ├── spike_trap.gd             # 地刺陷阱
│   │   ├── pressure_plate.gd         # 压力板
│   │   ├── npc.gd                    # DialogueNPC（对话 + Schedule）
│   │   ├── npc_dialogue.gd           # NPCDialogue Resource（旧格式）
│   │   ├── dialogue_balloon.gd       # 自定义对话气球
│   │   ├── oil_barrel.tscn           # 油桶场景（AOE + 表面生成）
│   │   ├── oil_barrel_data.tres      # 油桶配置
│   │   ├── barrel_shape.tres         # 桶碰撞形状
│   │   ├── breakable_wall.tscn       # 可破坏墙
│   │   ├── breakable_wall_data.tres  # 可破坏墙配置
│   │   ├── wall_shape.tres           # 墙碰撞形状
│   │   ├── ice_wall.tscn             # 冰墙
│   │   ├── ice_wall_data.tres        # 冰墙配置
│   │   ├── wooden_crate.tscn         # 木箱
│   │   ├── wooden_crate_data.tres    # 木箱配置
│   │   ├── wooden_fence.tscn         # 木栅栏
│   │   └── wooden_fence_data.tres    # 木栅栏配置
│   ├── doors/
│   │   ├── door.tscn                 # 门场景
│   │   ├── door_data.tres            # 门默认配置
│   │   └── door_shape.tres           # 门碰撞形状
│   ├── switches/
│   │   ├── switch.tscn               # 开关场景（旧）
│   │   ├── switch_new.tscn           # 开关场景（新）
│   │   └── pressure_plate.tscn       # 压力板场景
│   ├── traps/
│   │   ├── spike_trap.tscn           # 地刺场景
│   │   └── trap_shape.tres           # 地刺碰撞形状
│   ├── loot/
│   │   ├── loot_table.gd             # LootTable Resource
│   │   ├── loot_entry.gd             # LootEntry Resource
│   │   ├── test_loot_table.tres      # 测试掉落表
│   │   └── chest.tscn                # 宝箱场景
│   ├── portals/
│   │   ├── portal.tscn               # 传送门场景
│   │   ├── portal.gd                 # 传送门脚本
│   │   └── portal_shape.tres         # 传送门碰撞形状
│   ├── markers/
│   │   ├── world_marker.gd           # 世界锚点（NPC 导航目标）
│   │   └── marker_registry.gd        # 全局 Marker 注册表
│   ├── npcs/
│   │   ├── npc_brain.gd              # NPC 大脑（Schedule → Task 决策）
│   │   ├── npc_schedule.gd           # NPCSchedule Resource
│   │   ├── schedule_entry.gd         # ScheduleEntry Resource
│   │   ├── move_to_task.gd           # MoveToTask — 移动到 Marker
│   │   ├── npc_villager.tscn         # 村民场景
│   │   ├── villager_dialogue.tres    # 村民对话数据
│   │   └── villager_schedule.tres    # 村民日程数据
│   ├── time/
│   │   └── world_time.gd             # 世界时间（24h 循环）
│   └── portal.tscn                    # 根级传送门（备用）
│
├── content/                           # [内容层] — 纯数据 .tres 文件
│   ├── items/
│   │   ├── player_inventory.tres      # 玩家背包实例
│   │   └── examples/
│   │       ├── iron_helmet.tres       # 铁头盔
│   │       ├── leather_armor.tres     # 皮甲
│   │       └── iron_boots.tres        # 铁靴
│   ├── quests/
│   │   ├── kill_enemies_quest.tres    # 击杀敌人任务
│   │   └── README.md
│   └── visuals/
│       ├── fire_visual.tres           # 火焰投射物视觉
│       ├── fire_aoe_visual.tres       # 火焰 AoE 视觉
│       ├── shadow_visual.tres         # 暗影投射物视觉
│       └── ice_aoe_visual.tres        # 冰霜 AoE 视觉
│
├── ui/                                # [UI层] — 所有用户界面
│   ├── hud.tscn                       # HUD 场景
│   ├── hud.gd                         # HUD 主脚本
│   ├── inventory_panel.tscn           # 背包面板场景
│   ├── inventory_panel.gd             # 背包面板脚本
│   ├── level_up_ui.tscn               # 升级 UI 场景
│   ├── level_up_ui.gd                 # 升级 UI 脚本
│   ├── skill_bar.gd                   # 技能栏组件
│   ├── skill_pool_ui.gd              # 技能池 UI
│   └── slot_button.gd                # 拖拽槽位按钮组件
│
├── docs/                              # [文档] — 架构/契约/物理层
│   ├── INDEX.md                       # 文档索引
│   ├── ARCHITECTURE.md                # 六层架构定义（宪法）
│   ├── COMBAT_CONTRACTS.md            # 战斗内部 12 条契约
│   ├── WORLD_CONTRACTS.md             # 世界内部 9 条契约
│   ├── PHYSICS_LAYERS.md              # 物理层 11 层标准
│   ├── RUNTIME_TOPOLOGY.md            # 运行时拓扑（五大 Runtime）
│   └── skill_architecture.md          # 技能内容生产方式
│
├── tests/                             # [测试]
│   ├── test_gameplay.gd               # 功能测试（SceneTree 运行）
│   └── test_validation.gd             # 验证测试
│
└── tools/                             # [工具脚本] — 迁移/修复
    ├── add_physics_body.gd
    ├── copy_migration.gd
    ├── create_stubs.gd
    ├── fix_all_paths.gd
    ├── fix_collision_layers.gd
    ├── fix_hitbox_mask.gd
    ├── fix_paths.gd
    ├── fix_player_instance.gd
    └── fix_portal_paths.gd
```

---

## 3. 核心层 (core/)

### 3.1 game_runtime.gd

**类名**: `GameRuntime`  
**继承**: `Node`  
**角色**: 顶层运行时协调器（计划 Autoload）

**功能**:
- 管理五大 Runtime 边界（Combat/World/Simulation/UI/Save）
- 创建并管理 `CommandBus` 实例
- 每帧依次执行：CommandBus.dispatch() → SimulationRuntime.tick()
- 支持暂停/恢复 (`set_paused()`)

**依赖注入**: 通过 `setup_dependencies()` 将 WorldRuntime 的空间索引和状态管理器注入 SimulationRuntime。

---

### 3.2 input_setup.gd

**继承**: `Node`  
**角色**: 运行时 InputMap 自动注册

**功能**:
- 在 `_enter_tree()` 中注册所有游戏输入映射：
  - WASD 移动 (`move_left/right/up/down`)
  - 空格闪避 (`dodge`)
  - 鼠标左键攻击 (`attack`)、右键技能 (`skill`)
  - 数字键 1-4 技能快捷键 (`skill_1` ~ `skill_4`)
- 仅作为 fallback，若 InputMap 已存在相同 action 则跳过

---

### 3.3 state/state.gd — FSM 状态基类

**类名**: `State`  
**继承**: `Node`

**功能**:
- 定义 FSM 状态生命周期：`enter()` → `update()` / `physics_update()` → `exit()`
- `transitioned` 信号用于子类通知 StateMachine 切换
- `entity` 变量持有实体引用

---

### 3.4 state/state_machine.gd — FSM 状态机

**类名**: `StateMachine`  
**继承**: `Node`

**功能**:
- 自动扫描子节点注册所有 State（支持 Duck Typing：`is State` 或 `has_method("enter")`）
- `initial_state` 指定初始状态，否则自动使用第一个子节点
- `on_child_transition()` 处理状态间切换
- `transition_to()` 支持外部强制切换
- 每帧调用当前状态的 `update()` / `physics_update()`
- **FSM 铁律**: 只执行动画/移动/Tween，禁止决策

---

### 3.5 event/combat_event.gd — 战斗事件

**类名**: `CombatEvent`  
**继承**: `RefCounted`  
**角色**: 事件总线中流转的纯数据载体

**功能**:
- 定义 10 种事件类型枚举：`ON_CAST / ON_HIT / ON_DAMAGE / ON_KILL / ON_STATUS_APPLIED / ON_STATUS_REMOVED / ON_HEAL / ON_DODGE / ON_CRIT / ON_INTERACT`
- 携带数据：`source`（发起者）、`target`（承受者）、`skill`、`data: Dictionary`
- 纯数据，不包含任何逻辑

---

### 3.6 event/combat_event_bus.gd — 事件总线

**类名**: `CombatEventBus`  
**继承**: `Node`  
**角色**: 全局发布/订阅，每个场景一个实例

**功能**:
- `static var instance` 全局单例引用
- `subscribe(type, callback)` / `unsubscribe(type, callback)` 订阅管理
- `once(type, callback)` 一次性订阅
- `emit(ev)` 发射事件 — 硬上限 `MAX_DEPTH_HARD=5` 防递归爆炸
- 发射前复制监听列表防止回调中修改订阅
- 自动清理已释放的回调

---

### 3.7 event/combat_scope.gd — 战斗作用域

**类名**: `CombatScope`  
**继承**: `RefCounted`  
**角色**: 控制事件/效果的传播范围

**功能**:
- 定义三种作用域：`SKILL`（单次技能）、`BATTLE`（单场战斗）、`GLOBAL`（全局永久）

---

### 3.8 command/command_bus.gd — 异步命令总线

**类名**: `CommandBus`  
**继承**: `Node`  
**角色**: 跨 Runtime 边界异步通信的唯一通道

**功能**:
- `emit(cmd)` — 命令入队（最多 128 条，超限丢弃旧命令）
- `subscribe(type, callback)` / `unsubscribe(type, callback)`
- `dispatch(max_per_tick=16)` — 每帧由 GameRuntime 驱动处理队列
- **当前状态**: 设计完整但实际未启用（项目运行时主要依赖 CombatEventBus）

---

### 3.9 command/runtime_command.gd — 运行时命令

**类名**: `RuntimeCommand`  
**继承**: `RefCounted`  
**角色**: 跨 Runtime 异步命令的数据载体

**功能**:
- 定义 6 种目标 Runtime：`COMBAT / WORLD / SIMULATION / UI / SAVE / ALL`
- 携带 `type / source / target / payload / timestamp`
- 提供 `static create()` 快捷构造

---

### 3.10 debug/combat_debugger.gd — 战斗调试器

**功能**: 
- 全局 trace 开关 (`enabled: bool`)
- `begin(label)` → 创建 CombatTrace → `store(trace)` → 关闭
- `active()` → 获取当前活跃 trace
- 最多存储 50 条 trace

### 3.11 debug/combat_debug_ui.gd — 调试 UI

**功能**: 按 `~` 键切换显示，展示最近的 CombatTrace 列表和详情

### 3.12 debug/combat_trace.gd / combat_trace_event.gd

**功能**: 
- `CombatTrace` — 单次技能/命中的完整追踪记录（阶段转移、Modifier 变化、事件发射、DOT tick）
- `CombatTraceEvent` — 单个追踪条目（category + phase + message + before/after 值）

---

## 4. 玩法层 (gameplay/)

### 4.1 action/player_action.gd — Action Layer

**类名**: `PlayerAction`  
**功能**: 将原始 Input 转换为意图（Action）：
- 6 种类型：`MOVE / MELEE / DODGE / CAST_PRESS / CAST_RELEASE / INTERACT`
- 纯数据类，不包含决策逻辑
- `CAST_PRESS/RELEASE` 支持左/右手 + 4 快捷键槽位

---

### 4.2 abilities/ — 技能系统

#### 4.2.1 data/skill_data.gd — 技能数据 Resource

**类名**: `SkillData`  
**继承**: `Resource`

**功能**: 定义技能的所有配置字段（纯数据，零逻辑）：
- **类型枚举**: `PROJECTILE / BUFF / AOE / DASH`
- **核心标识**: `id / display_name / icon / description`
- **标签系统**: `tags: Array[String]`（供 Modifier/Condition 匹配）
- **消耗与冷却**: `mp_cost / cooldown`
- **伤害**: `damage / damage_scaling`
- **Archetype**: `archetype: String`（`"linear_projectile"` / `"persistent_aoe"`）
- **视觉**: `visual: ProjectileVisualData` / `aoe_visual: AOEVisualData`
- **专用字段**: `projectile_speed / cast_distance / buff_resource / aoe_radius / dash_distance / dash_speed`

**设计原则**: Scene = 行为 Archetype，与技能数量解耦。200+ 技能只需 <10 个 Scene。

#### 4.2.2 runtime/skill_executor.gd — 核心执行器

**类名**: `SkillExecutor`  
**继承**: `Node`

**功能**: 战斗技能的核心执行引擎：
- **四阶段 Modifier 管线**: `FLAT → MULTIPLY → OVERRIDE → FINAL`
- `modifiers_by_stage: Dictionary` 按阶段分桶，同阶段内按 priority 排序
- `resolve_damage(skill, ctx)` → 走完整管线返回最终伤害值
- `execute(skill, ctx)` → 按技能类型分发：
  - `_execute_projectile()` → 实例化 archetype Scene + setup
  - `_execute_buff()` → 调用 BuffManager.apply_buff()
  - `_execute_aoe()` → 实例化 persistent_aoe Scene
  - `_execute_dash()` → Tween 位移 + 可选 Buff
- **阶段序列**: `IDLE → MODIFIER → EFFECT → EVENT → POST → IDLE`
- **Archetype Scene 映射**: `_ARCHETYPE_SCENES` 字典

#### 4.2.3 runtime/skill_instance.gd — 技能运行时包装

**类名**: `SkillInstance`  
**继承**: `RefCounted`

**功能**: 包装 SkillData + 运行时冷却状态：
- `bind(skill)` 绑定数据
- `trigger_cooldown()` / `is_ready()` / `tick(delta)` 冷却管理
- `get_remaining_ratio()` 返回冷却进度

#### 4.2.4 runtime/cast_context.gd — 施法上下文

**类名**: `CastContext`  
**继承**: `RefCounted`

**功能**: 纯数据类，SkillExecutor 的输入参数：
- `caster / target / direction / target_position / world / skill`
- 三个快捷构造：`simple()` / `targeted()` / `at_position()`

#### 4.2.5 runtime/damage_context.gd — 伤害上下文

**类名**: `DamageContext`  
**继承**: `RefCounted`

**功能**: Modifier 管线中流转的伤害数据:
- `base_damage / final_damage / tags / meta / caster / target / skill`
- `from_cast()` 从 SkillData + CastContext 构造

#### 4.2.6 runtime/projectile.gd — 投射物运行时

**类名**: `Projectile`  
**继承**: `Area2D`

**功能**:
- `setup(skill, caster, direction)` → 注入伤害/速度/视觉/标签
- `_physics_process()` → 直线移动 + 超时自毁
- `_on_body_entered()` → 命中时调用 `CombatExecutor.report_hit()` → `target.take_damage()`
- AoE 命中多目标时共享一个 CombatTrace，超时时统一 store

#### 4.2.7 manager/skill_manager.gd — 技能管理器

**类名**: `SkillManager`  
**继承**: `Node`

**功能**:
- 左手/右手 + 4 快捷键槽位管理
- `equip_hand()` / `equip_slot()` / `unequip_hand()` / `unequip_slot()`
- `apply_loadout(loadout)` 批量装备
- `use_hand()` / `use_slot()` → MP/冷却验证 → 委托 SkillExecutor 执行
- 冷却跟踪：`_cooldowns` 字典 + `_process()` 每帧递减

#### 4.2.8 registry/skill_pool.gd — 技能池

**类名**: `SkillPool`  
**继承**: `Resource`

**功能**:
- 维护 `skill_id → SkillData` 的索引
- `add_skill()` / `get_skill()` / `has_skill()` / `build()` 重建索引

#### 4.2.9 loadout/skill_loadout.gd — 装备表

**类名**: `SkillLoadout`  
**继承**: `Resource`

**功能**:
- `left_hand / right_hand: String`（技能 ID）
- `slots: Array[String]`（4 快捷键）
- `static create()` 快捷构造

#### 4.2.10 effect_graph/ — 效果图系统

**核心概念**: 节点树——在当前 tick 内描述"做什么"，不拥有时间控制权。

| 节点 | 功能 |
|------|------|
| `EffectGraph` | 持有 root 节点，`run(event)` 启动执行 |
| `SequenceNode` | 依次执行子节点 |
| `BranchNode` | `if condition → true_branch else false_branch` |
| `ConditionGateNode` | 条件不满足 → 整条分支跳过 |
| `CallableNode` | 执行 Callable |
| `LogNode` | 调试日志输出 |
| `EmptyNode` | 终端/占位 |
| `EffectGraphContext` | 执行上下文（event + source/target + data） |

**设计原则**: 禁止 Loop/Async/Parallel/Delay 节点——时间控制权属于 Executor。

#### 4.2.11 visuals/ — 视觉数据 Resource

- `ProjectileVisualData` — 投射物视觉配置（texture/color/scale/speed/sfx）
- `AOEVisualData` — AoE 视觉配置（color/scale/radius/lifetime/sfx）

---

### 4.3 combat/ — 战斗核心系统

#### 4.3.1 combat_executor.gd — 唯一控制流入口 ⭐

**类名**: `CombatExecutor`  
**继承**: `Node`  
**角色**: 战斗系统的核心——所有 HP 修改、事件发射、阶段切换的唯一入口

**功能**:
- **静态单例**: `static var instance`
- **事件发射**: 所有 `report_*()` 方法（`report_hit / report_damage / report_kill / report_cast / report_bonus_damage / report_exp_bonus / report_heal / report_status_applied / report_status_removed`）
- **阶段机**: `IDLE → INPUT → CONDITION → MODIFIER → EFFECT → EVENT → POST → IDLE`
- **防火墙**: `MAX_EVENT_DEPTH=3`, `MAX_CHAIN_LENGTH=5`
- **阶段门控**: 事件只能在指定阶段发射
- **TriggeredEffect 冷却**: `_trigger_cooldowns` 字典集中管理

**CONTRACT 1 (铁律)**:
```
✅ 合法: CombatExecutor.report_hit() / report_damage() / report_kill()
❌ 禁止: body.take_damage(x) 裸调 / CombatEventBus.emit() 裸调
```

#### 4.3.2 combat_phase.gd — 战斗阶段锁

**类名**: `CombatPhase`  
**继承**: `RefCounted`

**功能**:
- 定义 7 个执行阶段枚举
- `is_valid_transition(from, to)` — 允许向前跳跃，禁止倒退
- `allowed_phases_for_event(type)` — 事件类型→允许阶段映射

#### 4.3.3 triggered_effect.gd — 触发式效果

**类名**: `TriggeredEffect`  
**继承**: `Resource`

**功能**:
- 事件 + 条件 + 效果的完整闭环
- 支持两种模式：
  1. **简单模式**: `conditions[] + _execute()`
  2. **图模式**: `graph: EffectGraph`
- `register()` → 调用 `CombatEventBus.subscribe()`
- 递归守卫：`max_recursion` 控制链式触发深度
- 冷却委托给 `CombatExecutor.check_trigger_cooldown()`

#### 4.3.4 conditions/ — 条件系统

| 文件 | 功能 |
|------|------|
| `condition.gd` | 基类，`check(ctx) → bool` |
| `tag_condition.gd` | 检查目标/源是否有指定标签 |
| `skill_tag_condition.gd` | 检查技能标签（如 `"fire"`） |
| `status_condition.gd` | 检查目标是否有指定状态 |
| `buff_name_condition.gd` | 检查目标是否有指定 Buff |
| `low_hp_condition.gd` | 检查目标 HP 是否低于阈值 |
| `target_type_condition.gd` | 检查目标类型（is_boss/is_player/is_enemy） |

**CONTRACT 3**: Condition 必须无副作用，只能返回 `bool`。

#### 4.3.5 modifiers/ — 伤害管线

| 文件 | 功能 | 阶段 |
|------|------|------|
| `damage_modifier.gd` | 基类：四阶段 + priority + tags 控制 | — |
| `flat_bonus_modifier.gd` | 固定加成（+10） | FLAT |
| `stat_scaling_modifier.gd` | 属性缩放（智力→魔法伤害） | FLAT |
| `tag_multiplier_modifier.gd` | 标签倍率（火焰+20%） | MULTIPLY |

**CONTRACT 2**: Modifier 必须是纯函数——只改 `ctx.final_damage/tags/meta`，不产生副作用。

#### 4.3.6 响应式效果

| 文件 | 触发事件 | 效果 |
|------|---------|------|
| `on_hit_apply_status.gd` | ON_HIT + fire tag | 施加 burning 状态 |
| `on_hit_fire_bonus.gd` | ON_HIT + fire tag | 火焰 bonus 伤害 |
| `on_kill_bonus_exp.gd` | ON_KILL | 额外经验值 |
| `on_ice_armor_expire.gd` | ON_STATUS_REMOVED (冰甲) | 触发冰爆 |

---

### 4.4 status/ — 状态/Buff 系统

#### 4.4.1 buff.gd — Buff Resource

**类名**: `Buff`  
**继承**: `Resource`

**功能**:
- **核心标识**: `display_name / status_id / icon`
- **生命周期**: `duration`（0=永久）/ `tick_interval`（0=无 tick）
- **叠加规则**: `REFRESH`（刷新）/ `INTENSITY`（层数）/ `INDEPENDENT`（共存）
- **属性修改**: `stat_modifiers: Dictionary / stat_multipliers: Dictionary`
- **Tick 效果**: `tick_damage / tick_heal / tick_damage_scaling`
- **速度修正**: `speed_multiplier`（<1 = 减速）
- **应用/移除**: `apply_to(entity)` / `remove_from(entity)` → StatsComponent / HealthComponent / CombatComponent / move_speed
- **叠加层数**: `max_stacks`

#### 4.4.2 buff_manager.gd — Buff 管理器

**类名**: `BuffManager`  
**继承**: `Node`

**功能**:
- 挂载在 Player/Enemy 实例上
- `apply_buff(buff)` — 按 stack_behavior 处理叠加 + 施加
- `remove_buff(buff)` — 移除 + 还原属性 + 发射事件
- `_process(delta)` — 倒计时过期 + 1秒 tick
- DOT/HOT 每 tick 执行
- 事件发射严格顺序：trace record → `report_status_removed`（防事件链污染）

---

### 4.5 inventory/ — 背包/装备系统

#### 4.5.1 inventory.gd — 背包 Resource

**类名**: `Inventory`  
**继承**: `Resource`

**功能**:
- 固定容量的物品槽位数组
- `add_item(item, qty)` — 优先堆叠到已有槽位
- `remove_item(item, qty)` — 从后往前移除
- `get_slot(idx)` / `set_slot(idx, item, qty)` 槽位读写

#### 4.5.2 equipment_manager.gd — 装备管理器

**类名**: `EquipmentManager`  
**继承**: `Node`

**功能**:
- 7 个装备槽位：`Head / Chest / Legs / Feet / Hands / LeftHand / RightHand`
- `equip(equipment)` / `unequip(slot)` → 自动通过 BuffManager 施加/移除属性
- 装备属性以 `duration=0`（永久）的 Buff 形式施加

#### 4.5.3 data/ — 物品/装备数据 Resource

- `ItemData` — 物品基类（display_name / icon / stackable / max_stack / description）
- `EquipmentData` — 装备数据（slot_type + stat_modifiers + stat_multipliers）

---

### 4.6 quest/ — 任务系统

#### 4.6.1 data/ — 任务数据

- **QuestData**: `quest_id / title / description / stages: Array[QuestStageData]`
- **QuestStageData**: `stage_id / objectives: Array[QuestObjective] / auto_complete`
- **QuestObjective** (基类): `required_count / track_from_start / current` → `on_event(ev)` 子类覆写

#### 4.6.2 objectives/ — 目标类型

- **KillObjective**: `target_tag`（如 `"enemy"`）→ 监听 ON_KILL 匹配 target 标签
- **InteractObjective**: `target_tag`（如 `"villager"` / `"chest"`）→ 监听 ON_INTERACT 匹配目标标签

#### 4.6.3 runtime/ — 任务运行时

- **QuestManager**: 
  - `start_quest(data)` → 创建 QuestRuntime
  - 订阅 `ON_KILL / ON_INTERACT` → 转发给所有活跃 quest
  - 检测完成 → 移入 `_completed_quests`
- **QuestRuntime**:
  - 持有 QuestData（只读）
  - `on_event(ev)` → 当前阶段所有目标 + 后续阶段 `track_from_start=true` 的目标
  - 阶段推进：所有目标完成后自动进入下一阶段
  - 所有阶段完成 → `COMPLETED`

#### 4.6.4 ui/quest_tracker.gd — 任务追踪 UI

**功能**: 显示当前活跃任务的阶段和进度（QuestManager 数据驱动）

---

### 4.7 interaction/ — 世界交互系统

#### 4.7.1 simulation_runtime.gd — 统一调度器

**类名**: `SimulationRuntime`  
**继承**: `Node`

**功能**:
- 统一调度子模块 tick 顺序：`Surface → Propagation → Respawn`
- 每 0.5s 执行 `_surface_manager.tick_entity_surface()`（实体-表面低频交互）
- `_register_default_reactions()` — 注册 7 条默认 SurfaceReaction：
  - `oiled + fire → burning (spread)`
  - `wet + ice → frozen`
  - `wet + fire → dry`
  - `burning + ice → dry`
  - `burning + wet → dry`
  - `dry + fire → burning`
  - `dry + ice → frozen`

#### 4.7.2 surface_manager.gd — 表面系统入口

**类名**: `SurfaceManager`  
**继承**: `Node`

**功能**:
- `register_reaction(rule)` — 注册 ReactionRule（按 required_state 索引）
- `apply_tags(cell, tags, source)` — 核心：根据当前格子状态 + 技能标签匹配规则
- `get_entity_buffs(cell)` — 映射表面状态→实体 Buff 路径
- `tick_entity_surface()` — 低频 tick：对站在活跃表面的实体施加对应 Buff

**CONTRACT 2**: Surface 只声明状态，不产生伤害。伤害由 InteractionSystem → CombatExecutor 产生。

#### 4.7.3 surface_reaction.gd — 反应规则 Resource

**字段**: `rule_id / required_state / required_tags / result_state / result_duration / spread_to_neighbors / spread_tags / spread_damage / entity_status_path`

#### 4.7.4 子调度器

- **SurfaceScheduler**: 管理活跃的表面单元格（cell → {state, remaining, source}）
- **PropagationScheduler**: BFS 传播队列（MAX_DEPTH=4, MAX_JOBS_PER_TICK=8, DECAY=0.5）
- **RespawnScheduler**: 可破坏物重生倒计时

---

## 5. 实体层 (entities/)

### 5.1 components/ — 共享组件

#### 5.1.1 health_component.gd

**类名**: `HealthComponent`  
**继承**: `Node`

**功能**: HP 系统核心——挂载到 Player/Enemy：
- `max_hp / invincible_duration / regen_delay / regen_rate`
- `take_damage(amount)` → HP 减少 → 无敌帧 → `ON_DAMAGE` → `ON_KILL`（HP≤0）
- `heal(amount)` → HP 增加
- 死亡时自动禁用碰撞体
- 脱战自回（`_process(delta)` 累计 → 回血）

#### 5.1.2 combat_component.gd

**类名**: `CombatComponent`  
**继承**: `Node`

**功能**: 近战攻击组件：
- `perform_melee_attack()` → 激活 Hitbox 0.15s
- `_on_attack_hit(body)` / `_on_attack_hit_area(area)` → `CombatExecutor.report_hit()` → `target.take_damage()`
- 命中走 CombatDebugger trace 记录

#### 5.1.3 mana_component.gd

**类名**: `ManaComponent`  
**继承**: `Node`

**功能**: MP 系统：
- `max_mp / mp_regen_rate / mp_regen_delay`
- `use_mp(amount) → bool` / `restore_mp(amount)`
- 施法后延迟回复（`_process`累计）

#### 5.1.4 stats_component.gd

**类名**: `StatsComponent`  
**继承**: `Node`

**功能**: 主属性系统：
- 4 主属性：`strength / intelligence / agility / endurance`
- 派生属性自动计算：`max_hp_bonus / max_mana / physical_damage / magic_damage / move_speed_bonus`
- `modify_stat(name, amount)` → 重新计算
- `add_experience(amount)` → 自动升级（`exp_to_next *= 1.5`，每级 3 属性点）
- `spend_attribute_point(stat)` → 消耗属性点

---

### 5.2 player/ — 玩家

#### 5.2.1 player.gd

**类名**: `Player`  
**继承**: `CharacterBody2D`

**功能**: 玩家主协调器（最复杂的文件之一，~550 行）：
- **移动**: `base_move_speed` + `stats_component.move_speed_bonus`
- **组件引用**: `HealthComponent / CombatComponent / ManaComponent / StatsComponent / SkillManager / EquipmentManager`
- **技能初始化** (`_setup_skills`):
  - 加载 `player_skill_pool.tres`
  - 确保 6 个技能注册（fireball/ice_armor/flame_storm/shadow_step/ice_explosion/shadow_bolt）
  - 构建 SkillPool 索引
  - 应用 Loadout（左手=ice_armor, 右手=fireball, slots=flame_storm/shadow_step/ice_explosion）
  - 配置 Modifier 管线
- **事件总线初始化** (`_setup_event_bus`):
  - 创建 `CombatExecutor` 单例
  - 创建 `CombatEventBus` 单例
  - 注册 TriggeredEffect（ON_KILL bonus exp / ice armor expire / fire status / EffectGraph demo）
  - 创建 `CombatDebugger` + `CombatDebugUI`
  - 创建 `WorldTime`
  - 创建 `QuestManager` + `QuestTracker`
- **Action Layer** (`poll_actions`):
  - WASD → MOVE
  - Space → DODGE
  - 左键 + 无左手技能 → MELEE
  - 左右键按下/释放 → CAST_PRESS / CAST_RELEASE
  - E → INTERACT
- **Action 路由** (`try_action`):
  - MELEE → `state_machine.transition_to("attack")`
  - DODGE → `state_machine.transition_to("dodge")`
  - INTERACT → 扫描最近可交互节点 → `Interactable.interact()`
  - CAST_PRESS → 显示瞄准指示器
  - CAST_RELEASE → 施放技能 → `state_machine.transition_to("skill")`
- **瞄准系统**:
  - `show_aim(source, skill)` — 按技能类型显示不同瞄准指示器
  - `hide_aim()` — 隐藏指示器
  - 滚轮 → `cancel_aim`

#### 5.2.2 player states/ — 玩家 FSM 状态

| 状态 | 功能 |
|------|------|
| `idle.gd` | 待机：无输入时自动播放 idle 动画 |
| `move.gd` | 移动：WASD 驱动 `velocity`，`move_and_slide()` |
| `attack.gd` | 攻击：调用 `perform_melee_attack()`，动画驱动命中窗口 |
| `dodge.gd` | 闪避：向移动方向（或默认前方）Tween 快速位移 + 无敌帧 |
| `skill.gd` | 技能：等待 `CAST_RELEASE` → 触发施放 |

**核心设计**: 每个 State 在 `physics_update()` 中调用 `player.poll_actions()` → 产生 Action → `player.try_action(action)`。State 不决策，只执行。

---

### 5.3 enemy/ — 敌人

#### 5.3.1 enemy.gd

**类名**: `Enemy`  
**继承**: `CharacterBody2D`

**功能**:
- **AI 驱动**: godot_state_charts 插件 → StateChart（`Brain/Idle → Chase → Attack`）
- **三种预设**: 哨兵🟢(敏捷) / 士兵🔴(均衡) / 坦克🟣(高力量耐力)
- **预设属性**: `PRESET_STATS` 为每种类型设定 STR/INT/AGI/END
- **属性系统**: 拥有 `StatsComponent/HealthComponent/SkillManager/BuffManager`
- **技能**: 默认装备 `shadow_bolt_data.tres` 作为右手技能
- **AI 逻辑**:
  - `Idle._physics` → 检测玩家距离 → `player_detected`
  - `Chase._physics` → 向玩家移动 + 远程施法 + 范围内 → `player_in_range`
  - `Attack._physics` → 每 `attack_cooldown` 执行 `_do_melee_attack()`
- **近战**: 通过 `CombatExecutor.report_hit()` + `begin_hit_sequence()/end_hit_sequence()`
- **死亡**: `CombatExecutor.report_exp_bonus()` → 50% 概率掉落血/魔包 → `queue_free()`

---

### 5.4 npc/ — NPC

#### 5.4.1 npc.gd

**类名**: `NPC`  
**继承**: `CharacterBody2D`

**功能**: NPC 基类，挂载 `StatsComponent`，设置视觉颜色/缩放。

---

### 5.5 pickups/ — 拾取物

#### 5.5.1 pickup.gd — 拾取物基类

**类名**: `Pickup`  
**继承**: `Area2D`

**功能**:
- `_on_body_entered(body)` — 验证 `player` group → `_on_collected(player)` → `queue_free()`
- 碰撞层: `layer=ITEM(512), mask=ACTOR(2)`
- 无形状时自动创建 `CircleShape2D(radius=16)`

#### 5.5.2 health_pickup.gd / mana_pickup.gd

**功能**: 子类覆写 `_on_collected(player)` → `player.heal(value)` / `player.restore_mp(value)`

---

## 6. 世界层 (world/)

### 6.1 world_runtime.gd — 世界运行时入口

**类名**: `WorldRuntime`  
**继承**: `Node`

**功能**:
- 创建并持有 `WorldSpatialIndex` + `WorldStateManager`
- `register_object(obj)` → 空间索引 + 状态管理器注册
- `unregister_object(obj)` → 空间索引注销
- 订阅 CommandBus：`DESTROYED / RESPAWN_REQUEST / CHUNK_LOAD_REQUEST`

---

### 6.2 spatial/world_spatial_index.gd — 空间索引

**类名**: `WorldSpatialIndex`  
**继承**: `RefCounted`

**功能**: 统一空间查询的唯一入口：
- 固定网格分桶 (`CELL_SIZE=64`)
- `register(obj)` / `unregister(obj)` / `update_position()`
- `query_radius(pos, radius)` → 半径查询
- `query_cell(cell)` → 单元格查询
- `query_tags(pos, radius, tags)` → 标签过滤查询
- 上限：`MAX_QUERY_RESULTS=32`

---

### 6.3 state/world_state_manager.gd — 世界状态管理器

**类名**: `WorldStateManager`  
**继承**: `Node`

**功能**:
- `_object_states: Dictionary` — 真实世界状态（SceneTree 只是表现层）
- 生命周期：`INTACT → DESTROYED → RESPAWNING → INTACT`
- `tick_respawn(delta)` — 重生倒计时

---

### 6.4 object/ — 世界物体体系

#### 6.4.1 map_object.gd — 基类

**类名**: `MapObject`  
**继承**: `Node2D`

**功能**:
- 四个接口：`Damageable / Interactable / Persistent / Taggable`
- `take_damage(amount)` → HP 减少 → HP≤0 → `_on_destroyed()`
- `_on_destroyed()` → 注销空间索引 → 破坏特效 → 掉落物 → AOE 伤害 → 表面生成 → 重生倒计时 → 移除碰撞
- `_trigger_destruction_aoe()` → `WorldSpatialIndex.query_radius()` → `CombatExecutor.report_hit()` 批量命中
- `_spawn_destruction_surface()` → `SurfaceManager.force_set_surface()` 在半径内生成表面状态
- 视觉状态：INTACT=DAMAGED=可见, DESTROYED=RESPAWNING=不可见

#### 6.4.2 map_object_data.gd — 配置 Resource

**字段**: `display_name / max_hp / respawn_time / tags / is_interactable / blocks_path / destruction_loot_scene / destruction_effect_scene / destruction_radius / destruction_aoe_damage / destruction_aoe_tags / destruction_surface / destruction_surface_radius`

#### 6.4.3 interactable.gd / signal_receiver.gd — 接口

- **Interactable**: `interact(actor)` → 回调模式
- **SignalReceiver**: `receive_signal(signal_id)` → 标准信号 `activate/deactivate/toggle`

#### 6.4.4 已实现的 WorldObject 子类

| 类型 | 基类+接口 | 核心行为 |
|------|----------|---------|
| **Switch** (`switch.gd`) | Node2D + Interactable | 按E切换 → 扫描兄弟节点 SignalReceiver |
| **Door** (`door.gd`) | MapObject + SignalReceiver | 开关驱动开/关，可破坏 |
| **Chest** (`chest.gd`) | MapObject + Interactable | 打开 → LootTable 随机掉落，一次性 |
| **SpikeTrap** (`spike_trap.gd`) | Area2D | 周期性 `CombatExecutor.report_hit()` |
| **PressurePlate** (`pressure_plate.gd`) | Area2D | body进入/离开 → 自动发信号 |
| **DialogueNPC** (`npc.gd`) | Node2D + Interactable + Schedule | 对话 + 日程驱动日常行为 |
| **Portal** (`portal.gd`) | Area2D | 玩家进入 → 切换场景 |

#### 6.4.5 可破坏物（MapObject 直接使用）

| 场景 | 数据 | 特性 |
|------|------|------|
| `oil_barrel.tscn` | `oil_barrel_data.tres` | 破坏AOE(radius=150, damage=15, fire tags) + 表面生成(oiled, r=120) |
| `breakable_wall.tscn` | `breakable_wall_data.tres` | 纯阻挡 |
| `ice_wall.tscn` | `ice_wall_data.tres` | 可破坏冰墙 |
| `wooden_crate.tscn` | `wooden_crate_data.tres` | 木箱 |
| `wooden_fence.tscn` | `wooden_fence_data.tres` | 木栅栏 |

---

### 6.5 npcs/ — NPC 日程系统

#### 6.5.1 npc_brain.gd — 决策层

**类名**: `NPCBrain`  
**继承**: `Node`

**功能**:
- `tick(delta)` → 读取 `WorldTime.get_hour()` → `schedule.get_entry_for_hour(hour)` → 切换行为
- `_execute_entry(entry)` → `"move"` → 创建 `MoveToTask` 导航到 Marker
- 五层架构中的决策层：只读 Schedule，不移动、不播动画

#### 6.5.2 npc_schedule.gd / schedule_entry.gd — 日程数据

- **NPCSchedule**: `entries: Array[ScheduleEntry]` — `get_entry_for_hour(hour)` 支持跨午夜
- **ScheduleEntry**: `start_hour / end_hour / target_marker / action_type`（"move"/"idle"/"wander"）

#### 6.5.3 move_to_task.gd — 移动任务

**类名**: `MoveToTask`  
**继承**: `Node`

**功能**: `tick(delta)` — 优先 NavigationAgent2D 寻路，无 navmesh 时直线移动到目标 Marker。

---

### 6.6 time/world_time.gd — 世界时间

**类名**: `WorldTime`  
**继承**: `Node`

**功能**:
- `static var instance` 全局单例
- `time_scale = 60`（1 秒现实 = 1 分钟游戏时间）
- `_process(delta)` → 推进 `hour`，24h 循环
- `get_hour()` / `is_night()`（< 6:00 或 > 20:00）

---

### 6.7 markers/ — 地图锚点

- **WorldMarker**: `marker_id + tags` — `_ready()` 自动注册到 MarkerRegistry
- **MarkerRegistry**: `static _positions: Dictionary` — `marker_id → global_position` 全局映射

---

## 7. 内容层 (content/)

纯数据 `.tres` 文件，零运行时逻辑：

- `content/items/player_inventory.tres` — 玩家背包实例
- `content/items/examples/` — 铁头盔/皮甲/铁靴 示例装备
- `content/quests/kill_enemies_quest.tres` — 示例任务
- `content/visuals/` — 投射物/AoE 视觉配置（fire/ice/shadow）

---

## 8. UI层 (ui/)

### 8.1 hud.gd / hud.tscn — HUD 主界面

**类名**: `HUD`  
**继承**: `CanvasLayer`

**功能**:
- 程序化构建整个 UI 布局（HP条、MP条、技能栏、属性摘要）
- 连接到 Player 信号：`health_changed / mp_changed / died`
- 连接到 StatsComponent 信号：`stat_changed / leveled_up`
- 死亡画面：全屏黑色半透明 + "Reload" 点击重载
- 技能栏通过 SkillBar 组件显示

### 8.2 inventory_panel.gd / inventory_panel.tscn — 背包面板

**类名**: `InventoryPanel`  
**继承**: `CanvasLayer`

**功能**:
- I 键切换打开/关闭
- 网格背包（5 列）+ 纸娃娃装备面板
- 7 个装备槽位按钮（替换场景中普通 Button 为 SlotButton）
- 拖拽支持：背包↔装备、装备↔装备、背包↔背包
- 类型校验：装备拖到装备槽时检查 slot_type 兼容性

### 8.3 level_up_ui.gd / level_up_ui.tscn — 升级 UI

**类名**: `LevelUpUI`  
**继承**: `CanvasLayer`

**功能**:
- 升级时弹出：闪光特效 → 面板淡入
- 4 属性行（+/- 按钮 + 预览）
- 派生属性预览（HP加成/物理伤害/魔法伤害/移速）
- 确认按钮 → 应用分配 → 关闭

### 8.4 skill_bar.gd — 技能栏组件

**类名**: `SkillBar`  
**继承**: `HBoxContainer`

**功能**:
- 左手 [L] · 右手 [R] · 槽1-4
- CD 遮罩动画 + 秒数显示
- SkillManager 信号驱动刷新

### 8.5 slot_button.gd — 拖拽槽位按钮

**功能**: 自定义 Button 支持拖拽（INVENTORY/EQUIPMENT 两种角色），`slot_dropped` 信号携带源数据。

### 8.6 skill_pool_ui.gd — 技能池 UI

**功能**: 展示 SkillPool 所有可用技能，支持拖拽到 Loadout。

---

## 9. 文档层 (docs/)

项目拥有**极为完善的架构文档体系**：

| 文档 | 角色 | 核心内容 |
|------|------|---------|
| `ARCHITECTURE.md` | 宪法 | 六层边界 + NPC 五层 + Enemy/NPC 分离 + FSM 铁律 + 停止线 |
| `COMBAT_CONTRACTS.md` | 战斗法典 | 12 条契约（CombatExecutor/Modifier/Condition/EffectGraph/EventBus/阶段机/标签/伤害链路/防火墙/Buff生命周期/AoE Trace） |
| `WORLD_CONTRACTS.md` | 世界法典 | 9 条契约（MapObject 接口/HP 唯一入口/表面系统/传播/状态机/空间索引/WorldState/密度/防火墙） |
| `RUNTIME_TOPOLOGY.md` | 运行时宪法 | 五大 Runtime 边界 + CommandBus + 三级激活 + 验证标准 |
| `PHYSICS_LAYERS.md` | 物理标准 | 11 层定义 + 各节点标准配置 + 迁移指南 |
| `skill_architecture.md` | 技能架构 | Scene ≠ 技能身份 + Entity Archetype 收敛 + 数据驱动 |

---

## 10. 测试层 (tests/)

- `test_gameplay.gd` — **SceneTree 功能测试**：加载 main.tscn → 验证 Player/StateMachine/States/InputMap 完整性
- `test_validation.gd` — 验证测试

---

## 11. 工具层 (tools/)

一组**迁移/修复工具脚本**，用于批量修改场景和资源文件：
- `add_physics_body.gd` — 为节点添加物理碰撞体
- `fix_collision_layers.gd` — 修复碰撞层设置
- `fix_hitbox_mask.gd` — 修复攻击盒掩码
- `fix_paths.gd` / `fix_all_paths.gd` — 修复资源路径引用
- `fix_player_instance.gd` — 修复玩家实例化
- `fix_portal_paths.gd` — 修复传送门路径
- `copy_migration.gd` — 文件迁移
- `create_stubs.gd` — 创建存根文件

---

## 12. 根目录文件

| 文件 | 作用 |
|------|------|
| `main.tscn` | 项目主场景入口 |
| `project.godot` | 项目配置：输入映射(WASD/鼠标/数字键)、自动加载(DialogueManager)、插件列表、渲染(Jolt Physics+D3D12) |
| `icon.svg` / `icon.png` | 项目图标 |
| `LICENSE` | MIT 许可证 |
| `README.md` / `README.ru.md` | Importality 插件说明（无关本项目核心功能） |

---

## 13. 架构评估与迭代建议

### 13.0 Runtime Sovereignty（运行时主权）声明

> 经架构评审确认：本项目已进入 **Runtime Sovereignty** 阶段。
> 
> 这意味着：
> - **CombatRuntime** 只负责计算，不控制世界
> - **WorldRuntime** 只维护状态一致性，不计算伤害
> - **SimulationRuntime** 统一调度，各系统禁止独立 `_process()`
> - **CombatExecutor** 是 HP 修改的唯一入口
> - **WorldStateManager** 持有真实世界状态（SceneTree 只是表现层）
>
> 这使得未来可以走向：联机、Chunk Streaming、Dedicated Server、Deterministic Replay、ECS 化——**路没有被堵死**。

### 13.01 三大警戒线（UNBREAKABLE）

| 警戒线 | 后果 |
|--------|------|
| EffectGraph 获得时间控制权 | 变成"第二个 Runtime"，系统失控 |
| Surface System 走元素组合 | 指数爆炸，不可维护 |
| CommandBus 退化为上帝总线 | 隐式调用地狱，事件流不可追踪 |

---

### 13.1 架构优势

| 优势 | 说明 |
|------|------|
| ✅ **契约体系完善** | 12 + 9 条契约覆盖战斗和世界全部关键路径 |
| ✅ **数据驱动** | 技能/物品/Buff/任务全部 .tres 配置，设计师友好 |
| ✅ **单一职责** | CombatExecutor 唯一写入口，事件单向流动 |
| ✅ **Archetype 收敛** | 2 个 Scene 支持 200+ 技能 |
| ✅ **EffectGraph** | 可组合的效果节点树，扩展性强 |
| ✅ **WorldObject 统一** | MapObject 基类 + 4 接口，7 种物体均继承 |
| ✅ **NPC 五层架构** | WorldTime→Brain→Task→Action→FSM 分离清晰 |
| ✅ **文档超群** | 6 份详实文档覆盖所有架构层面 |

### 13.2 当前核心问题：两套世界共存 🔴

> **经架构评审确认（2026-07-14）**：当前最危险的架构债务不是"缺系统"，而是**两套世界共存**。

```
纸上架构（正确）:  GameRuntime → CommandBus → Combat/World/Simulation/UI/Save
实际代码（残留）:  Node → 直接调用 Node（SceneTree 穿透 Runtime Boundary）
```

**证据**: `map_object.gd` 硬编码路径 `Game/GameRuntime/WorldRuntime` — SceneTree 层级成为 Runtime 查找方式。

**后果**: 当 propagation + surface + NPC schedule + quest 全部开始互调时，Runtime Boundary 被穿透会导致系统缠死。规模小时共存，规模一大架构分裂。

**解决方向**: 「Runtime 化迁移」三步走（见 §13.3）。

---

### 13.2.1 具体问题清单

| 问题 | 严重程度 | 说明 |
|------|---------|------|
| 🔴 **两套世界共存** | 致命 | 纸上 Runtime 架构 vs 实际直接调用并存 |
| 🔴 **Runtime 未夺权** | 致命 | GameRuntime 计划为 autoload 但未真正成为 Runtime Root |
| ⚠️ **物理层未迁移** | 中 | PHYSICS_LAYERS.md 定义了 11 层标准，但代码中仍用默认值 |
| ⚠️ **CommandBus 未启用** | 中 | 设计完整但 Runtime 间仍走直接调用 |
| ⚠️ **WorldRuntime 穿透** | 中 | `map_object.gd` 硬编码路径查找 WorldRuntime |
| ⚠️ **Tick 分散** | 中 | BuffManager/NPCBrain 等各自独立 `_process()`，未归 SimulationRuntime 统一调度 |
| ⚠️ **README 偏差** | 低 | README.md 是 Importality 插件说明 |
| ⚠️ **部分文件重复** | 低 | `world/portal.tscn` / `world/portals/portal.tscn` 两处存在 |

### 13.3 推荐迭代路线（按优先级）— 经架构评审重新校准

> **评审结论**: Action Layer 统一是当前最关键的架构缺口，从 P2 提升至 P1。
> 完成后 Player/Enemy/NPC/Boss 将共享统一 Action 体系，仅 Brain/Task/Available Actions 不同。

#### 🔴 P0 — Runtime 化迁移（真正的 P1，3-5 天）

> **这是整个项目真正的分水岭：从 Node Project → Runtime Project。**

**Step 1 — GameRuntime 成为 Runtime Root**:
- GameRuntime 设为 autoload
- 将 CombatRuntime / WorldRuntime / SimulationRuntime / CommandBus 全部挂入
- 形成树：`GameRuntime → [CommandBus, CombatRuntime, WorldRuntime, SimulationRuntime, UIRuntime]`

**Step 2 — 禁止 Runtime 直接调用，路由到 CommandBus**:
- `map_object.gd` 不再硬编码路径查找 WorldRuntime → 改为 `CommandBus.emit(SURFACE_CHANGE_REQUEST)`
- `HealthComponent._emit_damage_event()` 不再直接调 CombatEventBus → 通过 CombatExecutor（已做）
- `MapObject._trigger_destruction_aoe()` 中的 WorldSpatialIndex 直接查询 → 改为 CommandBus 模式
- `SurfaceManager.instance` 全局单例模式 → 改为通过 SimulationRuntime 访问

**Step 3 — SimulationRuntime 统一接管 Tick**:
- BuffManager._process() → 改为 SimulationRuntime 低频 tick
- NPCBrain._process() → 改为 SimulationRuntime 调度
- 所有 Scheduler（Surface/Propagation/Respawn）不再独立 `_process()`

#### 🟡 P1 — 架构收敛（5-8 天）

4. **物理层迁移**: 按 PHYSICS_LAYERS.md 标准配置所有节点 collision_layer/mask
5. **Action Layer 统一** ⭐:
   - 定义共享 Action 类型：`MoveAction / AttackAction / UseAction / CastAction / InteractAction`
   - Player/NPC/Enemy 统一走 `Intent → Action → RuntimeRequest → RuntimeExecute`
6. **CommandBus 领域分区（设计+实现）**:
   - 引入 command domain 枚举
   - 引入语义分层：`request/*` / `result/*` / `event/*`

#### 🟢 P2 — 内容管道 + 验证（5-10 天）

7. **场景 A 验证**: 小型地牢 — 门/开关/地刺/宝箱/油桶/surface/propagation/quest 联动
8. **场景 B 验证**: 村庄 — NPC Schedule/Marker/Dialogue/Quest/Interact 协同
9. **NPC Schedule P2**: WanderTask / SleepTask / WorkTask
10. **Actor Scheduler**: tick_group("high"/"medium"/"low") 预算调度

#### ⚪ 停止线 — 不要做的（含 UNBREAKABLE 规则）

- ❌ 新增技能类型/Modifier/Condition/GraphNode（当前已足够）
- ❌ 新增表面状态（5 个已覆盖所有需求）
- ❌ 引入行为树/GOAP/Planner（Schedule+Task 模式已足够）
- ❌ FSM 读 WorldTime/Quest/Schedule（违反 FSM 铁律）
- **🔒 UNBREAKABLE**: EffectGraph 不得拥有时间控制权（禁止 loop/async/delay/parallel）—— 一旦破功，会变成"第二个 Runtime"
- **🔒 UNBREAKABLE**: Surface System 不得走元素×元素×元素组合模式 —— 只用有限状态迁移
- **🔒 UNBREAKABLE**: CommandBus 不得退化为"上帝总线" —— 后期必须引入 domain 分区

### 13.4 整体评价

该项目是一个**架构设计极为用心、文档非常完善**的动作 RPG 原型。核心战斗系统（CombatExecutor + Modifier 管线 + EffectGraph + EventBus）设计精良，契约体系严密。数据驱动的技能架构（Archetype 收敛）体现了优秀的工程判断力。

当前项目处于"核心系统已完成，内容管道待填充"的阶段。主要差距在于：部分设计好的基础设施（CommandBus/SimulationRuntime/物理层）尚未完全落地，内容验证（地牢/城镇/野外三个场景）待完善。

**前进方向**: 不是增加更多系统，而是让现有系统协同运作，通过"场景 A/B/C 验证标准"证明架构能以低成本产出高质量内容。

---

> **文档维护**: 本文档基于 2026-07-14 的代码快照生成。架构变更时请同步更新本文档及 docs/ 下的对应契约文件。
