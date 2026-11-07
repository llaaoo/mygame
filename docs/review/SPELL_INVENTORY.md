# 当前施法资源清单

由 `tools/audit_spell_system.gd` 从灰河谷登记动作、操作目录、组合规则、物品用途、元素与地面定义生成。数值为定义基础值，不含属性、疲劳、装备和恩赐修正；材料描述中的制造配方不等于法术组合。完整字段见 [JSON](spell_inventory.json)。历史升级分支的被动触发不代表当前动作可装备。effect_definitions包含49个临时组合变体及其引用的旧结果/升级定义，不是独立技能数量；statuses统计由Resource与显式路径引用到的Buff定义；武器涂层、生存食品计时和地面状态另列，不混算。

## 基础动作

| ID | 动作 | 输入形态 | 基础MP | 冷却 | 准备 |
|---|---|---|---|---|---|
| ignite | 火花 |  | 4 | 0.6 | 0.25 |
| pulse | 震荡 |  | 3 | 0.8 | 0.25 |
| focus | 调谐 |  | 4 | 4.0 | 0.25 |
| water_call | 水引 |  | 5 | 1.5 | 0.25 |
| soul_harvest | 汲取 |  | 4 | 0.8 | 0.55 |
| project | 聚能投射 | charge | 18 | 5.0 | 0.25 |
| shape | 塑形 |  | 24 | 8.0 | 0.8 |
| step | 移形 |  | 18 | 6.0 | 0.15 |
| sustain | 引导介质 | channel | 12.0MP/秒，0.4秒结算 | 0.1 | 0.0 |
| inscribe | 铭刻法阵 |  | 8 | 8.0 | 0.8 |
| disperse | 喷洒介质 |  | 2 | 0.5 | 0.25 |

## 动作与介质

