# 灰河谷 UI 交互原型 v1.1

[完整方案](../../UI_SYSTEM_DESIGN.md) · [复审与后续修复](../../UI_SYSTEM_REVIEW.md) · [七款成熟作品对标](../../UI_AAA_BENCHMARK.md)。当前已实现 v1.1 的原型优化；**正式 Godot UI 尚未替换**。所有库存、交易和搜取都是刷新重置的示例状态，不连接正式旅程。

从项目根目录启动：

```sh
python3 -m http.server 8768 --bind 127.0.0.1
```

打开 <http://127.0.0.1:8768/docs/design/ui-system/>。顶部十二个视图按钮、角色阶段、火阵条件和敌情按钮属于评审工具，不是游戏内 HUD，也不模拟真实 AI/法阵。

## 可操作内容

- I/O/N 在同一行囊切换全部、穿戴、补给焦点；同入口再次按下返回。页面内 Tab/Shift+Tab 移动焦点，世界 Tab 回上次管理页。
- 物品单击查看、双击使用/穿戴、Shift 或按钮比较；搜索、筛选和选中身份保持。列表可切网格，瓶标和剂量直接可见。
- “绑定快捷槽”在行囊底部展开全部13槽，点目标槽后仍留在原物品。右键可转移、拆分或按数量丢弃；丢弃物可从搜取视图取回。
- 点击 HUD 槽只开小型详情。G 打开当前形式，Q/E/R/1—0 都可作为选材目标；按住中键指向候选后松开可选定。世界滚轮显式切换可用形式，所有选择都不施放、不消费。
- HUD 持续显示当前形式、来源费用和“固定”。“火阵条件”可测试：已选择的火球失去条件后明确失效；开着的候选不会被另一个形式替换。
- K 完整编组，武技不能占快捷槽。P 点击节点预览，再用“学习 · 1点”提交；不会因阅读节点立即花点。
- 买卖：单击浏览，双击/按钮加入清单，确认一次结算。商人资金不足、已穿戴或容量不足会拒绝。卖出的具体瓶保持余量，原绑定失效；买回同件会恢复对应绑定。
- 搜取：按数量取走，满包演示会把样例重量容量设为当前负重；失败留在原处。恢复容量后可取走或取部分材料。此处没有专业剥取模拟。
- 制造样例按实际示例原料与容量结算；缺料不消费。地图可选地点、缩放、拖动。
- 确认框独占输入并限制焦点。正常 Esc 逐层关闭；演示危险存在时 Esc 一次取消全部未提交的界面准备并返回世界。没有实际 AI、防御或自动闪避。
- 系统支持100/112/125%文字、增强对比与减少动态。示例时钟在菜单中持续推进。

[当前验证](verification.json) · [历史 v1 冒烟结果](verification-v1.json) · [历史复审缺口](review/audit.json)

[行囊原位绑定](screenshots/inventory-binding.png) · [当前形式](screenshots/current-form.png) · [买卖](screenshots/trade.png) · [搜取](screenshots/loot.png) · [小窗口大字](screenshots/inventory-small-large-text.png)

## 验证

需要现有 Python Playwright 和 `/usr/bin/chromium`，不自动下载依赖：

```sh
python3 docs/design/ui-system/verify_prototype.py --url http://127.0.0.1:8768/docs/design/ui-system/ --out /tmp/grayriver-ui-check
```

使用真实键鼠事件，检查从选择到结果、拒绝与取消，以及960×720、1440×900、1920×1080在100/125%文字下的命中区、固定主动作和全部编组槽。当前检查不是正式游戏试玩、Godot 回归、AI/物理/存档/平衡或性能验收。历史 `review/audit.py` 是 v1 特征记录工具；新的验收入口以本节为准，不能在新版直接用旧 DOM 假设重写历史数据。

仍为概念入口：真实课程付款、完整知识获取、九分支40节点、休息、存读档、改键、阵亡和智能元素跟随。当前所有形式为显式固定选择，原型没有真实战斗或成功施法事件。涂层秒数、Buff、目标血量为静态样例；没有UI提示音实现。

## 素材与权利

- `world.png`：原 v1 的隔离场景受控截图，未更改正式场景或存档，不是自然通关证据。沿用 [项目素材台账](../../../content/art/THIRD_PARTY_ASSETS.md)，散列保留在 [provenance.json](provenance.json)。
- 穿戴预览引用已有 `content/art/third_party/puny/Character-Base.png` 的无武器格，原图不变，CSS整数倍采样；来源 Shade / Puny Characters / CC0，原许可与散列见 [素材记录](../../../content/art/third_party/puny/animation_assets.json)。装备图层是读取样例穿戴的代码示意，并非正式角色 rig 接入。
- 物品和地图仍为原创代码示意。对象图标使用实体填色与瓶标帮助辨识，导航保留线框；不宣称已完成最终物品美术。
- 字体引用项目 Noto Sans SC，保留原 OFL 许可。本轮无新第三方下载、Figma 文件或运行时网络依赖。
- `.gdignore` 隔离整个设计目录，原型不是 Godot 导入或运行时依赖。
