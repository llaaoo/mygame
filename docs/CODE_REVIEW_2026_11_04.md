# 当前代码审查与渐进重构建议

审查日期：2026-11-04。基线：`main`，`882c191`。下文保留审查时的复现结果；后续实现状态以本表和 [重构进展](./REFACTOR_PROGRESS.md) 为准。

| 事项 | 当前实现状态 |
|---|---|
| R01存档恢复、R02施法意图、R03公共冷却、R04条件触发冷却 | 已实现并有独立回归 |
| R05事务通知、R06命中语义、R09周期到期边界 | 已实现；覆盖失败无通知、资格策略、周期来源与不同delta分割 |
| R07技能栏重复预览、法术组合规则索引 | 同帧复用、共享冷却查询、按动作/作用域预索引 |
| R08一次性订阅 | 已实现，覆盖嵌套发射 |
| Buff实例与属性、公共区域生命周期、Player/MVPGame拆分、内容类型化 | 已实现；范围见重构进展 |
| 旧测试fixture、runner、CI和文档对齐 | 已迁移至独立fixture；统一隔离runner与GitHub工作流已加入 |

此表描述修复后的状态；下文的“当前”“实测”和行数描述审查基线，保留为缺陷复现与取舍依据。最终验收记录见[重构进展](./REFACTOR_PROGRESS.md)。

## 判断与范围

当前结构已能支撑探索、条件施法、材料、恩赐和世界反应的 MVP。法术组合规则资源、独立解析器、运行时技能副本、批量暂存效果和真实物理集成测试值得保留。继续扩充前，应优先统一施法与结算语义，收拢区域生命周期及持久化边界。

检查了 `core`、`entities`、`gameplay`、`ui`、`world` 的主要调用路径、当前内容配置和测试。上述五个目录合计179个 GDScript、19,624行；行数用于定位阅读范围，不作为拆分模块的唯一依据。重点阅读的文件包括 Player（1310行）、RunManager（1083行）、SkillExecutor（529行）、MVPGame（496行）、SkillManager（441行）、SaveManager（420行）、组合控制器（379行）、CombatExecutor（370行）和 BuffManager（323行）。旧 RunManager 属于保留的试验场，优先级低于当前探索入口。

审查阶段没有修改玩法代码，随后A—D批次已实施。审查用临时无界面探针复现边界问题，所有读写均使用独立 `XDG_DATA_HOME`；没有触碰玩家实际存档。未进行人工画面、手感或目标设备性能验收。

## 已复现的问题

P1表示先处理的数据丢失问题；P2表示影响行为一致性或后续联动的事项；P3表示基础设施和边界规则完善。

### R01 · P1：读取失败与新存档混为一谈，可能覆盖有效备份

