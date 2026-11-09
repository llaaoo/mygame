# RPG成长系统验证

2026-11-10（上海），Godot 4.6.3，云端Linux。系统范围与公式见[RPG成长系统](RPG_PROGRESSION_SYSTEM.md)。

`rpg_progression`验证唯一角色等级与预算、基础/有效属性体力投影、临时属性不能借点、前置拒绝、格挡延迟、手动反击、闪避费用、敏捷远射、实际制造/强化/拆解/采集、资源点耗尽、满包部分产出回滚、Perk变化取消旧施法、真实材料与耗魔、食物限定回复与过期、无奖励试战、旧点数一次迁移、非法快照和保存后重建场景。

`rpg_progression_input`使用Godot真实键鼠事件：P打开实时成长页、点击耐力提高体力、鼠标学习与条件不足拒绝、F5/F9、按基础属性/实践要求点出制造Perk、小窗口树/详情滚动、真实工作台制作7支箭并支付1份碎料、退出后重进核对节点/点数/属性/实物。库存、经验、实践和配方知识为受控条件，世界与背景AI正常；不使用按钮信号代替点击。

## 已核对的实际结果

| 操作 | 结果 |
|---|---|
| 10耐力、当前60体力，分配1点耐力 | 上限100→102，当前仍60；临时+4耐力后上限110，过期回102 |
| 真实经验奖励100，角色1→2级 | 获得3属性点、1通用Perk点；学习战斗调息后上限117、Perk点0；重复/越前置学习拒绝 |
| 精准防御后手动攻击 | 反击研习使原本1.25倍反击变为1.5倍；不自动攻击 |
| 学习箭簇整备后制作箭 | 6→7支，仍消耗1木炭和1金属碎料；满包仅能部分接收时，库存和实践整体回滚 |
| 学习整修熟手和拆解辨材 | 同一真实UID强化费用5→3币，仍付2碎料；随后拆解产出4碎料，该UID消失 |
| 学习识草并完成真实资源点作业 | 基础产物额外+1，资源点进入耗尽/再生；立即重采拒绝 |
| 学习原毁灭节点后实际布火石阵 | 付7MP和1火石，只生成1座法阵；学习中途改变Perk的旧准备取消且不消费 |
| 吃真实口粮并拥有补给回气 | 食物有效时额外回气+2/秒，250秒后食品效果过期，额外回气消失；吃饭不发实践经验 |
| 保存、销毁场景、重新进入 | 节点、点数、属性、制造实物与已拆装备状态保持；旧点数迁移重复恢复不增发 |

以上为自动化受控条件下的真实领域执行结果，不能当作自然开荒的成长速度样本。

## 图形平台与覆盖边界

原生Xorg图形以1152×648和960×600窗口、Compatibility软件渲染（Mesa llvmpipe）与Dummy音频运行。平台提示不支持修改V-Sync；这不是游戏脚本错误。覆盖上述键鼠输入流程，截图、录像和最终归档全量结果在下方记录。不据此宣称自然两小时开荒、真人手感、长期数值平衡、音频听感或目标机器性能。GitHub Actions保持停用。

## 最终提交归档复测

验证代码提交：`44e5a7a7be1a585ccc7aa458e52f81ff5383c2ab`。由`git archive`导出到`/tmp/mygame-rpg-archive-0pqh9rh2`，确认初始没有`.godot`，运行：

```sh
python3 tools/run_tests.py --suite all --jobs 3
```

runner退出码0，首次导入通过，**121/121检查通过**，无runner匹配的脚本错误、错误或警告。原始隔离日志目录`/tmp/mygame-tests-8oe3nhw_`；仓库保留[全量摘要](playtests/rpg-progression/all-tests.log)、[成长领域日志](playtests/rpg-progression/domain.log)与[无界面真实输入日志](playtests/rpg-progression/input-headless.log)。

随后在**同一归档**运行原生Xorg版本的`tests/test_rpg_progression_input.gd`，Godot退出码0并打印`PASS RPG input`。保留[图形运行日志](playtests/rpg-progression/input-native.log)、[进程退出结果](playtests/rpg-progression/native-runner.log)与[输入录像](playtests/rpg-progression/progression-input.mp4)。图形日志仅含上述V-Sync平台警告，没有游戏脚本错误。

截图：[耐力与体力预览](playtests/rpg-progression/stamina-investment.png)、[武器树与条件](playtests/rpg-progression/weapon-tree-requirements.png)、[制造分支](playtests/rpg-progression/craft-tree.png)、[小窗口野外分支](playtests/rpg-progression/survival-tree-small.png)、[工作台实际产出预览](playtests/rpg-progression/ammo-output-preview.png)。后续证据提交仅增加本文与上述文件，不改变已验证的游戏代码。
