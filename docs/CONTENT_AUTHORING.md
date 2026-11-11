# 内容接入与系统扩展

地图、门、出生点与现场内容摆放优先使用[地图制作工作流](MAP_AUTHORING.md)的场景/模板、命名落点与统一检查。档案窖已从JSON迁到Godot场景；新地图不复制手填坐标或另建运行规则。

新增内容优先复用现有稳定ID和领域快照，无须为每次内容更新提高存档版本。新增可选持久字段或独立系统的接入方式、模块迁移与旧档保护见[存档系统](SAVE_SYSTEM.md)。

2026-11-10：[地图场景编辑](TOWN_MAP_CELLS.md)通过MapCellCatalog登记可视化房屋/室内场景，Node2D位置为唯一空间来源，类型化Resource提供门、站点、文书、服务和固定容器。碰撞、寻路和室内地图共用footprint；公共库存只初始化一次，空箱保留。

2026-11-08，北京时间。本指南描述已接入灰河谷的内容入口；系统契约见[SYSTEM_EXTENSIBILITY](SYSTEM_EXTENSIBILITY.md)。沿用Godot4.6的Resource定义、场景装配和显式依赖注入，不增加规则脚本语言。

## 增加内容应改哪里

| 内容 | 定义与登记 | 仍由谁负责执行 |
|---|---|---|
| 食品/饮品 | `ProvisionDefinition` → `content/provisions/catalog.tres`；物品同时登记`content/foundation/items.tres` | 原物品准备/扣费、`SurvivalNeeds`需求变化与`BuffManager`效果 |
| 药效/异常/食品状态 | `Buff`，配置期限、互斥组、属性/恢复及死亡保留策略 | 同一状态/命中链；持续效果保存到角色快照 |
| 武器动作与武技 | `WeaponMoveset`/`MartialTechnique` → `content/martial/catalog.tres` | 同一物理动作、命中、体力、冷却与附魔投送；不另写技能执行器 |
| 学习路径 | `LearningOffer` → `TrainingCatalog`；技能书的`ItemUseDefinition.technique_id`引用同一武技ID | `TechniqueLearning`处理课程条件和付款；`MartialArts`统一检查能力前置/互斥 |
| 店家与排产 | `MarketDefinition`首次库存；`ProductionDefinition`引用已有`CraftingRecipe` → `content/production/catalog.tres` | `ProductionService`按游戏时间排程；`InventoryService`原子加工与交易 |
| 法术材料/组合 | 原`SpellPayloadData`/`SpellOperationData`/`SpellCombinationRule`目录 | 原`CastPlan`预览与事务、命中/表面反应链 |
| 制造配方 | `CraftingRecipe` → `content/crafting/catalog.tres`（`CraftingCatalog`） | 原角色已学知识、现场制造与库存事务；目录登记不自动学会，NPC排产仍引用同一配方 |
| 采集/机关/委托 | 原灰河谷定义、`SurvivalStationData`及探索Resource | 原现场作业、库存、世界事实与进度服务 |

新增定义并不自动授予玩家：必须同时提供真实来源，如资源点、工作台配方、店家库存、敌人穿戴/行囊、训练师课程或技能书。只有新的空间行为、动作节奏或领域语义才需要扩展执行代码。增加地图上的服务人物仍需场景/入口装配，不能把登记目录误认为自动生成NPC。

## 食品示例

1. 创建物品定义并登记物品目录，提供采集/制造/购买来源。
2. 创建`Buff`，配置`provision_id`为物品ID、`provision_group`为`meal/water/tea`之一。同组使用同一个非空`exclusive_group`，确保替换而非叠加。期限、属性、生命/法力/体力恢复写在这份定义。
3. 创建`ProvisionDefinition`，设置饱食、饮水、疲劳、准备秒数、描述和上面的效果，加入食品目录。原快捷物品与补给页会使用同一准备和消费路径。

`meal`是食物槽，饮水和茶各有独立槽；污染水可以引用原中毒定义而不占恢复槽。需要第四种并存恢复槽属于新语义，应明确增加规则及UI，不能借不同互斥组偷偷堆叠同一槽。

## 学习与专精示例

