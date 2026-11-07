# 当前代码与内容使用盘点

2026-11-07，起点 `60aad363`。本轮把首玩阻塞修复与架构整理一起验证，保留现有地图、敌人配置、配方和初始预算。默认产品入口是 `grayriver.tscn`，不要用文件数量或技能资源数量代表可玩深度。

## 系统分类

| 系统 | 当前实际用途与权威所有者 | 整理结果及边界 |
| --- | --- | --- |
| 战役、区域与存档 | GrayriverGame → CampaignGame → CampaignSession；RegionSession 管离区，ExplorationProgressService 管发现与委托 | 保留这条装配链；删除没有使用的房间生成器字段，避免创建随后被灰河谷目录替换的默认目录。不是另建一套战役框架。 |
| 输入与动作 | PlayerInputController 提交动作，ActorComponents 接受并付费；InputBindings 负责默认绑定与读入用户设置 | 删除三个场景内重复注册脚本、Player 中重复的交互/额外技能注册、无调用的 core/input_setup。5/6 槽在读设置前注册，首次启动的改键不会被跳过。 |
| HUD、远征面板 | 当前 HUD、FrontierHUD、ExplorationPresenter 均有实际显示/交互职责 | 保留两个不同层次的展示；修复全屏被动容器拦截世界鼠标的问题。真实按钮继续接收事件，点击按钮不会同时攻击。 |
| 物品、装备、掉落、制作、交易 | InventoryService 是实例写入边界；材料字典是兼容投影；ItemCatalog 是当前物品目录 | 删除无人调用且重复列装备ID的 GrayriverItems。保留旧 EquipmentCatalog 的兼容与旧验证场用途，不能把两份目录计成两套灰河谷装备。 |
| 技能与组合 | SkillManager、CastPlan/事务、SpellOperationCatalog；共同命中、状态和地面规则 | 不把每种结果拆成新的可学习技能；保留仍被旧场景和测试使用的蓄力、引导、召唤等执行能力。当前来源数量见下表。 |
| 敌人与人物 | 共同角色定义、实际装备/库存，AI 提交可执行动作 | 修复侦测圈外但追击界内受击后仍闲置的问题，沿用既有侦测与追击边界。没有改敌人属性、掉落模板或分布。 |
| 生存、采集、现场作业、世界工程 | SurvivalService、补给/制造服务、FieldWork 与项目/任务服务已接入场景 | 炉灶真实 E 输入复测通过；使用实际材料制火石、拾取遗骸、返镇读档数量/UID一致。现有单项测试覆盖其他边界，本轮未逐一自然游玩所有工程。 |
| NPC 日程、关系与交涉 | 由角色/任务/关系服务及灰河谷故事适配接入，属于现有内容 | 不把代码存在解释为完整城镇社会模拟；日程、交易与停战有回归，后续扩充必须指定实际人物与流程。 |
| 旧房间制与通用NPC任务 | main.tscn 使用 RunManager、QuestManager；mvp.tscn 是保留的监狱验证场 | 从两个 Campaign 场景移除禁用 RunManager；探索模式不再创建闲置 QuestManager/QuestTracker。main 的旧模式继续保留、单独回归。 |
| EffectGraph/战斗原型 | CallableNode 仍被行为回归使用；部分旧示例完全无场景、资源或测试调用 | 只归档核对无调用的8个原型；不整包删除 effect_graph、条件或修饰框架。 |
| 编辑器工具、插件 | 内容校验器与离线美术工具仍有用途；addons 是第三方实现 | 8个旧批量改路径/生成占位脚本移入 tools/archive/migration，`.gdignore` 排除导入；插件不做无证据删减。 |

## 内容定义与接入程度

资源盘点由 [audit_content_usage.gd](../tools/audit_content_usage.gd)生成[来源清单](validation/project_content_usage.json)，读取当前灰河谷发现、角色模板、操作介质、组合规则及物品目录。

