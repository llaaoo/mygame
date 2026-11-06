# 项目架构与维护边界

2026-11-06。RPG 所有权与角色组合升级见 [RPG 基座](./RPG_FOUNDATION.md)。本文件定义当前边界；[运行时拓扑](./RUNTIME_TOPOLOGY.md)说明时序，[战斗契约](./COMBAT_CONTRACTS.md)与[世界契约](./WORLD_CONTRACTS.md)说明领域规则。[重构进展](./REFACTOR_PROGRESS.md)记录验收范围。早期项目分析文档保留为历史资料。

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
| `SkillManager` | 动作知识、编组、冷却及公开施法请求 |
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

统一入口：`python3 tools/run_tests.py`。每项检查隔离数据/配置/缓存，保留日志并设置超时；脚本错误、警告及非零退出均失败。CI使用相同入口。新增内容先运行内容验证，再运行受影响的玩法检查。

当前架构重构以已复现缺陷和可维护性目标为范围；手感、画面、数值平衡和目标设备性能仍需试玩或profile。后续新增功能由产品需求决定，不以增加抽象层作为目标。