| 动作 | 介质/样式 | 实物 | 现场来源 | 基础总MP | 结果 |
|---|---|---|---|---|---|
| 铭刻法阵 | 凝能阵 `arcane` | 无 | 无 | 8 | arcane  |
| 铭刻法阵 | 火石阵 `ember` | fire_stone ×1 | 无 | 8 | fire  |
| 铭刻法阵 | 霜盐阵 `frost` | frost_salt ×1 | 无 | 8 | frost  |
| 铭刻法阵 | 雷晶阵 `storm` | storm_dust ×1 | 无 | 9 | storm  |
| 铭刻法阵 | 守护法阵 `ward_rune` | ward_powder ×1 | 无 | 8 | ward  |
| 喷洒介质 | 清水喷洒 `water` | water_sprayer ×1 | 无 | 2 |  wet |
| 喷洒介质 | 毒性喷洒 `venom` | venom_sprayer ×1 | 无 | 4 |  poisoned |
| 喷洒介质 | 浓毒喷洒 `potent` | potent_sprayer ×1 | 无 | 5 |   |
| 喷洒介质 | 麻痹喷洒 `paralytic` | paralytic_sprayer ×1 | 无 | 4 |   |
| 喷洒介质 | 树脂喷洒 `resin` | resin_sprayer ×1 | 无 | 2 |  oiled |
| 调谐 | 纯粹凝神 `basic` | 无 | 无 | 4 | focus |
| 调谐 | 回响铭印 `echo` | echo_ink ×1 | 无 | 6 | echo_mark |
| 调谐 | 守护调谐 `ward` | ward_powder ×1 | 无 | 10 | resonant_guard |
| 调谐 | 火阵调谐 `attune_fire` | 无 | field:fire | 4 | ember_focus |
| 调谐 | 霜阵调谐 `attune_frost` | 无 | field:frost | 4 | frost_stride |
| 调谐 | 雷阵调谐 `attune_storm` | 无 | field:storm | 4 | static_focus |
| 调谐 | 凝能阵调谐 `attune_arcane` | 无 | field:arcane | 4 | focus |
| 调谐 | 守护阵调谐 `attune_ward` | 无 | field:ward | 4 | resonant_guard |
| 调谐 | 霜盐护甲 `ice_armor` | frost_salt ×1 | field:frost | 25 | ice_armor |
| 汲取 | 真实残魂 `soul_source` | 无 | soul: | 4 | soul_harvest |
| 汲取 | 火阵充能 `extract_fire` | 无 | field:fire | 4 | extract_fire |
| 汲取 | 霜阵充能 `extract_frost` | 无 | field:frost | 4 | extract_frost |
| 汲取 | 雷阵充能 `extract_storm` | 无 | field:storm | 4 | extract_storm |
| 汲取 | 凝能阵充能 `extract_arcane` | 无 | field:arcane | 4 | extract_arcane |
| 汲取 | 守护阵充能 `extract_ward` | 无 | field:ward | 4 | extract_ward |
| 聚能投射 | 火石核心 `charged_fireball` | fire_stone ×1 | field:fire | 20 | charged_fireball |
| 聚能投射 | 树脂散射 `cinder_volley` | resin ×1 | field:fire | 20 | cinder_volley |
| 聚能投射 | 炭屑重核 `ember_orb` | charcoal ×1 | field:fire | 24 | ember_orb |
| 聚能投射 | 霜盐追踪核 `glacial_orb` | frost_salt ×1 | field:frost | 18 | glacial_orb |
| 聚能投射 | 雷晶追踪核 `thunder_orb` | storm_dust ×1 | field:storm | 23 | thunder_orb |
| 聚能投射 | 清水追踪核 `tidal_orb` | clean_water ×1 | field:arcane | 18 | tidal_orb |
| 聚能投射 | 毒萃穿刺 `plague_bolt` | venom_extract ×1 | field:arcane | 18 | plague_bolt |
| 聚能投射 | 回响暗蚀 `shadow_bolt` | echo_ink ×1 | field:arcane | 18 | shadow_bolt |
| 聚能投射 | 守护粉贯穿 `solar_spear` | ward_powder ×1 | field:fire | 32 | solar_spear |
| 塑形 | 树脂焚区 `magma_pool` | resin ×1 | field:fire | 30 | magma_pool |
| 塑形 | 火石爆区 `flame_storm` | fire_stone ×1 | field:fire | 35 | flame_storm |
| 塑形 | 霜盐暴雪 `blizzard` | frost_salt ×1 | field:frost | 42 | blizzard |
| 塑形 | 雷晶雷场 `storm_field` | storm_dust ×1 | field:storm | 32 | storm_field |
| 塑形 | 雷晶近身三脉冲 `static_nova` | storm_dust ×1 | field:storm | 24 | static_nova |
| 塑形 | 毒萃瘴环 `miasma_ring` | venom_extract ×1 | field:arcane | 36 | miasma_ring |
| 塑形 | 浓毒爆区 `venom_burst` | potent_venom ×1 | field:arcane | 24 | venom_burst |
| 塑形 | 守护再生 `radiant_aegis` | ward_powder ×1 | field:ward | 28 | radiant_aegis |
| 塑形 | 晶砂构体 `summon_golem` | crystal ×1 | field:arcane | 44 | summon_golem |
| 塑形 | 铭刻灰与真实残魂 `summon_skeleton` | ash ×1 | soul: | 30 | summon_skeleton |
| 塑形 | 炭屑火灵 `summon_wisp` | charcoal ×1 | field:fire | 24 | summon_wisp |
| 移形 | 晶砂短移 `arcane_dash` | crystal ×1 | field:arcane | 18 | arcane_dash |
| 移形 | 墨印突袭 `shadow_step` | echo_ink ×1 | field:arcane | 20 | shadow_step |
| 移形 | 铭刻灰长移 `phase_blink` | ash ×1 | field:arcane | 22 | phase_blink |
| 引导介质 | 霜盐冰风暴 `ice_storm` | frost_salt ×1 | 无 | 0 + 12.0MP/秒 | ice_storm |

## 条件组合