| 项目 | 本轮盘点 | 能说明什么 |
| --- | --- | --- |
| 区域 / 委托 | 4 / 11 | 连续野外加三个室内区域；不等于四张新增地图。 |
| 有当前来源的玩家基础动作 | 7 | 火花、布阵、喷发、凝神、震荡、汲取、水引；数据中的旧技能ID经 canonical 映射。 |
| 有来源映射的条件结果 | 22 | 玩家操作/组合可生成的结果定义；不是22个独立解锁技能，也不代表所有动态元素知识结果。 |
| 制造配方 | 20 | 全部有发现来源；有来源不等于本轮逐一制作。 |
| 当前装备目录 / 旧装备目录 | 13 / 30 | 当前13件与实际来源映射单列；旧目录含验证场、旧存档及技能树内容。 |
| 全部独立 SkillData ID | 69 | 包括当前动作、结果、旧奖励与技能树，不可当作灰河谷69种可学技能。 |
| 没有当前灰河谷直接来源的 SkillData ID | 28 | 详见JSON；例如召唤、蓄力火球、暴风雪、暗影步。旧房间奖励、技能树等仍引用，保留为旧内容，不能称为死代码，也不宣传为当前探索奖励。 |

## 无调用与冗余的判定

[静态盘点脚本](../tools/audit_project_usage.py)输出[引用清单](validation/project_usage.json)。它同时检查 `res://` 引用及全局类名，包括可选分支、类型和注释，刻意高估可达性。305个“可能被当前入口引用”的脚本不是305个已运行系统；反之，没有静态调用也不能直接删除动态加载内容。

归档前另查了场景/Resource、目录登记、测试与工具、运行时入口。隐藏代理元数据和历史文档不算运行来源。归档的8个战斗原型与8个迁移工具见 [archive说明](../tools/archive/README.md)。真正仍有测试依赖的 CallableNode、内容校验器保留。

真实首玩驱动还记录场景树脚本列表，但它只覆盖当时实例化的 Node，不覆盖所有 RefCounted 服务、延迟内容或其他区域。它用来补充证据，不能替代引用与领域审查。

## 后续扩充的准入与顺序

1. **维护一份权威状态**：输入注册、战役任务、库存和区域生命周期不再新增平行实现。旧模式通过入口装配和规则配置保留，领域服务不根据具体游戏类名选择行为。
2. **先补接入再加定义**：需要让旧技能进入灰河谷时，选择少量与现有材料、采集、制作、生存有明确取舍的能力，给出学习来源、实际费用、AI可用性、反馈和存档验证；不要批量把28个技能塞入奖励池。
3. **纵向完善组合**：一次围绕一个实物/来源贯通获取、加工、装备或施法、敌人使用、剩余掉落、保存恢复；优先完善失败原因和实际效果反馈，再扩内容数量。
4. **继续缩小适配器职责**：GrayriverGame 相关 UI/故事/地图可以依赖入口，通用角色、物品与战斗不反向依赖灰河谷。大型 Presenter 按真实改动拆分，不进行无行为收益的全量重写或引入通用ECS。
5. **验证分层**：资源来源盘点 → 领域回归 → 正常AI真实输入路线 → 同档对照与保存恢复。测试场内可控通过不等于自然试玩、平衡或性能验收。

这些边界沿用 Godot 4.6 官方[场景组织与依赖注入](https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html)、[Node/RefCounted/Resource选择](https://docs.godotengine.org/en/4.6/tutorials/best_practices/node_alternatives.html)：父级装配依赖，生命周期决定树归属，纯数据/服务不必成为Node。本轮未增加Autoload或抽象框架。早期分析以历史资料保留，当前契约见 [ARCHITECTURE](ARCHITECTURE.md)，首玩证据见 [GRAYRIVER_FIRST30](GRAYRIVER_FIRST30.md)。

复核命令：

```bash
python3 tools/audit_project_usage.py
godot --headless --path . --script res://tools/audit_content_usage.gd
python3 tools/run_tests.py --suite all
```
