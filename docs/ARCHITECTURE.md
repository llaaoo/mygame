# 项目架构与维护边界

2026-11-08：[操作闭环与智能施法](PLAYER_FLOW_AND_SPELL_ASSIST.md)加入由SkillManager持有的瞬态SpellFormAssist；QuickslotLoadout仍独占绑定，形式解析继续进入同一CastPlan和事务。生产事实由适配器请求日志与排队通知，UI不增加库存或施法权威。

2026-11-06。RPG 所有权与角色组合升级见 [RPG 基座](./RPG_FOUNDATION.md)。本文件定义当前边界；[运行时拓扑](./RUNTIME_TOPOLOGY.md)说明时序，[战斗契约](./COMBAT_CONTRACTS.md)与[世界契约](./WORLD_CONTRACTS.md)说明领域规则。[重构进展](./REFACTOR_PROGRESS.md)记录验收范围。早期项目分析文档保留为历史资料。

2026-11-07 UTC的[系统深化](SYSTEM_DEPTH.md)沿用这些边界：WeaponMoveset/MartialTechnique为Resource，MartialArts为角色持有的RefCounted状态，ActorActionController执行物理动作，TownServices为灰河谷服务适配器，InventoryService提交UID交易/拆解/强化，WorldTime投影持久时钟。

2026-11-09：[评审修复与验证](reviews/WORLD_FEEDBACK_REMEDIATION.md)统一内容引用与前置查询、派生任务阶段和装备详情入口。`ExplorationContentCatalog`只查询不可变定义；`ConditionQuery`读取当前事实；任务Resource派生阶段。`InventoryActions`提供穿戴/卸下原因查询与执行重验，所有持有装备详情进入同一`ActorInventoryScreen`，UID与库存权威仍为`InventoryService`。

2026-11-09：[行路者手册界面](UI_AND_INTERACTION.md)共享`ExpeditionNavigation`与`GameUIStyle`外观组件；`GrayriverGame`注入现有页面路由，界面保存自己的浏览上下文。绑定继续进入`QuickslotLoadout`，选材继续进入`QuickslotMaterials`，库存变化继续进入`InventoryActions/InventoryService`，页面不成为新的库存、绑定或世界状态写入者。

## 请求、查询与事实

公开方法接受同步请求并返回是否接受，查询只读状态，已提交事件广播事实。需要原子性的施法保留在同一事务中。延迟世界工作由带区域作用域的 `CommandBus` 排队；它不承担全部跨模块调用。

UI可以调用领域服务请求训练、制造、交付或施法，由服务验证并修改状态；UI不直接写生命、库存或探索记录。保存恢复通过领域接口写入状态，文件处理独立于玩法。

## 组合根与所有权

| 所有者 | 职责与公共边界 |
|---|---|
| `GameRuntime` | 创建战斗、世界、模拟、命令、存档及区域服务；发出运行时就绪事件 |
| `Player` | 装配角色组件，保留移动、受击、属性、状态机与场景接口 |
| `PlayerInputController` | 将输入转换为 `Action`；只在输入边界采样强化意图 |
| `PlayerCastingController` | 瞄准、蓄力、引导及取消；持续计时注册到模拟服务 |
| `PlayerCombatBindings` | 角色事件、熟练度、触发器与辅助UI装配；退出时取消订阅 |
| `SkillManager` | 动作知识、冷却及施法请求，旧编组API委托QuickslotLoadout |
| `ConditionalCastController` | 条件规划、准备、重校验与提交；按能力字段管理任意元素动作 |
| `BuffManager` | 状态实例、版本、事务通知和属性重算 |
| `CampaignGame` | 战役装配与探索流程，创建 Session、World、Interface；MVPGame 为旧入口适配 |
| `CampaignSession` | 战役库存、关系、事实、角色记录及 RegionContext 的所有者 |
| `ActorComponents` | 共用体力、稳定性与动作执行；由 ActorContext 注入能力 |
| `InventoryService` | 实例、容器、穿戴与交易的唯一写入边界 |
| `ExplorationProgressService` | 知识、发现、成长、委托、世界选择、奖励与保存同步 |
| `ExplorationPresenter` | 展示进度和规则，向进度服务提交操作请求 |
| `ExplorationRegionBuilder` | 将区域资源装配为遭遇、发现与交互节点 |
| `RegionSession` | 探索、旧房间与场景地图共享的离开/进入边界 |

