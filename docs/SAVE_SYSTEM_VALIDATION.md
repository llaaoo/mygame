# 存档扩展验证

2026-11-10，北京时间。实现与接入契约见[SAVE_SYSTEM](SAVE_SYSTEM.md)。

## 提交归档回归

实现提交`7a53d0a76c0b524e1e0294e70b7c5b8926d2d1fe`通过`git archive`导出无`.godot`副本，Godot4.6.3 Recovery模式首次导入退出0，无脚本错误/警告；[导入日志](playtests/save-system/cold-import.log)。然后运行：

```sh
python3 tools/run_tests.py --suite all --jobs 3
```

最终 **129/129通过，退出0**，包括内容引用、启动、持久化、世界状态、生产、NPC、成长、战斗和输入检查；见[完整结果](playtests/save-system/archive-tests.log)。之后只有文档与验证证据变化，没有再次修改运行代码。

新增`save_sections`覆盖：

- 仅显式存储字段参与；继承、可选字段/嵌套默认值、类型化数组和字典保持声明语义；未知字段往返，快照不暴露实时可变容器。
- 独立版本迁移、无迁移时拒绝破坏兼容、依赖排序、依赖环拒绝、后面模块无效时前面模块不被提前恢复。
- 未加载模块及其未知版本在同一槽正常保存后保留，不泄漏到另一个槽。
- 已知未来版本存在于主档或仅备份时，保存与重新开始均拒绝覆盖，原始字节不变；未来嵌套模块不回退到旧备份。
- 当前版本新旅程不误走旧版本迁移；拒绝运行时引用、非有限值以及会超过64MiB读取预算的写入，后者不创建主档或临时文件。

见[字段、模块与文件边界日志](playtests/save-system/value-and-module.log)。

## 真实历史文件与场景重进

`save_sections_game`直接复制仓库中的[历史v9存档](reviews/senior-first-play-2026-11-08/evidence/final-normal-save_3.sav)，不是将当前快照改写版本号。原文件SHA256为`65fce86a0781be7fbc924bd20219b30a3052d09def0fc847a4700be494f8c5ed`，测试不改动该原件。

实际加载后进入客栈，将历史口袋中的实物转入寄存箱，为受控喷剂样本腾出容量；通过InventoryService接收喷剂、消耗1剂并寄存。保存并销毁/重建游戏场景后，所在室内、寄存物品UID与剩余2剂一致，UID分配器不倒退。临时登记的测试模块不再加载后再次保存，其勘察与预算数据仍保留。

随后人为将生产模块修订号提高，调用F9使用的reload_progress入口，验证返回UNSUPPORTED_VERSION、当前人物和库存不被部分恢复、后续保存不改变文件。该段是API集成和故障夹具；实际F5保存键与场景重进另见下面的原生输入验证。见[历史档与模块日志](playtests/save-system/historical-campaign.log)。

## 原生窗口输入

同一提交归档在Xorg原生窗口运行`test_town_cells_input.gd`，1152×648与960×600，Godot退出0。正常模拟与AI继续运行；此脚本使用受控位置与喷剂库存，不当作自然游玩。

通过真实F、F5、M、Esc和鼠标输入验证三处室内、实际寄存/取回、UID与剩余2剂、补给交易、一小时休息、制造与本地地图；F5保存后销毁/重建场景，客栈、箱内实物和地图标记一致。[原生日志](playtests/save-system/native-input.log)、[退出结果](playtests/save-system/native-runner.log)、[已用喷剂实物界面](playtests/save-system/used-spray-storage.png)。

## 正常新档与独立进程

同归档另外运行[镇中步行输入](../tools/playtests/town_cells_journey.json)的76个真实WASD/F/鼠标请求：读手册、领物资、进客栈寄存/取回、睡一小时、卖2份谷粮并买1份烤饼、去作坊制造火石、读公署文书并保存。沿用默认预算、正常AI，无传送/授予库存/属性修改，是已知路线的引导输入，不是盲测。

退出第一个Godot进程，将实际生成的[存档](playtests/save-system/normal-route-save_3.sav)复制为第二个进程的唯一起点。原存档与第二进程种子的SHA256均为`42b4f126fe011cb62348b2e2e06c77320c632114f3607b9387d8856d12857e5a`。

重进比较13组记录：口袋、背包、装备、快捷槽、战利品、NPC账户、关系、成长、追踪目标、武技、固定容器、已到访地区与领取事实，全部一致。

| 实物/事实 | 重新进入后的结果 |
|---|---|
| 寄存箱炭屑 | 5份，UID `item.79` |
| 火石 / 随身炭屑 | 1 / 0 |
| 烤饼 / 净水 / 谷粮 | 2 / 3 / 1 |
| 客栈老板钱币 | 16 |
| 已访室内 | 客栈、作坊、公署 |
| 文书发现 | 公署目录已记；未远程发现档案地牢 |

见[最终比较结果](playtests/save-system/normal-journey-result.log)、[状态摘要](playtests/save-system/normal-route-summary.json)、[76次输入记录](playtests/save-system/normal-route-input.log)、[首进日志](playtests/save-system/normal-route.log)、[第二进程日志](playtests/save-system/normal-reentry.log)、[重进截图](playtests/save-system/normal-reentry.png)。游戏时钟在运行时继续推进，没有要求两个进程截图时间或持续计时效果逐字节相同；对应计时语义由campaign_effects/provision_lifecycle/survival等检查覆盖。

## 平台与边界

环境为Linux、Godot4.6.3、X11/Compatibility、Mesa llvmpipe软件渲染。图形日志只有驱动不支持切换VSync的预期警告，无脚本错误，不作为目标设备性能验收。一次较早的无CPU亲和性限制首次导入进程在字体导入处退出139，未定位引擎内部原因；中止基于不完整导入的测试。最终重新导出干净归档，以`taskset -c 0,1`完成首次导入，再运行上述全量与图形验证，未复用失败缓存。

未知模块只保留不执行；正式provider仍须在读档前登记。业务语义、持久ID替换和结构破坏仍需要局部迁移；恢复回调不得有外部副作用，通用登记表不为任意回调异常提供事务回滚。GitHub Actions工作流仍在disabled-workflows目录，本轮未启用。