- 位置：[SaveManager.read_extension](../core/save_manager.gd#L80)、[备份写入](../core/save_manager.gd#L71)、[MVP启动](../gameplay/exploration/mvp_game.gd#L50)、[进入区域后保存](../gameplay/exploration/mvp_game.gd#L197)。
- 路径：主档存在但根数据不是字典 → `read_extension` 返回 `{}` → `ExplorationProgress` 初始化为新进度 → 启动进入营地自动保存 → 损坏主档复制到 `.bak`，新进度覆盖主档。读取流程从未尝试 `.bak`。
- 实测：启动前备份包含已学知识；启动后知识未恢复，主档变为新游戏，备份变为原来的损坏内容。
- 建议：提取 `SaveRepository`，返回明确的 `missing / valid / recovered / invalid / unsupported_version / io_error` 状态。对主档、备份分别做格式与版本校验，读取失败时禁止启动自动覆盖；仅有效主档可以更新有效备份。`read_extension` 和完整读档使用同一加载入口。
- 验收：主档损坏能恢复备份；两个文件均损坏时保留原文件；未来版本不降级覆盖；临时文件/备份/替换失败均返回明确结果。另将 `_save_dirty` 在成功写入后清除，失败保留待保存状态。

### R02 · P2：Shift校验与执行使用不同施法意图

- 位置：[ActionResolver](../gameplay/action/action_resolver.gd#L61)、[实际执行](../gameplay/abilities/manager/skill_manager.gd#L272)。
- `ActionResolver` 调用 `preview(skill, entity)`，缺少强化意图；SkillManager 执行时读取 Shift，并调用另一种计划。
- 实测：同时有共鸣护盾和回响印记、剩余8 MP时，Shift＋震荡计划是8 MP且可用；普通计划是14 MP回响脉冲。真实输入流程的校验返回 `false`，拦住了可支付的爆破。现有测试直接调用 SkillManager，绕过了这一层。
- 建议：输入只在一个入口生成施法请求，携带 `source / direction / target / empower`。校验、瞄准、预览和准备都读取该请求；SkillManager 和 UI 不再分别采样全局 Shift。开始准备后继续保留已有的意图锁定。
- 验收：补真实 `Action → resolve_action → SkillManager` 路径；覆盖强化更便宜、更贵、材料不足以及准备中松开Shift。

### R03 · P2：公共冷却修正没有进入组合路径

- 位置：[公共冷却策略](../gameplay/abilities/manager/skill_manager.gd#L398)、[组合解析](../gameplay/abilities/combinations/conditional_cast_controller.gd#L91)、[组合提交](../gameplay/abilities/combinations/conditional_cast_controller.gd#L310)。
- 普通技能走 `_get_effective_cooldown`，读取熟练度和装备；组合计划/提交直接使用法术组合规则及动作的基础冷却。法力已接公共策略，冷却尚未接入。
- 实测：注入已有装备接口支持的 `cooldown.all = -0.5` 后，震荡的公共策略为0.4秒，组合计划仍为0.8秒。
- 另有显示问题：`get_cooldown_total` 根据当前条件重新解析总时长，未保存本次已接受施法的总冷却。离开法阵、换Buff或切Shift后，剩余时间与遮罩分母可能来自不同计划。
- 建议：提取共用 `CastCostPolicy`，统一动作、法术组合规则结果和修正项的费用/冷却。为每个冷却键保存本次 `remaining / duration`。明确“基础动作共享冷却＋结果法术组合规则冷却”的现有玩法规则；统一表示不意味着改变规则。
- 验收：相同修正在普通/组合路径效果一致；换槽不能绕过共享冷却；环境改变不使进度条跳变。无需为此新增装备内容。

### R04 · P2：不匹配的事件也会消耗触发器冷却

- 位置：[TriggeredEffect._on_event](../gameplay/combat/triggered_effect.gd#L62)、[冷却检查与写入合一](../gameplay/combat/combat_executor.gd#L255)。
- 触发器在检查 conditions 前调用 `check_trigger_cooldown`，而该方法直接写入最近触发时间。
- 实测：配置“火焰命中触发，冷却10秒”；先传入冰霜命中，再传入火焰命中，两次均未执行效果。冰霜事件已经花掉冷却。
- 建议：分开查询可触发与提交冷却。简单条件或效果图确认匹配且接受执行后再记录冷却；图模式需要返回明确的执行结果。触发冷却改用可暂停的模拟时间，避免 `Time.get_ticks_msec()` 与其他冷却的暂停规则不同。
- 验收：不匹配不占冷却；同一触发链只提交一次；暂停不推进游戏冷却。

### R05 · P2：失败回滚恢复了数值，但没有回滚通知

- 位置：[提交时先消费状态](../gameplay/abilities/combinations/conditional_cast_controller.gd#L275)、[remove_buff立即广播](../gameplay/status/buff_manager.gd#L77)、[快照恢复再次应用](../gameplay/status/buff_manager.gd#L112)。
- `SkillExecutionBatch` 已能延后新投射物、AoE、Buff和施法事件；对旧Buff的消费、恢复及材料变化通知仍立即发生。
- 实测：双法阵中第二个结果被执行器拒绝，余烬战意正确恢复、没有投射物激活，但观察者已收到1次 `ON_STATUS_REMOVED` 和2次 `buffs_changed`。
- 这会影响未来“Buff被消耗/移除时触发另一个技能”的机制；目前并未证明现有余烬法术组合规则已经产生额外伤害。
- 建议：扩展已有批处理为 `CastTransaction`：保留/暂存资源变化、准备全部效果、提交状态、最后发布事实事件。回滚不广播临时移除/重新获得。为状态移除携带原因 `expired / consumed / dispelled / replaced / region_cleanup`，避免把消费、自然到期和清理视为同一事件。
- 验收：失败不产生消费/施法事实事件；成功只产生一次消费事件；状态原剩余时间、层数、tick进度和资源保持现有回滚保证。

### R06 · P2：命中事件不能表达命中是否被接受

- 位置：[report_hit](../gameplay/combat/combat_executor.gd#L57)、[无敌判断](../entities/components/health_component.gd#L72)、[命中附加状态](../gameplay/combat/on_hit/on_hit_apply_status.gd#L29)。
- `ON_HIT` 先广播，再调用目标扣血；无敌/死亡等拒绝发生在扣血内部。状态、连锁和反应订阅者看不到最终是否接受。
- 实测：无敌目标生命保持100，但仍收到命中事件并被挂上燃烧。
- 需要明确“伤害无敌”和“状态免疫”的玩法规则；上述结果不能单凭现象判定必须完全免疫。当前缺少表达这一区别的结算数据，是已经确认的接口缺口。
- 建议：增加轻量 `HitContext / HitResult`，明确资格、伤害、状态、反应及来源策略。保持原有共同动作 `family_id`，支持一个动作的多个结果；实用性零伤害法术仍可命中机关/施加状态，不能简单用“damage > 0”过滤事件。
- 验收：闪避/护盾/独立动作无敌语义明确；零伤害水引、反应伤害、多法阵同次伤害和机关行为均保留。

### R07 · P2：技能栏重复构建完整计划

- 位置：[SkillBar._process](../ui/skill_bar.gd#L50)、[读取剩余冷却时解析](../gameplay/abilities/manager/skill_manager.gd#L218)、[读取总冷却时再次解析](../gameplay/abilities/manager/skill_manager.gd#L388)、[法术组合规则排序](../gameplay/abilities/combinations/spell_combination_resolver.gd#L36)。
- 每个已装备的受管动作：读剩余冷却、读总冷却、更新tooltip各解析一次；另有火花总提示。材料和恩赐修正可能各复制一次 SkillData及视觉资源。
- 实测：右手＋六槽填满受管动作，手工调用一次 SkillBar刷新，计数得到22次 `preview`。这是重复计算证据，尚未证明目标设备已经出现特定帧率下降。
- 建议：优先同帧复用按动作/意图索引的预览，统一返回展示模型；冷却只读状态。法术组合规则注册时按触发动作和条件作用域索引并排序。之后再按知识、材料、Buff版本、法阵、施法者位置和修正项变化失效缓存。
- 准备提交必须重新读取真实条件；不能为优化取消现有版本校验。UI只更新倒计时和变更文本，详细tooltip按变化更新。
- 验收：相同动作/意图在一帧只解析一次；有新增状态、出入法阵、Shift和材料配置变化时立即更新；提交不读陈旧缓存。先比较调用数和分配，再用Godot profiler评估收益。

### R08 · P3：一次性订阅实际上会重复执行

- 位置：[CombatEventBus.once](../core/event/combat_event_bus.gd#L55)。
- lambda捕获的是赋值前的空 `wrapper`，因此回调中的unsubscribe没有移除实际监听者。
- 实测：连续发射两次，回调执行2次，监听者仍为1。
- 当前业务代码没有发现该API的调用点，因此低于正在使用的施法/存档问题。
- 建议：用总线内部一次性标记/订阅ID，在调用前移除该条订阅，覆盖嵌套发射。不要只在调用后清理，否则回调再次emit仍可重入。

### R09 · P3：持续效果到期边界需要明确

- 位置：[BuffManager.tick](../gameplay/status/buff_manager.gd#L30)、[到期移除](../gameplay/status/buff_manager.gd#L235)。
- 先移除到期Buff，再计算周期效果。实测：持续2秒、每秒治疗5点，精确推进两次1秒，只治疗5点。
- 需要决定到期时刻的最后一跳是否应结算，并统一Buff、AoE和地面效果的时间约定。目前常规测试未覆盖这一边界，不宜仅调整顺序后默认所有技能数值都不变。
- 建议：按实际存活时间推进周期累计，再按明确的边界约定移除。添加不同delta切分、较大delta和暂停用例，保证相同模拟时间得到一致结果。

## 最值得做的结构调整

### 1. 把施法计划变成明确的数据对象

当前 `pending`、组件、签名和材料计划都是跨文件共享的可变字典；新增字段要同步修改UI、准备、提交和回滚，拼写/类型错误只能在特定运行路径暴露。

逐步引入少量 `RefCounted` 数据类型：

- `CastRequest`：输入意图和来源；兼容已有 `CastContext`，避免长期维护两个重复上下文。
- `CastPlan` / `CastComponent`：实际结果、准备时间、费用、冷却键、状态与法阵要求。
- `CastTransaction`：接受、消费、效果暂存、提交、失败恢复与通知。
- `CooldownState`：本次时长及剩余时间。

保留 SpellCombinationResolver、CastingSupplies、BoonSpellModifier 的现有职责，合成一个可供预览/执行共用的规划入口。先合并 `_execute` 与 `_execute_with_context` 的重复代码，再让普通技能使用零/单组件计划。按能力配置判断是否支持法阵、材料或恩赐，逐步去掉 `handles()` 的技能ID白名单和 `_sigil` 名字后缀判断。

修复R02/R03/R05后，再将原 `FireCombinationController` 更名为能反映多元素职责的名字（已迁移为 `ConditionalCastController`）；单独改名不算完成重构。不要立刻引入通用规则语言或新的图编辑器。

### 2. 分离Buff定义与Buff实例

现在Buff资源既描述效果，又被当作字典key；剩余时间、层数、tick进度和版本分散在多个容器。Buff用加减/乘除直接修改角色值，Player再用“上一次推导值”修补成长差值，EquipmentManager另算百分比。顺序越多，恢复、驱散、成长与叠层越难验证。

建议渐进引入 `StatusInstance`：稳定实例ID、定义引用、来源施法者/技能、剩余时间、层数、周期进度和移除原因。将永久成长值与临时修正分开，以现有属性组件为基础统一重算；先迁移移动速度、攻击和最大生命等实际使用的字段。

当前DOT以受影响实体同时作为source/target，来源信息会丢失；`stat_multipliers`也仅见于描述，Buff的apply/remove未应用它。它们需要在实例化和属性契约中明确，不应仅增加更多导出字段。

### 3. 收拢区域生命周期，减轻Player与MVPGame职责

[MVPGame._clear_temporary](../gameplay/exploration/mvp_game.gd#L123) 直接清空三个调度器的内部容器、派发命令、清Buff、清瞄准和删除区域。旧RunManager与RegionRuntime也各自管理区域。以后新增持续效果，很容易只在一套路径清理。

- 提供区域进入/退出的公共入口和scope标识；各系统清理自己拥有的状态，避免MVP触碰 `_active_surfaces / _jobs / _respawn_queue`。
- Player保留移动、受击及状态机接口，将输入/瞄准/蓄力引导提取为组件；将技能事件注册、熟练度和UI装配转到明确的组合根。
- `MVPGame`逐步拆出区域会话、进度服务和委托/事件处理；UI请求训练/加工/交付，由服务处理并返回结果。
- 当前探索与旧房间模式各有规则，先共享生命周期协议和公共服务，保留场景适配器；不要求立即把两者合并成一个巨型管理器。
- 长期装备修正与区域临时Buff需分别清理，避免 `clear_all()` 让装备管理器的“已装备”记录与实际加成脱节。

### 4. 让内容扩展主要落在资源配置

当前区域、发现、遭遇、机关和选项大量使用 `Array[Dictionary]`；路径、字段名、营地特殊逻辑、材料ID、制造配方与技能白名单分散在代码中。

优先把实际反复编辑的遭遇、出口条件、发现奖励、机关步骤和制造配方升级为有类型的资源。扩展已有 `validate_mvp_content.gd`：检查触发动作、状态和标签引用、机关非空步骤、费用数量范围及重复ID，在输出中包含资源路径。保持资源注册表，不必为当前规模增加动态插件发现机制。

### 5. 统一文档与测试入口

- `ARCHITECTURE.md`表示替代旧拓扑，但 `RUNTIME_TOPOLOGY.md`仍自称上层宪法；UI只读、跨Runtime一律异步等描述与当前实际控制流不同。应修订为可执行的公共接口规则：同步命令处理请求、查询读状态、提交后事件广播事实。资源事务不应被拆成若干无原子性保证的异步消息。
- 新测试存在 `boon_choices → joint_interactions → advanced_spells → spell_materials → exploration_mvp` 的五层脚本继承。抽出独立fixture，测试脚本互不继承；保留现在有价值的真实物理、实际生命组件和失败回滚验证。
- 增加一个统一runner，为每项测试设置隔离存档、超时、日志及退出码校验。`test_validation.gd`是旧编辑器辅助脚本，不应误当为可直接执行的SceneTree测试。
- 建立快检（规则/迁移/内容）、集成（施法/世界）、少量完整流程三个级别；之后接入CI。无需把所有短脚本改成复杂测试框架。

## 建议实施顺序与验收

| 批次 | 工作范围 | 完成标准 |
|---|---|---|
| A：行为修复 | R01存档恢复；R02意图一致；R03公共冷却；R04触发条件/冷却；补边界回归 | 本文复现改为正确行为断言，现有核心集成仍通过，正常存档兼容 |
| B：施法和状态边界 | 请求/计划类型；统一执行入口；R05事务事件；R06命中结果；明确R09时间边界 | 普通/组合/强化共用规划，失败不发布消费事实，零伤害工具与多结果保留 |
| C：预览与运行时生命周期 | R07同帧预览复用；法术组合规则索引；公共区域清理；R08一次性订阅 | 调用数可测，切区/死亡/读档无残留，各系统不由外部清空内部容器 |
| D：内容与维护性 | Player/MVPGame按职责拆分；高频内容类型化；fixture/runner；文档与CI | 增加已有行为的新法术组合规则/机关主要改资源，测试可一条命令运行 |

不建议先大规模搬目录、重写所有Runtime、做ECS、全量对象池或开放世界流式加载。现有数据规模下，应先消除行为分叉与多处状态写入，再用profile决定性能工程投入。每批保持可玩，不将稳定运行等到最后统一恢复。

## 本轮验证记录

- 重跑通过：`test_boon_choices.gd`、`test_joint_interactions.gd`、`test_skill_upgrades.gd`、`test_save_system.gd`，退出码均为0，日志无脚本错误/警告。
- `validate_mvp_content.gd`通过：9区域、15法术组合规则、3委托，交互净空和路线连通。
- 临时探针九项：损坏主档及有效备份、Shift入口差异、冷却缩减、条件触发冷却、回滚通知、无敌命中状态、技能栏预览次数、一次性订阅、周期效果到期。探针输出用于确认当前行为，并不表示这些缺陷已经修复。
- 临时脚本与输出留在本环境 `/tmp/mygame_review_probe.gd`、`/tmp/mygame_review_save_probe.gd`、`/tmp/mygame-review-probe.log` 和 `/tmp/mygame-review-save-probe.log`；正式修复时应将正确行为断言加入独立回归测试。