## 技能与状态

2026-11-07：灰河谷通过 `SpellOperationData + SpellPayloadData` 区分释放动作和材料效果，复用 CastPlan、事务、命中与表面反应。详见 [基础动作与释放介质](./MATERIAL_SPELL_OPERATIONS.md)。

`CastContext`保留施法者、来源、方向、目标、世界、蓄力和强化意图；`ActionResolver`与执行使用同一上下文。`CastPlan / CastComponent / CastStatusRequirement`表达确定结果和条件版本。预览不扣资源，准备提交时重新验证；`SpellRuleIndex`按动作与作用域预索引规则，同帧UI复用预览。

普通施法和条件施法共用费用策略、材料/恩赐规划、执行器与 `CastTransaction`。事务暂存法力、材料、状态消费和效果，全部接受后统一通知；失败恢复状态与计时，不广播消费或施法事实。引导脉冲复用普通事务，按累计引导费用结算整数法力，失败停止。

`Buff`是效果定义，`StatusInstance`持有来源、剩余时间、层数、周期进度和版本。`ActorAttributes`从永久基础值、固定/百分比贡献和速度倍率重算属性，避免移除时反向算术带来的漂移；装备贡献标记为持久，不随区域临时状态清除。

伤害入口为 `CombatExecutor.report_hit → HitResult`，分别表达伤害/状态资格。`ON_HIT`是接受后的命中反应入口，`ON_DAMAGE`是扣血后的事实；同次动作共享family。周期状态保留原施法者，使用已施加DOT策略，不因接触伤害无敌丢失后续跳数，默认不重触发普通元素附加状态。

## 内容与术语

| 内容 | 含义 | 数据位置 |
|---|---|---|
| 法术组合规则 | 动作＋法阵/状态产生结果，可叠加材料与恩赐修正 | `SpellCombinationRule`、`content/combinations/` |
| 施法材料修正 | 施放时消费媒介，改变伤害、标签、范围或结果形态 | `CastingMaterialData`、`content/casting_materials/` |
| 制造配方 | 消耗库存原料，产出库存物品 | `CraftingRecipe`、`content/crafting/` |

区域、遭遇、发现、出口、世界事件、机关路线与委托使用类型化Resource；`content/exploration/chapter.tres`集中登记区域、动作、法术组合规则与委托。旧存档的 `recipes`键仅作为法术知识的迁移输入，新保存写入 `spell_rules`，制造配方不进入知识列表。

已有行为的新内容主要修改资源；新条件、新原型或新世界反馈仍需要明确的代码扩展。禁止用未校验的字符串拼接成第二套隐式脚本语言。

## 世界、敌人与NPC

`WorldStateManager`持有稳定ID的物体事实，`WorldSpatialIndex`持有当前区域的空间引用；各调度器拥有自己的清理接口。法术默认挂在活动区域根下，显式上下文可指定其他世界节点。区域退出保留已排队的世界事实，清除瞬态工作，推进scope/generation后卸载旧根。异步回调必须验证来源作用域。

敌人的反应式StateChart和NPC的 `WorldTime → NPCBrain → Task → Action → StateMachine`保留；状态机执行移动/动画，不选择日程、任务或宏观目标。本轮没有扩展NPC生活、生存数值、装备内容或开放世界流式加载。

## 验证与后续

个人定时状态与冷却由`BuffManager`、`SkillManager`提供纯值快照，`CampaignSession`负责来源ID解析与按游戏时间恢复。离区效果在全区域角色挂载后结算，复用正常命中、死亡、奖励和真实UID战利品链；不以读档重放施加事件。`SaveRepository.start_new`先归档再建立新主/备份，`SaveManager`阻止旧场景回写，`CampaignGame`重建场景。边界与实测见[状态一致性、稳定行囊与新旅程](PERSISTENCE_RESTART_PLAN.md)。