| ID | 动作 | 条件 | 结果 | 基础MP |
|---|---|---|---|---|
| fire_sigil_fireball | ignite | 火阵 | 火球术 | 12 |
| fire_sigil_pulse | pulse | 火阵 | 火阵喷发 | 14 |
| frost_sigil_spark | ignite | 霜阵 | 寒霜弹 | 10 |
| frost_sigil_pulse | pulse | 霜阵 | 寒霜新星 | 12 |
| fire_sigil_focus | focus | 火阵 | 余烬战意 | 10 |
| frost_sigil_focus | focus | 霜阵 | 霜行 | 10 |
| storm_sigil_spark | ignite | 雷阵 | 雷矢 | 11 |
| storm_sigil_pulse | pulse | 雷阵 | 雷环 | 13 |
| storm_sigil_focus | focus | 雷阵 | 雷息 | 10 |
| echo_spark | ignite | 回响印记 | 回响三重矢 | 12 |
| echo_pulse | pulse | 回响印记 | 回响脉冲 | 14 |
| echo_focus | focus | 回响印记 | 共鸣护盾 | 10 |
| echo_water | water_call | 回响印记 | 回响复苏 | 9 |
| echo_venom | venom_mist | 回响印记 | 腐蚀孢子 | 12 |
| guard_pulse | pulse | 共鸣护盾 + Shift | 守护爆破 | 8 |
| soul_spark | ignite | 蕴魂 + Shift | 魂焰矢 | 9 |
| soul_pulse | pulse | 蕴魂 + Shift | 魂霜震荡 | 10 |
| soul_focus | focus | 蕴魂 + Shift | 先祖护佑 | 8 |
| soul_water | water_call | 蕴魂 + Shift | 净魂 | 7 |
| terrain_fire_focus | focus | 脚下燃烧地面（消耗1格）或树脂制剂×1 + Shift | 余烬战意 | 10 |
| terrain_water_focus | focus | 脚下水域（消耗1格） + Shift | 流息 | 8 |
| terrain_frost_focus | focus | 脚下冰面（消耗1格）或霜盐×1 + Shift | 霜行 | 10 |
| terrain_lightning_focus | focus | 脚下导电水域（消耗1格）或雷晶粉×1 + Shift | 雷息 | 10 |
| terrain_poison_focus | focus | 脚下毒地（消耗1格）或毒性萃取×1 + Shift | 毒契 | 8 |
| arcane_pulse | pulse | 凝能阵 | 凝能震荡 | 8 |
| ward_focus | focus | 守护阵 | 共鸣护盾 | 10 |
| ward_pulse | pulse | 守护阵 | 守护爆破 | 10 |
| fire_energy_ignite | ignite | stored_fire + Shift | 火球术 | 10 |
| fire_energy_pulse | pulse | stored_fire + Shift | 火阵喷发 | 10 |
| frost_energy_ignite | ignite | stored_frost + Shift | 寒霜弹 | 10 |
| frost_energy_pulse | pulse | stored_frost + Shift | 寒霜新星 | 10 |
| storm_energy_ignite | ignite | stored_storm + Shift | 雷矢 | 10 |
| storm_energy_pulse | pulse | stored_storm + Shift | 雷环 | 10 |
| arcane_energy_ignite | ignite | stored_arcane + Shift | 凝能震荡 | 10 |
| arcane_energy_pulse | pulse | stored_arcane + Shift | 凝能震荡 | 10 |
| ward_energy_ignite | ignite | stored_ward + Shift | 守护爆破 | 10 |
| ward_energy_pulse | pulse | stored_ward + Shift | 守护爆破 | 10 |

## 单次修饰材料

| ID | 名称 | 额外MP | 作用 |
|---|---|---|---|
| ash | 铭刻灰 | 2 | 火/霜法阵持续时间+10秒，额外2 MP；不增加触发次数。 |
| resin | 树脂制剂 | 4 | 强化火球或魂焰矢：飞行减慢20%，命中留下半径80的6秒燃烧区，额外4 MP。 |
| frost_salt | 霜盐 | 2 | 冰/水投射物或范围法术适配：寒霜弹穿透+1、范围半径+30；造水先凝成冰面，额外2 MP。 |
| storm_dust | 雷晶粉 | 4 | 铭刻雷阵的必需媒介；雷矢或水系投射物变三发散射，每发伤害70%；造水同时导电，可能波及自己与相连水域，额外4 MP。 |
| echo_ink | 回响墨 | 3 | 回响铭印的必需媒介；也可让回响三重矢每发或魂焰矢额外穿透1个目标，额外3 MP。 |
| venom_extract | 毒性萃取 | 3 | 毒雾的必需媒介；冰/水投射物或范围法术附毒，造水形成毒地、失去洗毒用途，额外3 MP。 |
| ward_powder | 守护粉 | 2 | 延长凝神恩赐、共鸣护盾、先祖护佑或净魂保护4秒，额外2 MP；不延长蕴魂或回响印记。 |

