# NPC交互验证

2026-11-10（上海），Godot4.6.3，云端Linux。实现范围见[NPC交互系统](NPC_INTERACTIONS.md)。

`npc_interactions`使用隔离档与受控时钟/位置验证真实领域执行：三位居民使用共同角色与库存；谈话记忆不制造地图发现；接受不扣物；缺料、缺钱、满库失败整体回滚；当面交付守恒且只付一次；库存观察者读到完成收据和关系；熟客实际价格；世界成果一次认可；有效属性及过期重验；夜间服务拒绝；实墙、距离与会话失效；真实保存后销毁/重建场景；非法快照拒绝；攻击造成敌对和信任损失；死亡、遗骸、余量与重进不复活。

`npc_interaction_input`用Godot真实键鼠事件，在正常世界与背景AI下覆盖F交谈、鼠标读话题、接受/交付、进入熟客商店、J筛选已完成人情、小窗口、条件不足与夜间服务拒绝、训练师课程入口、远离自动关闭、不漏攻击、保存后重进。测试设置位置、库存和夜间时钟作为受控条件，不代表自然开荒过程；不以直接发出按钮信号代替操作。

最终提交归档与原生图形结果见下方。GitHub Actions保持停用。

已核对的受控执行样本：

| 情况 | 实际结果 |
|---|---|
| 萨芙的2木炭委托 | 玩家减少2木炭、增加8币，萨芙对应增加2木炭、减少8币；完成后信任10，再交付拒绝 |
| 熟客购买原价16币的短刀 | 价格为15币（九折后向上取整）；出售仍为8币 |
| 艾妲没有报酬或行囊满 | 双方库存、人情状态保持原快照；资金/空间恢复后可正常交2草药、取6币 |
| 智力10＋临时2点 | 能交谈要求智力12的能力话题；增益过期后再次请求拒绝，不能利用旧预览 |
| 修复木桥后的成果话题 | 艾妲信任从10到20；重复回应不再增加；未取得成果时拒绝 |
| 信任10后攻击萨芙 | 态度变敌对，信任变为−20，旧会话与柜台交易均拒绝 |
| NPC死亡、保存、关闭后重进 | 无人物复活，遗骸与实物归属保留，柜台不提供服务也不补钱 |

这些样本验证结算与输入，不代表自然成长速度、真人手感、完整两小时通关或长期经济平衡。

## 最终归档与图形证据

验证代码提交`62f1c6868faf98ac35ab76d1cf9da7fb1ef0223a`。从`git archive`导出到`/tmp/mygame-npc-archive-te7y5_at`，确认初始没有`.godot`，执行：

```sh
python3 tools/run_tests.py --suite all --jobs 3
```

首次导入通过，runner最终**123/123通过、退出码0**，没有匹配的脚本错误、错误或警告。原始隔离日志目录`/tmp/mygame-tests-cdulhs3j`；仓库保留[全量结果](playtests/npc-interactions/all-tests.log)、[领域日志](playtests/npc-interactions/domain.log)与[无界面输入日志](playtests/npc-interactions/input-headless.log)。原有商店、课程与连招输入测试同步改为经人物话题进入训练服务；区域重复加载测试比较初始真实角色数量，仍检查不积累角色和ticker。

随后在**同一归档**运行原生Xorg的`tests/test_npc_interaction_input.gd`，1152×648与960×600窗口、Compatibility / Mesa llvmpipe软件渲染、Dummy音频，Godot退出码0并打印`PASS NPC input`。日志只有“不支持修改V-Sync”的平台警告，没有游戏脚本错误。保留[图形日志](playtests/npc-interactions/input-native.log)、[退出码](playtests/npc-interactions/native-runner.log)与[输入录像](playtests/npc-interactions/conversation-input.mp4)。这不验证音频听感或目标设备性能。

截图：[商人物资话题](playtests/npc-interactions/merchant-topics.png)、[人情交付与信任](playtests/npc-interactions/merchant-favor-completed.png)、[熟客实物商店](playtests/npc-interactions/familiar-shop.png)、[J人情历史](playtests/npc-interactions/favor-journal.png)、[小窗口路线交谈](playtests/npc-interactions/aida-routes-small.png)、[受控夜间服务拒绝](playtests/npc-interactions/off-duty-service.png)。夜间截图只将NPC日程查询设置为23点，世界背景仍为正常白天；它证明服务实时重验，不能当作自然昼夜过渡证据。

后续证据提交仅更新本文与上述文件，不改变验证过的游戏代码。