统一入口：`python3 tools/run_tests.py`。每项检查隔离数据/配置/缓存，保留日志并设置超时；脚本错误、警告及非零退出均失败。GitHub Actions保持停用，验证在云环境运行。新增内容先运行内容验证，再运行受影响的玩法检查。

当前架构重构以已复现缺陷和可维护性目标为范围；手感、画面、数值平衡和目标设备性能仍需试玩或profile。后续新增功能由产品需求决定，不以增加抽象层作为目标。

2026-11-07：新增 [物品动作、喷洒与真实来源](./ITEM_ACTIONS_AND_REACTIONS.md)，描述共用物品执行器、逐瓶余量、武器涂层、明确来源与临时能量的职责和验证。

2026-11-07：当前接入与历史内容区分见[项目使用审计](PROJECT_USAGE_AUDIT.md)。输入默认项与用户改键统一由`InputBindings.install()`在Player入树时装配；场景不另行注册。探索战役使用`ExplorationProgressService`，不创建旧`QuestManager/QuestTracker`或禁用的`RunManager`；旧main入口仍保留房间与NPC任务验证。

技能输入与历史能力迁移见[LEGACY_SKILL_INTEGRATION](LEGACY_SKILL_INTEGRATION.md)。统一快捷槽与来源快照见[SPELL_SYSTEM_REVIEW](SPELL_SYSTEM_REVIEW.md)。QuickslotLoadout持有13槽的动作/物品绑定；旧left/right存储键保留兼容，解释为Q/R独立槽，E单独保存；新操作继续经过SpellOperationData、CastPlan和同一事务，不另建技能或材料执行链。

2026-11-07：实时界面与物品管理见[REALTIME_INVENTORY](REALTIME_INVENTORY.md)。`QuickslotMaterials`统一按槽选材查询/请求，`InventoryActions`注入库存管理权限与保存行为，`GroundItems`只投影库存cache；UI不持有第二份绑定或战利品。菜单仅接管输入，`ActorActionController.advance`与世界保持运行。

实时首玩复测补强见[游玩循环审查](GRAYRIVER_LOOP_REVIEW.md)。`CombatExecutor.defense_resolved`在命中组与资源结算完成后广播只读防御结果，由注入执行器的伤害文字组件展示；不把表现事件用于扣款或伤害。空`ground.*`容器由库存事务回收，独立落地身份不会在当前会话重用。

2026-11-08：[状态、生产与知识扩展](SYSTEM_EXTENSIBILITY.md)明确食品时钟与死亡策略、纯值排产状态、原子库存加工和武技/课程Resource目录；内容登记与失败边界见[接入指南](CONTENT_AUTHORING.md)。`TownServices`只装配商店/训练师配置与UI，排产、知识、库存仍各有唯一权威。

2026-11-09：[按住式武器操作](WEAPON_HOLD_INPUT.md)由输入适配器无损提出鼠标边沿，ActorActionController独占短暂准备、计时和一次性段落/路线保留。速发/重发均复用原TECHNIQUE执行与真实库存提交；共享Resource不存蓄力进度，存档不存鼠标意图。

2026-11-09：[角色动画基座](ACTOR_ANIMATION_SYSTEM.md)以只读动作快照、不可变Clip/Profile与原生SpriteFrames/AnimationLibrary分离玩法和表现。Avatar实例拥有播放/受击状态，武器绘制移出动作执行器；挥出提示来自真实提交事实。身体、纸娃娃与遗骸共用已登记的无武器身体配置，装备仍由实际UID提供。
## 全游戏表现入口

角色rig是[全游戏表现基座](GAME_PRESENTATION_SYSTEM.md)的一个分支。CampaignGame组合场景拥有的PresentationDirector、WorldObjectPresentation、EnvironmentPresentation、CameraFeedback与原生音效；事实、库存和时钟继续拥有玩法。UI用局部Tween；美术预制体禁止脚本、碰撞和外部方法轨道。玩法的随机流独立于原生粒子使用的引擎全局随机源。