## 物品动作

| ID | 名称 | 类型 | 准备秒 | 体力 | 容量 | 投送距离 |
|---|---|---|---|---|---|---|
| poison_rag | 毒抹布 | COATING | 1.2 | 0.0 | 3 | 360.0 |
| fire_rag | 火焰抹布 | COATING | 1.2 | 0.0 | 3 | 360.0 |
| oil_bottle | 火油瓶 | THROWABLE | 0.5 | 8.0 | 3 | 360.0 |
| venom_bottle | 毒瓶 | THROWABLE | 0.5 | 8.0 | 3 | 360.0 |
| paralytic_bottle | 麻痹瓶 | THROWABLE | 0.5 | 8.0 | 3 | 360.0 |
| water_sprayer | 清水喷剂 | SPRAY | 1.2 | 0.0 | 3 | 360.0 |
| resin_sprayer | 树脂喷剂 | SPRAY | 1.2 | 0.0 | 3 | 360.0 |
| venom_sprayer | 毒性喷剂 | SPRAY | 1.2 | 0.0 | 3 | 360.0 |
| potent_sprayer | 浓毒喷剂 | SPRAY | 1.2 | 0.0 | 3 | 360.0 |
| paralytic_sprayer | 麻痹喷剂 | SPRAY | 1.2 | 0.0 | 3 | 360.0 |

## Buff与状态

同ID可有不同来源定义/运行变体，下表逐项展示，不能当作可叠加状态数量。临时能量同属一个互斥组；食物计时与具体武器涂层另由生存/物品服务管理。