- 新武技加入武技目录后，K页、知识快照、快捷绑定和原动作执行会查询目录，不再追加硬编码ID列表。
- `MartialTechnique.art_routes`登记`MartialRoute`短序列与窗口，共用核心武技键按路线发动，不要求逐招绑定。匹配与事实由角色`WeaponArtState`持有，Resource不存进度；配置区分无需/末击/每击命中并设显式优先级，避免同序列同优先级冲突。见[路线接入](WEAPON_ART_ROUTES.md)。
- 已有武技可配`followup_after`（从0起的普通攻击下标）及`followup_profile`，在非末段有效命中后开放接势；仍共用原知识和冷却，不能隐式释放附魔。输入、AI、预览共用同一查询与快照。角色`ActorCharacterData.techniques`声明首次生成的知识（按前置顺序），已有存档记录不由模板补写。见[接势武技](MARTIAL_FOLLOWUPS.md)。
- 普攻段落在`WeaponMoveset.attacks`有序登记，配置每段`AttackProfile.title/motion/swing_direction`及真实范围/费用；`chain_window`从完成收招后计时。末段结束不会自动出招。状态在角色自己的`WeaponComboState`，不写Resource或存档；弓段必须配置真实箭矢投送。详见[武器连段](WEAPON_COMBOS.md)。
- `AttackProfile.movement_multiplier`控制前摇/有效阶段，`recovery_movement_multiplier`控制后摇末端，默认1，后摇使用平滑插值。若新动作需要收招仍减速，显式配置末端倍率；不要通过延长有效阶段制造锁步。总时长、伤害、命中与费用仍取原定义，见[武器操作响应](WEAPON_RESPONSE.md)。
- `prerequisites`引用武技ID；`exclusive_group`表示学习后互斥的专精。验证器拒绝未知前置、循环及自相矛盾的互斥前置链。已保存的旧知识不因新前置追溯删除。
- 课程的`requirements`使用现有`WorldCondition`：探索发现、清场、实物、关系、法术知识。每项写面向玩家的`hint`。课程可使用不同费用和条件，技能书可提供另一条获取路径；能力自身的武技前置/互斥仍对书生效。
- 课程费用唯一读取`LearningOffer.costs`；旧武技`price`字段为兼容保留，不作为当前课程价格来源。
- 现有横扫课程要求携带实际战杖（已装备也算）；技能书机制支持另一条获取路径，当前实际书是贯步刺。训练师配置还持有角色ID、工作/休息位置和日程，场景入口注入该配置。课程条件在确认时重验；对方装不下付款时不留下半份知识或付款。

## 排产示例

新增`ProductionDefinition`：填稳定ID、生产者库存所有者ID、现有配方与每批游戏小时，再加入排产目录。绑定该所有者的整修铺会列出对应配方。

订单表示排程意图，不预扣原料或锁定货品。玩家可以把真实采集材料卖给店家；店家在工期完成时原子消费自己实际持有的配方原料，产出归店家，再按原交易规则出售。缺料/满库会等候，解除后重新计算完整工期；不把阻塞时间积攒成瞬间产量。停止订单不会凭空退款，已完成批次也不会撤回。

现有箭、火石与石肤药剂只复用旧配方/预算作为接入样本。排产不制造河谷币，不重置原库存，不自动搜集或采购原料。这个边界支持供货、加工和购买循环，尚不是完整城镇生产经济。

## 登记与兼容要求

- 灰河谷JSON经`GrayriverDefinition.read_source/parse_source`和`GrayriverValidator`预检后才装配：原始类型、二维坐标、模板身份、资源存在及类型必须有效。`build()`失败返回带`preflight_errors`和`map_catalog_errors`的空章节，工具显示原字段路径；不要在检查前索引原始数组或调用模板装配。`build_from_data()`允许用独立副本验证坏输入，不改正式内容。完整类型化内容/地图校验继续执行，预检不代替领域规则。
- 正式入口预检失败时显示启动诊断并停在旅程装配之前；`source_path`可注入隔离制作夹具。地图目录中的空Inspector槽仍须修复，当前地图检查会保留该诊断。
- Resource是共享定义，运行时不能修改。UID、订单截止时间、批数、知识与冷却分别由现有领域服务持有。
- 稳定ID属于存档协议；不能随意删除/改名已发布的物品、武技、订单或状态定义。变更先补迁移，不能靠忽略未知条目丢掉旧资产。
- 先跑`python3 tools/run_tests.py --tests content`，再跑对应领域及输入验证。新行为覆盖失败、费用、容量、重复请求、离区、死亡、F9和重新进入；跨系统变更按AGENTS跑无缓存归档全套。
- 内容定义可复用当前系统；新投送形态、武器类型、食品槽或NPC服务行为仍要明确设计，不能声称任意内容都无需代码。

