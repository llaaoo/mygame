# 灰河谷 UI 设计原型

[完整方案](../../UI_SYSTEM_DESIGN.md)。这是本轮设计评审产物，正式 Godot UI 尚未替换。**原型仍为 v1**；v1.1 方案的复审发现与待修事项见 [设计复审](../../UI_SYSTEM_REVIEW.md)，旧 67 项检查不代表这些缺口已经覆盖。

从项目根目录启动：

```sh
python3 -m http.server 8766 --bind 127.0.0.1
```

打开 <http://127.0.0.1:8766/docs/design/ui-system/>。顶部十个按钮是评审工具，不属于游戏内 HUD。右侧可切换未觉醒/觉醒状态及演示敌情。刷新恢复样例状态。

- I/O/N 行囊，K 技艺，P 成长，J 手札，M 地图，G 当前槽形式，Esc 逐层返回。
- 行囊单击查看、双击使用/换装、右键操作、Shift 比较；详情可将实物绑定到独立快捷槽。
- G 打开后按 Q/E/R 切换候选槽；选形式不消费、不施放。地图滚轮缩放，中/右键拖动。
- 系统页可试字号、对比和减少动态。样例时钟在菜单中仍走动；“演示敌情”展示受伤与立即返回提示。

[检查结果](verification.json) · [探索截图](screenshots/hud.png) · [行囊截图](screenshots/inventory.png) · [技艺截图](screenshots/skills.png)

浏览器验证（需要 Python Playwright 和系统 Chromium，不下载新依赖）：

```sh
python3 docs/design/ui-system/verify_prototype.py --url http://127.0.0.1:8766/docs/design/ui-system/ --out /tmp/grayriver-ui-check
```

验证是 HTML 设计原型测试，不是正式游戏试玩、Godot 回归、平衡或性能结论。具体可操作与概念入口的边界见完整方案末节。

## 素材与权利

- `world.png`：本项目灰河谷场景在隔离内存会话中的受控构图截图；隐藏原 HUD，未更改正式场景或存档。不是自然通关证据。底图内已有素材许可沿用项目 [素材台账](../../../content/art/THIRD_PARTY_ASSETS.md)。
- 图标、人体轮廓、地图：本轮代码绘制的原创 SVG 示意，无外部图像下载。正式纸娃娃应使用实际装备外观系统。
- 字体：引用项目 `content/art/fonts/NotoSansSC.ttf`，原许可保留在该目录，不嵌入新字体。
- 本轮未获取新第三方素材，未连接 Figma 文件，未生成或宣称制作新的游戏美术资产。
- `.gdignore` 使该设计目录不进入 Godot 资源导入；浏览器原型不成为运行时依赖。