| ID | 名称 | 时长 | 层数 | 互斥组 | 周期伤/治疗 | 控制 | 可兑现 | 效果 |
|---|---|---|---|---|---|---|---|---|
| focus | 凝神 | 5.0 | 1 | sigil_attunement | 0 / 0 | false | false | 凝神: 移速 ×1.08 5.0s |
| soul_charge | 蕴魂 | 45.0 | 3 |  | 0 / 0 | false | false | 蕴魂: 普通施法保留；Shift＋火花/震荡/凝神/水引各兑现1层。汲魂刷新持续时间，不超容量；跨区域清理。 45.0s |
| soul_charge | 蕴魂 | 45.0 | 3 | stored_energy | 0 / 0 | false | false | 蕴魂: 普通施法保留；Shift＋火花/震荡/凝神/水引各兑现1层。汲魂刷新持续时间，不超容量；跨区域清理。 45.0s |
| washing | 冲洗 | 0.1 | 1 |  | 0 / 0 | false | false | 冲洗: 净化：中毒、麻痹、燃烧 0.1s |
| poison | 萃取毒素 | 5.0 | 1 |  | 3 / 0 | false | false | 萃取毒素: DOT 3/1.0s 5.0s |
| poison | 浓缩毒素 | 8.0 | 1 |  | 6 / 0 | false | false | 浓缩毒素: DOT 6/1.0s 8.0s |
| poison | 中毒 | 5.0 | 5 |  | 3 / 0 | false | false | 中毒: DOT 3/1.0s 5.0s |
| paralysis | 麻痹 | 1.5 | 1 |  | 0 / 0 | true | false | 麻痹: 移速 ×0.00 1.5s |
| echo_ready | 回响印记 | 12.0 | 1 | echo_preparation | 0 / 0 | false | false | 回响印记: no modifiers 12.0s |
| resonant_guard | 共鸣护盾 | 8.0 | 1 | sigil_attunement | 0 / 0 | false | false | 共鸣护盾: 受到伤害 x0.60 8.0s |
| ember_focus | 余烬战意 | 10.0 | 1 | sigil_attunement | 0 / 0 | false | true | 余烬战意: 近战攻击+8, 近战附加火焰, 火焰法术伤害 x1.20（保留）, Shift消耗：燃尽余烬（额外3 MP） 10.0s |
| frost_stride | 霜行 | 8.0 | 1 | sigil_attunement | 0 / 0 | false | true | 霜行: 移速 ×1.30, 凝霜法术伤害 x1.20（保留）, Shift消耗：碎霜（额外3 MP） 8.0s |
| static_focus | 雷息 | 9.0 | 1 | sigil_attunement | 0 / 0 | false | true | 雷息: 移速 ×1.15, Shift消耗：雷息过载（额外3 MP） 9.0s |
| ice_armor | 冰霜护盾 | 8.0 | 1 |  | 0 / 0 | false | false | 冰霜护盾: 生命上限+40 8.0s |
| stored_fire | 蕴能 · 火 | 45.0 | 3 | stored_energy | 0 / 0 | false | false | 蕴能 · 火: Shift＋火花/震荡手动兑现1层；更换能量类型替换原有能量，跨区域清理。 45.0s |
| stored_frost | 蕴能 · 霜 | 45.0 | 3 | stored_energy | 0 / 0 | false | false | 蕴能 · 霜: Shift＋火花/震荡手动兑现1层；更换能量类型替换原有能量，跨区域清理。 45.0s |
| stored_storm | 蕴能 · 雷 | 45.0 | 3 | stored_energy | 0 / 0 | false | false | 蕴能 · 雷: Shift＋火花/震荡手动兑现1层；更换能量类型替换原有能量，跨区域清理。 45.0s |
| stored_arcane | 蕴能 · 凝能 | 45.0 | 3 | stored_energy | 0 / 0 | false | false | 蕴能 · 凝能: Shift＋火花/震荡手动兑现1层；更换能量类型替换原有能量，跨区域清理。 45.0s |
| stored_ward | 蕴能 · 守护 | 45.0 | 3 | stored_energy | 0 / 0 | false | false | 蕴能 · 守护: Shift＋火花/震荡手动兑现1层；更换能量类型替换原有能量，跨区域清理。 45.0s |
| radiant_aegis | 辉光圣盾 | 8.0 | 1 |  | 0 / 6 | false | false | 辉光圣盾: 生命上限+20, HOT 6/1.5s 8.0s |
| shadow_step | 暗影步 | 3.0 | 1 |  | 0 / 0 | false | false | 暗影步: 近战攻击+25 3.0s |
| restoring_echo | 回响复苏 | 4.3 | 1 | echo_restoration | 0 / 6 | false | false | 回响复苏: HOT 6/1.0s 4.3s |
| ancestral_ward | 先祖护佑 | 8.0 | 1 | ancestral_boon | 0 / 0 | false | true | 先祖护佑: 受到伤害 x0.75, 火焰/凝霜/雷电/arcane法术伤害 x1.15（保留）, Shift消耗：先祖回声（额外2 MP）, 保留减伤与15%法术增益；Shift伤害施法消费护佑，增加伤害和穿透，额外2 MP。 8.0s |
| clear_mind | 清明 | 6.0 | 1 |  | 0 / 0 | false | false | 清明: 净化：燃烧、中毒、感电, 保护：燃烧、中毒、感电, 净化并阻止燃烧、中毒、感电；不能阻挡直接伤害或冻结。 6.0s |
| flow_attunement | 流息 | 8.0 | 1 | sigil_attunement | 0 / 0 | false | true | 流息: 受到伤害 x0.90, 水系法术伤害 x1.10（保留）, Shift消耗：涌流（额外3 MP）, 净化：燃烧 8.0s |
| venom_accord | 毒契 | 8.0 | 1 | sigil_attunement | 0 / 0 | false | true | 毒契: 毒法术伤害 x1.15（保留）, Shift消耗：蚀散（额外3 MP）, 净化：中毒, 保护：中毒 8.0s |
| burning | 燃烧 | 4.0 | 3 |  | 5 / 0 | false | false | 燃烧: DOT 5/1.0s 4.0s |
| wet | 潮湿 | 6.0 | 1 |  | 0 / 0 | false | false | 潮湿: no modifiers 6.0s |
| frozen | 冻结 | 3.0 | 1 |  | 0 / 0 | false | false | 冻结: 移速 ×0.30 3.0s |
| shocked | 感电 | 2.0 | 1 |  | 4 / 0 | false | false | 感电: DOT 4/1.0s, 移速 ×0.85 2.0s |
| steam_veil | 蒸汽迟滞 | 2.0 | 1 |  | 0 / 0 | false | false | 蒸汽迟滞: 移速 ×0.85, 投射物直接伤害 x0.75, 投射物直接伤害降低25%；近战、范围与持续伤害不变。接触蒸汽刷新2秒，离开后自然消退。 2.0s |

