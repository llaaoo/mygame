# 运行时拓扑与时序

2026-11-04。本文从属于[项目架构](./ARCHITECTURE.md)，说明当前实现；早期“所有调用必须异步”和“战斗执行器纯计算”的描述已由公开请求/查询/事实边界替代。

## 运行时结构

```text
GameRuntime
├── CommandBus           延迟命令与区域scope
├── CombatExecutor       命中、伤害、阶段与事件边界
├── CombatEventBus       领域事实订阅
├── WorldRuntime         物体状态、空间索引与场景同步
├── SimulationRuntime    表面/传播/重生与实体持续计时
├── RegionSession        活动区域、generation与共享退出协议
├── RegionRuntime        场景资源切换适配器
├── SaveManager          玩法收集与恢复
│   └── SaveRepository   文件校验、迁移、备份与替换
└── WorldTime            NPC日程使用的世界时钟
```

UI是角色/场景装配的表现组件集合，不要求一个名为UIRuntime的全局节点。旧房间 RunManager 与战役 CampaignGame 保留各自流程，共用区域生命周期。战役新增 Session/World/Interface 装配，ActorContext 和 RegionContext 注入角色依赖，详见 [RPG 基座](./RPG_FOUNDATION.md)。

## 一次施法

1. 输入适配器创建Action与CastContext，记录强化意图。验证和执行读取同一请求。
2. SkillManager检查知识与装备；条件动作由ConditionalCastController生成类型化计划、准备并校验真实条件版本。普通动作使用同一规划中的材料/恩赐和费用策略。
3. CastTransaction保留资源，执行器暂存效果；任一结果拒绝则回滚。成功后提交所有状态，再通知资源/状态观察者并发布ON_CAST。
4. 投射物/AoE/近战通过CombatExecutor.report_hit同步申请命中；接受后进行命中反应和实际扣血，返回HitResult。
5. 物体破坏等延迟世界工作进入CommandBus。该队列不拆分施法原子事务。

调用公开领域方法可以同步获得接受结果；读取状态通过查询API。禁止外部清空其他服务的内部容器。UI可请求服务执行操作，服务保留校验与写入权。

## 时钟与就绪

GameRuntime非暂停帧依次分发命令、推进触发冷却、调用SimulationRuntime。模拟服务推进表面、传播、重生、实体tick，再处理低频实体/表面接触。角色的生命、法力、状态、技能、条件准备、法阵、蓄力引导注册为ticker；位置/碰撞依赖物理帧，视觉更新保留在表现组件。

RuntimeRegistration保存弱引用的早期注册请求。GameRuntime就绪后只接收同一游戏场景内的节点，待注册节点离树时移除等待记录；模拟中的节点也在tree_exiting时注销。GameRuntime进入场景树后才成为兼容入口，战斗总线、执行器及世界时钟由它创建。角色与区域组件记录实际订阅的总线，并在退出时向同一总线注销。

模拟暂停停止技能、恩赐、触发冷却等玩法时间。状态和持续AoE按实际存活时间处理周期，包含到期端点；大步长保留周期余量，表面自然迁移继续消耗超出的时间。

## 区域边界

`RegionSession.leave(root, actor)`依次：

1. 取消角色准备、蓄力、引导、瞄准、位移Tween、召唤与临时状态；保留装备贡献。
2. 有界派发已排队的WORLD目标事实；取消旧区域战斗/模拟工作，然后清空队列并推进scope。
3. 各调度器清理自己的瞬态状态，世界空间索引清空。
4. 推进generation，禁用、移出并删除旧根，清除活动根。地图锚点随旧根卸载。

`mount`标记新根并挂入场景。延迟命令携带scope，旧scope在入队和派发时拒绝；遭遇回调校验generation。需要跨区域长期保留的状态放在持久进度中，不能依赖旧节点或旧计时队列存活。

旧入口在场景中指定初始地图与玩家。旧房间和整张地图复用活动根，房间接管时卸载旧地图。传送在物理回调结束后检查请求的 generation，确认目标场景与目标地图内的锚点，再卸载旧区域。无效目标或重复请求保留当前区域与玩家位置。

CastContext默认world选择活动区域，便于统一卸载普通投射物、AoE和召唤。显式world仍按调用方提供的生命周期管理。

## 持久化

SaveRepository返回缺失、有效、备份恢复、无效、未来版本或I/O错误，不直接改玩法。存档信封检查字段及数组元素后再进入恢复流程；旧版缺失的可选字段沿用默认值。读出的数组和字典在恢复时复制，避免源快照与运行对象共享可变容器。SaveManager收集和恢复注册数据，MVP的进度服务负责探索恢复与自动保存重试。损坏文件无有效备份时保留原文件；未来版本不降级覆盖。失败读档保留当前旅程。旧地图存档先确认并进入记录的区域，随后恢复世界快照、角色及扩展数据，避免旧区退出时的排队事件覆盖已读入的世界事实。

## 验证

`test_region_lifecycle.gd`检查早期/重复注册、旧命令与回调、世界事实保留、普通法术归属、反复切区和装备贡献。`test_status_transactions.gd`检查事务通知、命中资格、周期边界与属性重算。测试入口和完整范围见[重构进展](./REFACTOR_PROGRESS.md)。