## 灰河谷远征与世界后果

在`content/frontier/grayriver.json`增加区域、角色实物配置、线索与机关；默认沿用类型化Resource装配。`quests.unlock_claims`控制找到线索后的列表可见性及交付资格；不以UI隐藏代替领域验证。多层内部区域的第一个出口须是无条件的返回上一层/河谷出口，地图通过该返回链定位；推进出口用`required_claims`连接真实机关。保证每层都有不消耗材料的撤退路线，地面机关检测点放在64格中心。

事件`irreversible=true`后，选项可通过`grants_claims`开放实际站点、奖励或出口；重复请求不能改变决定。可反复改道的事件禁止发永久事实，避免两边奖励都领。引用新事实必须在内容校验中可解析。

灰河谷发现/机关/交付的材料奖励通过既有库存转移，容量不足的部分留在现场实例容器，空箱隐藏；不要重新直接向显示字典追加奖励。新增路线、空间可达性、两种后果、满包余量与保存重进必须验证，内容规模与真人盲玩时长分别记录。具体样本见[巡河demo](GRAYRIVER_DEMO.md)。

## 地点线索、前置与任务状态（2026-11-09）

灰河谷笔记 `leads` 每项仅填 `region` 或 `claim` 稳定ID；编译为 `ExplorationNavigationHint` Resource。目录从实际出口拓扑或目标位置生成相对阅读点的八方向说明，通路未连通则说明阻塞。不要把方向、入口坐标复制到新字段。此查询不探索迷雾、不解锁目标；旧档发现记录在展示时解析现行定义，机关完成方式和费用等历史记录继续保留原文。

`required_claims` 是真正的前置；现场作业、设施、交付与事件通过 `ConditionQuery` 显示对应发现/设备/实物部件名称，并在提交时重新核验。任务 `unlock_claims` 是既有引入线索，`discovery_claims` 是当地入口线索；获得任一当地线索或目标证据可使任务可见。真正报告条件只放 `required_claims / required_clears / conditions`，不得把建议顺序作为隐形交付门槛。任务的未发现、进行中、可报告、已报告阶段从实际进度推导，不保存另一份状态。

关键初教笔记可设置正数 `reading_margin`。校验器要求其中心到每个初始敌岗的距离至少为 `detect_range + 80交互半径 + reading_margin`；默认敌人侦测仍为440。它只约束初始布局，不提供无敌、不暂停、不保证被追击后安全。新增机关/设施/交付/事件的事实依赖会检查循环；导航引用和任务当地线索必须存在。

## 身体动画与动作表现

按[动画接入流程](ACTOR_ANIMATION_SYSTEM.md)添加SpriteFrames、ActorAnimationClip与原生姿态库，将真实角色配置登记到`content/animations/live_profiles.tres`并配置ActorCharacterData。AttackProfile.animation_id只选择表现；前摇/有效期/后摇、命中与消耗仍由物理动作决定。脚步接触点属于Clip，不能按精灵帧数推断声音次数。参考图若含绘制武器须保持equipment_free=false，不能进入真实角色目录；素材许可与散列须一并登记。
## 视觉与声音扩充

世界物体通过`presentation_profile`接入原生姿态和视觉预制体，区域通过`presentation_environment`接入环境配置，法术沿用`trail_scene / hit_effect / sound_cast / sound_hit`。水井与火球是已运行样本；目录、白名单、预算、真实状态和输入验证见[全游戏表现接入](GAME_PRESENTATION_SYSTEM.md)。表现不提交奖励，不储存第二套采集/机关进度，也不推进玩法随机流。

## NPC服务与任务线索（2026-11-10）

人物的交易/排产话题必须有同actor_id的NpcProfile.market，课程话题必须有同actor_id的training；绑定自己的MarketDefinition/TrainingCatalog，不能借主商店默认配置。地区、前置事实、导航引用与日程须通过跨目录校验；独立派生的交涉事实由章节显式登记。NPC导航用navigation_hints引用地点，不再在response复制坐标与方位。J人情追踪由真实物资、已知采集点与人物生命/日程派生，新增世界条件仍由原进度服务持有。规则与验证见[世界衔接](WORLD_SYSTEM_COHERENCE.md)。