## 命中反应

| ID | 名称 | 条件与效果 |
|---|---|---|
| melt | 融化 | 火焰命中冻结目标时造成 60% 额外伤害并移除冻结。 |
| vaporize | 蒸发 | 火球命中潮湿目标时额外造成30%伤害，并消耗潮湿。 |
| toxic_ignition | 毒焰引爆 | 火焰命中中毒目标时造成 75% 额外伤害并消耗中毒。 |
| deep_freeze | 凝冻 | 寒霜弹或寒霜新星命中潮湿目标时额外造成30%伤害，消耗潮湿并保留冻结。 |
| conduction | 导电 | 闪电命中潮湿目标时造成 45% 额外伤害。 |
| static_overload | 雷息共鸣 | 雷息期间，雷矢或雷环命中额外造成35%伤害。 |
| steam_burst | 蒸汽爆裂 | 冰或水命中燃烧目标时造成 50% 额外伤害并扑灭燃烧。 |
| shadow_decay | 腐影 | 暗影命中中毒目标时造成 40% 额外伤害，不消耗中毒。 |
| shatter | 碎冰 | 震荡或回响脉冲命中已冻结目标时额外造成50%伤害并打碎冻结；消耗控制时间换取爆发。 |

## 地面反应

| 原状态 | 命中标签 | 新状态 | 持续秒 |
|---|---|---|---|
| oiled | ["fire"] | burning | 8.0 |
| wet | ["ice"] | frozen | 5.0 |
| wet | ["fire"] | steam | 3.0 |
| burning | ["ice"] | dry | 0.0 |
| burning | ["water"] | dry | 0.0 |
| dry | ["fire"] | burning | 5.0 |
| dry | ["ice"] | frozen | 4.0 |
| frozen | ["impact"] | wet | 4.0 |
| wet | ["lightning"] | electrified | 5.0 |
| frozen | ["fire"] | wet | 5.0 |
| dry | ["water"] | wet | 12.0 |
| electrified | ["ice"] | frozen | 4.0 |
| poisoned | ["fire"] | burning | 6.0 |
| poisoned | ["water"] | wet | 8.0 |
| poisoned | ["ice"] | frozen | 4.0 |
| wet | ["poison"] | poisoned | 8.0 |

## 材料职责与制造联动

