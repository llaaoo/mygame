# 灰河谷 UI 交互原型 v1.2

[完整方案](../../UI_SYSTEM_DESIGN.md) · [复审与后续修复](../../UI_SYSTEM_REVIEW.md) · [七款成熟作品对标](../../UI_AAA_BENCHMARK.md)。当前已实现 v1.2 的决策支持优化；**Godot核心路径已接入并按原型重排视觉，扩展功能仍待迁移**（[正式实现及证据](../../UI_GODOT_IMPLEMENTATION.md)）。所有库存、交易和搜取都是刷新重置的示例状态，不连接正式旅程。

## 直接查看与下载（无需云环境）

- [下载离线原型 ZIP](https://github.com/llaaoo/mygame/raw/refs/heads/main/docs/design/ui-system/downloads/grayriver-ui-v1.2.zip)：约13 MB，解压后双击 `grayriver-ui.html`，用桌面 Chrome / Edge / Firefox 打开。全部字体、图片、脚本内嵌，不需要 Python、Godot 或本地服务。所有状态仍为刷新重置的原型样例。
- [在 GitHub 浏览说明与截图](https://github.com/llaaoo/mygame/blob/main/docs/design/ui-system/README.md)：无需运行页面。ZIP 若未直接下载，可进入[文件页](https://github.com/llaaoo/mygame/blob/main/docs/design/ui-system/downloads/grayriver-ui-v1.2.zip)，点击 **Download raw**。
- `127.0.0.1` / `localhost` 地址仅供开发环境内部验证，不能当成外部分享链接。本会话当前没有对外端口预览工具；没有因此启用 Pages、公开部署或 Actions。

离线包由 `python3 tools/export_ui_prototype.py` 从现有原型确定性生成，不改正式玩法。包内保留素材出处与字体/图集许可。打包文件重新通过141+93项交互回归；另经断网后的7项流程检查，只有首次HTML请求，后续没有网络请求。[交付验证](downloads/offline-verification.json)记录包与HTML散列。

平台边界：云端受管 Chromium 以 `ERR_BLOCKED_BY_ADMINISTRATOR` 禁止 `file://`。因此本轮通过HTTP只提供这一个HTML，再断网验证交互与内嵌素材；没有声称完成用户本地浏览器或设备验收。

## 开发环境运行

从项目根目录启动：

```sh
python3 -m http.server 8769 --bind 127.0.0.1
```

打开 <http://127.0.0.1:8769/docs/design/ui-system/>。顶部十三个视图按钮、角色阶段、百项/复合状态夹具、火阵条件和敌情按钮属于评审工具，不是游戏内 HUD，也不模拟真实 AI/法阵。

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

[基础流程141项](verification.json) · [新增决策流程93项](decision-verification.json) · [证据散列](evidence.json) · [历史 v1.1 结果](verification-v1.1.json) · [历史 v1 冒烟结果](verification-v1.json) · [历史复审缺口](review/audit.json)

[行囊原位绑定](screenshots/inventory-binding.png) · [当前形式](screenshots/current-form.png) · [买卖](screenshots/trade.png) · [搜取](screenshots/loot.png) · [小窗口大字](screenshots/inventory-small-large-text.png)

## v1.2 决策与整理

- 配装：选择“行路轻刃”并比较，查看伤害下降、体力费用和重量下降的不同收益方向；选择弓查看弹药与刀剑武技条件变化。解释入口可用鼠标/键盘打开，返回保留物品和搜索，不实际换装。
- 准备：从行囊或制造固定最多3个目标，调整1–9份。共享材料汇总；身上数量、缺项和远处已知寄存分开。成功加工才计入完成，丢弃/取回/交易会更新实际缺项。清单不锁物、不补料、不重绑槽。
- 整理：物品可按UID收藏/标待售；按类别、最近获得、名字、总重或参考总值排序。多选默认略过已穿戴、收藏、快捷来源、任务物和准备材料；批量只标记意图。到买卖载入待售后仍需检查报价、确认结算；资金不足整批拒绝。手动卖收藏品会显示保护原因并要求显式加入，卖出后清除待售意图，买回保持原UID和收藏。
- 情境HUD：系统页选标准/探索/战斗；探索收起通用帮助，13槽位置、资源与当前来源保持稳定。演示敌情可强制危险反馈。菜单文字与HUD缩放分别设置。
- 复合状态：顶部按钮打开静态归属样例，区分异常积累、已生效状态、武器涂层和地面阵能；不宣称模拟战斗计时。失败提示优先于普通提示，系统页“近期消息”只读重看，不重放动作；声音可选且文字始终保留。
- 地图：区分亲历与听闻，传闻只给范围和来源，不能生成精确路标。查看记录返回不丢当前地图线索。
- 百项夹具：顶部切入100件实物样例，**明确把示例容量改成500/120格**；同名喷剂有独立瓶标和1–3剂余量，装备有独立强化。再点重置，刷新不保存。

[配装比较](screenshots/comparison.png) · [准备缺项](screenshots/preparation.png) · [批量整理](screenshots/batch.png) · [百项行囊](screenshots/stress-bottles.png) · [状态归属](screenshots/status-language.png) · [地图线索](screenshots/map-clue.png)

## 验证

需要现有 Python Playwright 和 `/usr/bin/chromium`，不自动下载依赖：

```sh
python3 docs/design/ui-system/verify_prototype.py --url http://127.0.0.1:8769/docs/design/ui-system/ --out /tmp/grayriver-ui-check
python3 docs/design/ui-system/verify_decision_support.py --url http://127.0.0.1:8769/docs/design/ui-system/ --out /tmp/grayriver-ui-decisions
```

使用真实键鼠事件，检查从选择到结果、拒绝与取消，以及960×720、1440×900、1920×1080在100/125%文字下的命中区、固定主动作和全部编组槽。本轮两组共234项通过；没有浏览器异常或缺失资源。新增组覆盖大字下的比较+批量按钮命中和三目标可编辑性；不是目标设备帧率或真实玩家效率研究。当前检查不是正式游戏试玩、Godot 回归、AI/物理/存档/平衡或性能验收。历史 `review/audit.py` 是 v1 特征记录工具；新的验收入口以本节为准，不能在新版直接用旧 DOM 假设重写历史数据。

仍为概念入口：真实课程付款、完整知识获取、九分支40节点、休息、存读档、改键、阵亡和智能元素跟随。当前所有形式为显式固定选择，原型没有真实战斗或成功施法事件。涂层秒数、Buff、目标血量为静态样例；提示音为默认关闭的原创合成音，设置页可试听；浏览器已覆盖音频路径与文字反馈，没有目标设备听感验收。

## 素材与权利

- `world.png`：原 v1 的隔离场景受控截图，未更改正式场景或存档，不是自然通关证据。沿用 [项目素材台账](../../../content/art/THIRD_PARTY_ASSETS.md)，散列保留在 [provenance.json](provenance.json)。
- 穿戴预览引用已有 `content/art/third_party/puny/Character-Base.png` 的无武器格，原图不变，CSS整数倍采样；来源 Shade / Puny Characters / CC0，原许可与散列见 [素材记录](../../../content/art/third_party/puny/animation_assets.json)。装备图层是读取样例穿戴的代码示意，并非正式角色 rig 接入。
- `decision-support.js`中的 typed 样例、图形及 WebAudio 提示音为原创代码；没有外部音频素材。它只支持原型评审，迁入 Godot 时复用领域查询，不复制一套数值规则。
- 物品和地图仍为原创代码示意。对象图标使用实体填色与瓶标帮助辨识，导航保留线框；不宣称已完成最终物品美术。
- 字体引用项目 Noto Sans SC，保留原 OFL 许可。本轮无新第三方下载、Figma 文件或运行时网络依赖。
- `.gdignore` 隔离整个设计目录，原型不是 Godot 导入或运行时依赖。
