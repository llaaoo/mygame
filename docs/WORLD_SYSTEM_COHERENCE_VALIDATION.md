# 世界系统衔接验证

2026-11-10（上海），Godot4.6.3，云端Linux。系统规则见[世界系统衔接](WORLD_SYSTEM_COHERENCE.md)。

`world_coherence`覆盖独立商人库存/货币、独立训练师课程与学费、真实保存后重新挂载、有效体力投影、人物地点引用与日志、未知前置/地点/服务配置拒绝、人情与正式任务共用追踪、已知采集点、交付后目标消失、镇民撤退与训练师防卫，以及生产者在首批库存通知中死亡后的全部订单取消、旧死者订单恢复、休息和重进守恒。额外商人/训练师为隔离的内容装配夹具，没有修改共享定义、扩充正式地图或发放正式奖励。

`coherence_input`使用真实P/F/J和鼠标输入，验证缺水/疲劳回复显示、经验变化不销毁按钮或丢焦点、实际耐力加点、独立人物的交易与课程、人情追踪/交付、小窗口、实际保存并重进。经验、需求、知识、物资与位置明确为受控条件，背景AI和世界模拟正常。帧样本包含云端调度及软件渲染成本，不用于声称目标设备性能。

## 提交归档与原生界面

玩法提交为`f021f5455f1b97eefae8e9963aac412875b5eb44`。从该提交导出`git archive`，确认没有`.godot`后执行`python3 tools/run_tests.py --suite all --jobs 3`，首次导入及最终退出码均为0，**125/125通过**。完整结果见[归档回归](playtests/world-coherence/archive-all.log)，关键边界见[领域验证日志](playtests/world-coherence/domain-coherence.log)。

同一归档在Xorg原生窗口运行`test_coherence_input.gd`，Godot退出码0，真实P/F/J与鼠标操作、独立服务账户、交付和保存重进全部通过，见[运行日志](playtests/world-coherence/native-input.log)和[启动结果](playtests/world-coherence/native-runner.log)。需求与经验等为前述受控夹具；没有将夹具当成默认新档验收。

[原生输入录像](playtests/world-coherence/native-input.mp4)与截图对应同一次运行。

- [有效体力与稳定控件](playtests/world-coherence/effective-stamina-stable-controls.png)：缺水/疲劳下加耐力后显示当前1.8/秒、基础10.2/秒；经验变动未销毁按钮或丢失焦点。
- [独立商人](playtests/world-coherence/independent-merchant.png)、[独立课程](playtests/world-coherence/independent-training.png)：额外人物使用本人实物和货币，没有改动原商人和训练师账户。
- [人物引用线索](playtests/world-coherence/typed-route-leads.png)、[960×600目标追踪](playtests/world-coherence/personal-objective-small.png)、[实际交付](playtests/world-coherence/personal-delivery.png)：列表、滚动详情及追踪按钮可操作。

平台为云端Linux、Godot4.6.3、X11/Compatibility和Mesa软件渲染。原生输入样本451帧，帧间隔中位数69.43ms、P95为128.69ms、最大150ms，最高2112节点、进程时间峰值623.87ms。此样本包含云端调度、软件渲染和录屏，不能据此证明目标设备性能或两小时运行稳定性。驱动报告不支持切换VSync；未出现脚本错误。没有为得到截图关闭AI或暂停世界。

GitHub Actions保持停用。

## 默认预算路线的修订记录

默认新档路线复用了历史首玩坐标，首次在旧猎营笔记外未能交互；西侧第二个点仍超过80单位交互范围。最终使用笔记西侧50单位的点，读完再向原战斗准备位置移动。另一次在J保留的“知识”页找不到追踪按钮，路线补充了点击“委托记录”的真实导航操作。上述尝试均未计为完成验收；修订只涉及测试路线，没有扩大交互距离、授予物资、移动笔记或改变战斗。玩法回归对应前述归档提交；最终路线文件和证据作为独立的工具/验证补充提交。

## 默认新档闭环结果

最终74步[输入路线](../tools/playtests/world_coherence_journey.json)在同一玩法归档、独立新档、正常AI与模拟下全部完成；随后启动第二个Godot进程，载入该局实际生成的存档，两个进程均退出0。没有授予额外物资/经验，也没有传送。路径由已知地图引导、战斗输入由探针循环提出，属于可重放集成验证，不是盲玩或两小时内容验收。

沿提示阅读手册、领取口粮、工作台制火石，从笔记西侧50单位处按F安全阅读后再前移选阵。最终一次守林兵战斗用时4.567秒（墙钟4.699秒）、受伤0、消耗火石1，铭刻后打出两发火球，结束时30 MP。此前路线修订运行的4.523秒/29 MP是另一局的记录；最终数据以[战斗原始快照](playtests/world-coherence/duel_combo.json)为准。[安全阅读](playtests/world-coherence/07-safe-preparation-final.png)及[火球成果](playtests/world-coherence/09-fireball-result-final.png)与该局一致。本轮未新增同存档基础打法对照，不能将此路线声称为平衡比较。

返镇后实际穿戴守林兵的驿路短刀。商人委托交付炭屑2取得8币，支付8币学习“破势斩”，训练师再以收到的学费支付口粮委托3币：

|账户|初始货币|最终货币|本轮实际变动|
|---|---:|---:|---|
|玩家|0|3|+8委托−8课程+3委托|
|商人萨芙|160|152|支付8；实收炭屑2|
|训练师|0|5|课程收入8−委托支付3；实收口粮1|
|艾妲|24|24|未参与交易|

最终等级2、经验30、属性点3；两个人情完成，“破势斩”已学。玩家余量包括炭屑3、晶砂8、树液9、口粮2、清水4，火石耗尽；口粮包含原实物战利品，不能仅用初始口粮减交付推算。见[独立账户与整局摘要](playtests/world-coherence/coherence-summary.json)、[人情目标追踪](playtests/world-coherence/journey-personal-tracker.png)、[商人支付](playtests/world-coherence/journey-funded-supply.png)、[学费支持的口粮交付](playtests/world-coherence/journey-course-funded-favor.png)。

重进逐项精确比较口袋、背包、装备、快捷槽、遗骸记录、NPC账户、交谈与人情、等级成长、追踪ID和武技配置，并比较世界事实集合，全部相同。见[比较结果](playtests/world-coherence/journey-reentry-comparison.log)、[重进画面](playtests/world-coherence/journey-reloaded.png)、[完整输入日志](playtests/world-coherence/journey-runtime.log)和[第二进程日志](playtests/world-coherence/reentry-runtime.log)。