| ID | 名称 | 可作修饰 | 主介质用途 | 制造投入 | 制造产出 |
|---|---|---|---|---|---|
| ash | 铭刻灰 | true | ["塑形/铭刻灰与真实残魂", "移形/铭刻灰长移"] | ["ward_powder"] | ["ash"] |
| resin | 树脂制剂 | true | ["聚能投射/树脂散射", "塑形/树脂焚区"] | ["fire_rag", "oil_bottle", "resin_sprayer"] | ["resin"] |
| frost_salt | 霜盐 | true | ["铭刻法阵/霜盐阵", "调谐/霜盐护甲", "聚能投射/霜盐追踪核", "塑形/霜盐暴雪", "引导介质/霜盐冰风暴"] | [] | ["frost_salt"] |
| storm_dust | 雷晶粉 | true | ["铭刻法阵/雷晶阵", "聚能投射/雷晶追踪核", "塑形/雷晶雷场", "塑形/雷晶近身三脉冲"] | [] | ["storm_dust"] |
| echo_ink | 回响墨 | true | ["调谐/回响铭印", "聚能投射/回响暗蚀", "移形/墨印突袭"] | [] | ["echo_ink"] |
| venom_extract | 毒性萃取 | true | ["聚能投射/毒萃穿刺", "塑形/毒萃瘴环"] | ["potent_venom", "poison_rag", "venom_bottle", "venom_sprayer"] | ["venom_extract"] |
| ward_powder | 守护粉 | true | ["铭刻法阵/守护法阵", "调谐/守护调谐", "聚能投射/守护粉贯穿", "塑形/守护再生"] | [] | ["ward_powder"] |
| fire_stone | 火石 | false | ["铭刻法阵/火石阵", "聚能投射/火石核心", "塑形/火石爆区"] | [] | ["fire_stone"] |
| water_sprayer | 清水喷剂 | false | ["喷洒介质/清水喷洒"] | [] | ["water_sprayer"] |
| venom_sprayer | 毒性喷剂 | false | ["喷洒介质/毒性喷洒"] | [] | ["venom_sprayer"] |
| potent_sprayer | 浓毒喷剂 | false | ["喷洒介质/浓毒喷洒"] | [] | ["potent_sprayer"] |
| paralytic_sprayer | 麻痹喷剂 | false | ["喷洒介质/麻痹喷洒"] | [] | ["paralytic_sprayer"] |
| resin_sprayer | 树脂喷剂 | false | ["喷洒介质/树脂喷洒"] | [] | ["resin_sprayer"] |
| charcoal | 炭屑 | false | ["聚能投射/炭屑重核", "塑形/炭屑火灵"] | ["ash", "storm_dust", "venom_extract", "fire_stone", "fire_rag"] | [] |
| clean_water | 饮用水 | false | ["聚能投射/清水追踪核"] | ["water_sprayer", "resin_sprayer", "venom_sprayer", "potent_sprayer", "paralytic_sprayer"] | [] |
| potent_venom | 浓缩毒剂 | false | ["塑形/浓毒爆区"] | ["potent_sprayer"] | ["potent_venom"] |
| crystal | 晶砂 | false | ["塑形/晶砂构体", "移形/晶砂短移"] | ["frost_salt", "storm_dust", "echo_ink", "ward_powder", "fire_stone", "paralytic_extract"] | [] |
| sap | 树液 | false | [] | ["resin", "echo_ink", "venom_extract"] | [] |
| herb | 苦叶 | false | [] | ["paralytic_extract", "potent_venom"] | [] |
| paralytic_extract | 麻痹萃取 | false | [] | ["paralytic_bottle", "paralytic_sprayer"] | ["paralytic_extract"] |
| cloth | 布料 | false | [] | ["poison_rag", "fire_rag"] | [] |
| poison_rag | 毒抹布 | false | [] | [] | ["poison_rag"] |
| fire_rag | 火焰抹布 | false | [] | [] | ["fire_rag"] |
| oil_bottle | 火油瓶 | false | [] | [] | ["oil_bottle"] |
| venom_bottle | 毒瓶 | false | [] | [] | ["venom_bottle"] |
| paralytic_bottle | 麻痹瓶 | false | [] | [] | ["paralytic_bottle"] |

## 制造配方

| 产物 | 数量 | 原料 |
|---|---|---|
| ash | 1 | { "charcoal": 1 } |
| resin | 1 | { "sap": 2 } |
| frost_salt | 1 | { "crystal": 2 } |
| storm_dust | 1 | { "crystal": 1, "charcoal": 1 } |
| echo_ink | 1 | { "crystal": 1, "sap": 1 } |
| venom_extract | 1 | { "sap": 2, "charcoal": 1 } |
| ward_powder | 1 | { "ash": 1, "crystal": 1 } |
| fire_stone | 1 | { "charcoal": 2, "crystal": 1 } |
| paralytic_extract | 1 | { "herb": 2, "crystal": 1 } |
| potent_venom | 1 | { "venom_extract": 2, "herb": 1 } |
| poison_rag | 1 | { "venom_extract": 1, "cloth": 1 } |
| fire_rag | 1 | { "resin": 1, "charcoal": 1, "cloth": 1 } |
| oil_bottle | 1 | { "resin": 2 } |
| venom_bottle | 1 | { "venom_extract": 2 } |
| paralytic_bottle | 1 | { "paralytic_extract": 2 } |
| water_sprayer | 1 | { "clean_water": 1 } |
| resin_sprayer | 1 | { "resin": 1, "clean_water": 1 } |
| venom_sprayer | 1 | { "venom_extract": 1, "clean_water": 1 } |
| potent_sprayer | 1 | { "potent_venom": 1, "clean_water": 1 } |
| paralytic_sprayer | 1 | { "paralytic_extract": 1, "clean_water": 1 } |
