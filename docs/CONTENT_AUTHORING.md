# 内容接入与系统扩展

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
| 采集/机关/委托 | 原灰河谷定义、`SurvivalStationData`及探索Resource | 原现场作业、库存、世界事实与进度服务 |

新增定义并不自动授予玩家：必须同时提供真实来源，如资源点、工作台配方、店家库存、敌人穿戴/行囊、训练师课程或技能书。只有新的空间行为、动作节奏或领域语义才需要扩展执行代码。增加地图上的服务人物仍需场景/入口装配，不能把登记目录误认为自动生成NPC。

## 食品示例

1. 创建物品定义并登记物品目录，提供采集/制造/购买来源。
2. 创建`Buff`，配置`provision_id`为物品ID、`provision_group`为`meal/water/tea`之一。同组使用同一个非空`exclusive_group`，确保替换而非叠加。期限、属性、生命/法力/体力恢复写在这份定义。
3. 创建`ProvisionDefinition`，设置饱食、饮水、疲劳、准备秒数、描述和上面的效果，加入食品目录。原快捷物品与补给页会使用同一准备和消费路径。

`meal`是食物槽，饮水和茶各有独立槽；污染水可以引用原中毒定义而不占恢复槽。需要第四种并存恢复槽属于新语义，应明确增加规则及UI，不能借不同互斥组偷偷堆叠同一槽。

## 学习与专精示例

- 新武技加入武技目录后，K页、知识快照、快捷绑定和原动作执行会查询目录，不再追加硬编码ID列表。
- `prerequisites`引用武技ID；`exclusive_group`表示学习后互斥的专精。验证器拒绝未知前置、循环及自相矛盾的互斥前置链。已保存的旧知识不因新前置追溯删除。
- 课程的`requirements`使用现有`WorldCondition`：探索发现、清场、实物、关系、法术知识。每项写面向玩家的`hint`。课程可使用不同费用和条件，技能书可提供另一条获取路径；能力自身的武技前置/互斥仍对书生效。
- 现有横扫课程要求携带实际战杖（已装备也算）；技能书机制支持另一条获取路径，当前实际书是贯步刺。训练师配置还持有角色ID、工作/休息位置和日程，场景入口注入该配置。课程条件在确认时重验；对方装不下付款时不留下半份知识或付款。

## 排产示例

新增`ProductionDefinition`：填稳定ID、生产者库存所有者ID、现有配方与每批游戏小时，再加入排产目录。绑定该所有者的整修铺会列出对应配方。

订单表示排程意图，不预扣原料或锁定货品。玩家可以把真实采集材料卖给店家；店家在工期完成时原子消费自己实际持有的配方原料，产出归店家，再按原交易规则出售。缺料/满库会等候，解除后重新计算完整工期；不把阻塞时间积攒成瞬间产量。停止订单不会凭空退款，已完成批次也不会撤回。

现有箭、火石与石肤药剂只复用旧配方/预算作为接入样本。排产不制造河谷币，不重置原库存，不自动搜集或采购原料。这个边界支持供货、加工和购买循环，尚不是完整城镇生产经济。

## 登记与兼容要求

- Resource是共享定义，运行时不能修改。UID、订单截止时间、批数、知识与冷却分别由现有领域服务持有。
- 稳定ID属于存档协议；不能随意删除/改名已发布的物品、武技、订单或状态定义。变更先补迁移，不能靠忽略未知条目丢掉旧资产。
- 先跑`python3 tools/run_tests.py --tests content`，再跑对应领域及输入验证。新行为覆盖失败、费用、容量、重复请求、离区、死亡、F9和重新进入；跨系统变更按AGENTS跑无缓存归档全套。
- 内容定义可复用当前系统；新投送形态、武器类型、食品槽或NPC服务行为仍要明确设计，不能声称任意内容都无需代码。
