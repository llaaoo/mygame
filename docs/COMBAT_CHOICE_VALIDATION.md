# 出售、连招双选与可用施法形式验证

2026-11-09，云端Linux，Godot 4.6.3。当前规则见[操作](CONTROL_SCHEME.md)及[武技](WEAPON_ART_ROUTES.md)。本轮复用灰河谷地图、敌人、配方、物品与预算。

## 已修复的系统原因

- 单件交易原先先付钱、后移货；双方满包时，出售物即使能腾格也先被拒绝。现在同一原子交换先取出双方付出，再接收所得，并限制货物为请求的具体UID；预览完全只读，失败不扣物/钱。整修铺显示穿戴装备、显式卸下入口、容量/资金等拒绝原因。
- 武技配装与瞬时选择分开：MartialArts保存每组最多两个路线引用；WeaponArtState保存当前动作的选择和截止事实。Ctrl轻点只改变选择，Ctrl+左键不触发额外切换。V及逐招快捷释放退役，旧存档保留知识并释放旧武技槽位；输入仍走同一物理动作/命中/成本边界。
- 战斗轮盘原本展示全目录且保留失效条目；现在以实际CastPlan筛选可执行的具体介质和修饰，普通与耗材形式并列。确认再次校验；打开期间扇区身份不滑动，条件丢失撤销悬停，不能松键选到替代源。K保留完整整备目录。
- 组合操作的输入ID与实际效果ID不同。材料兼容现在经SpellOperationData统一解析实际效果，轮盘、K与实际施法共用；守护粉延长凝神等已有效果不再因操作改名而失配。规则仍由原材料Resource定义，没有第二套施法条件。

## 回归覆盖

- `foundation_inventory`：双方满容器仍成功出售、只读预览、指定同名物品UID、资金守恒与不足回滚、放下目标背包时拒绝交易且库存/货款不变。原装备/涂层/喷剂回归继续验证实例属性和余量。
- `weapon_art_routes`：四武器序列、双选切换不续时/不扣费用、捕获后选中锁定、两槽上限、故意留空与保存、来源/令牌/装备/期限失效及原动作承诺。
- `weapon_art_input`：实际键鼠轻击、长按重击、Ctrl+左键在四武器发动，命中接势与同连招Ctrl切换，旧直接键拒绝，菜单阻断与F5/F9清理；弓各次轻/重/武技共三支实物箭，MP保持60。
- `contextual_choices`：无耗材/有耗材铭刻、火阵中普通与树脂修饰火球、凝神与火阵调谐的普通/守护粉形式，缺场地/超距/材料/法力过滤、确认重验、完整整备目录、真实增益/耗材/MP及旧武技槽迁移。
- `combat_choices_input`：F整修铺、鼠标卸下/出售指定UID、满包货款、K移除/重新装备两招、按住轮盘期间真实材料丢失且松键不换源、小窗口详情边界、实际保存退出重进。
- 原有附魔、推敌入火地、操作响应、接势、轮盘多瓶及智能跟随测试改走当前真实输入契约；不保留已经移除的V/E武技释放断言。

## 平台与限制

原生图形为Xorg、1152×648及960×600、Compatibility/OpenGL、Mesa软件渲染、Dummy音频。测试通过真实Godot键鼠事件与可见控件，未用按钮信号替代点击。世界时间、自然恢复与背景AI运行；库存、知识、初始位置受控，命中验证使用停止移动/决策的既有敌人。用于功能和输入验收，不代表自然开荒、真人手感、两小时通关、音频听感或目标机器性能。

## 原生图形实测

两份脚本均正常退出0，无脚本/运行错误。Xorg软件驱动报告不支持V-Sync切换，属于平台限制；未据此修改游戏计时。

- [商店、K配装与轮盘日志](playtests/combat-choices/shop-input.log)、[录像](playtests/combat-choices/shop-input.mp4)。满包用例先令玩家口袋12/12、背包30/30、无币堆，出售整件实物后得到8币，店家扣8币，指定UID进入店家背包；实际重进仍保留。K移除再装入后顺序为`staff_sweep/power_followup`、`staff_sweep/power`，重进不变。
- [武技日志](playtests/combat-choices/weapon-arts-input.log)、[录像](playtests/combat-choices/weapon-arts-input.mp4)。四武器真实轻→重→Ctrl+左键全部发动；弓箭8→5，MP始终60。同连招轻点Ctrl后选中`power_followup`，发动前仍余0.9593秒，随后执行同一接势路线；没有刷新到1.1秒或被发动组合键改回另一招。截图放在发动后，避免文件编码占用输入窗口。
- [穿戴装备](playtests/combat-choices/shop-worn-item.png)、[满包出售](playtests/combat-choices/shop-full-bag-sale.png)、[双招配装](playtests/combat-choices/two-art-loadout.png)、[失效材料撤销悬停](playtests/combat-choices/wheel-lost-material.png)、[960×600商店](playtests/combat-choices/shop-small-window.png)、[切换后发动](playtests/combat-choices/same-combo-second-art.png)。小窗口详情宽499，滚动视口宽507，所有可见详情标签均保持在列内。

录像对应执行代码`fad38da1555e8af0a55ca1819ef60b2cc87dc834`的干净归档。后续只修正显式手动时钟的持久化测试fixture在装配等待阶段的计时隔离；正常输入与图形测试使用的fixture模式保持实时模拟，游戏执行代码未变。

GitHub Actions保持停用。


## 干净归档全量结果

最终执行代码提交`f1b814ecaa0e8d1792c61fae9fcc899d1734d112`通过`git archive`导出到全新目录，确认起初没有`.godot`后执行：

```sh
python3 tools/run_tests.py --suite all --jobs 3
```

首次恢复模式导入通过，**119/119 checks passed**，runner最终退出码0；[完整日志](playtests/combat-choices/archive-all.log)。持久化fixture仅在明确要求手动驱动时钟的模式下，于场景装配后立即停止自动模拟，防止加载等待消耗待验证的效果余量；实际输入/图形模式不走这条隔离路径。之后只补本文与证据文件，未修改执行代码或测试。
