# 装备系统

装备系统由静态资源、装备负载计算、掉落拾取、UI 和存档五部分组成。新增内容应优先通过 `.tres` 配置完成。

## 数据结构

- `EquipmentData`：装备本体，包含槽位、等级、图标索引、基础属性、战斗修正、词缀和套装。
- `EquipmentAffixData`：可在多件装备间复用的词缀资源。
- `EquipmentSetData`：套装定义，持有多个 `EquipmentSetBonus` 阈值。
- `EquipmentCatalog`：扫描 `res://content/items/equipment` 并提供 ID 查询和稀有度抽取。

固定属性使用 `stat_modifiers`，百分比属性使用 `stat_multipliers`。构筑相关修正使用 `combat_modifiers`，当前支持：

- `damage.all`、`damage.<skill_tag>`
- `cooldown.all`、`cooldown.<skill_tag>`
- `mana_cost.all`、`mana_cost.<skill_tag>`
- `damage_reduction`
- `healing_received`
- `crit_chance`、`crit_damage`

## 运行时约束

`EquipmentManager` 是装备效果的唯一汇总入口。每次换装时先移除旧负载 Buff，再汇总装备、词缀和已解锁套装阈值，最后应用一份新的永久 Buff。不要从 UI 或拾取物直接修改玩家属性。

装备存档保存资源路径和槽位。装备产生的运行时 Buff 不单独保存，加载时由装备资源重建，避免重复叠加。

## 新增装备

1. 在 `content/items/equipment` 新建 `EquipmentData` 资源。
2. 设置唯一 `id`、槽位、稀有度、物品等级和 `icon_atlas_index`。
3. 组合基础属性、战斗修正、词缀和可选套装。
4. 运行 `tests/test_equipment_system.gd`，确认目录数量、唯一 ID、图标和属性可逆性。

## 探索装备与施法构筑（2026-11-05）

探索章节在`content/exploration/equipment/`固定配置4件装备，通过`chapter.tres`登记；旧房间的30件掉落目录保留。两者共用EquipmentData、EquipmentManager、Inventory与属性计算，不另建属性/伤害系统。

| 装备 | 收益 | 代价 | 来源 |
|---|---|---|---|
| 守阵者指环 | 布阵半径+24、寿命+6秒；Shift造地可借阵灌注 | 全法术费用+15%；借阵另消耗1充能与2 MP（修正前） | 档案室震荡记录 |
| 游魂吊坠 | 蕴魂容量+2、汲魂范围+60 | 最大生命-15 | 祈堂储备 |
| 灰烬契印 | 每份恩赐释放伤害倍率+0.25 | 每份额外2 MP；新获得可释放恩赐时长-25% | 火药库守卫补给 |
| 节律护手 | 条件施法准备时间-20%；Shift保留恩赐当前剩余时长50%，保留形态强化 | 全法术费用+15%；部分消费使用保留伤害倍率，每份额外3 MP | 机房雷阵实验记录 |

两个指环使用同一戒指槽。CastingEquipmentProfile提供8个类型化字段，不使用未经验证的字符串脚本。费用仍走CastCostPolicy；恩赐释放修正只影响主动消费，时长修正只影响新获得的可释放恩赐。布阵半径限制48—180，寿命5—40秒，准备倍率0.5—1.5。

Profile另提供`medium_infusion`能力及其成本。EquipmentManager支持当前与候选负载的能力查询；MediumInfusion在材料、恩赐之后读取同一地面反应表，选最新的可反应法阵，借一份充能改变介质而保留落点。无反应不花资源，已有结果已经用阵则不重复借用。该能力不添加新技能或改变命中标签，详见[涌现施法设计](./EMERGENT_CASTING_DESIGN.md)。

ExpeditionEquipment处理章节所有权、奖励、营地装备请求与比较，实际效果仍由EquipmentManager汇总；未穿戴物品回到已有背包。O显示来源、取舍与预计施法参数，I背包遵守同一营地边界。换装推进版本，使旧准备取消且不扣费；降低魂量容量立即裁至新上限。记录`equipment_owned / equipment_loadout`，旧存档缺失时默认空；已领取发现新增装备自动补领，不强制装备。

部分消费由Profile的能力开关及成本声明，经EquipmentManager查询，由恩赐规划与CastTransaction提交；候选装备比较展示从完整消费到部分消费的变化。来源、剩余时长与版本支持失败回滚；蕴魂/回响/护盾不受影响。详见[当前交付](./FIVE_ELEMENT_IMPLEMENTATION.md)。
