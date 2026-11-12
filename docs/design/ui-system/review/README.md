# v1 原型复审证据

[评审结论与 v1.1 修订](../../../UI_SYSTEM_REVIEW.md)。这里只复现旧概念原型的设计缺口，不是正式 Godot 试玩。

从项目根目录启动原型后执行（需要现有 Python Playwright 与 `/usr/bin/chromium`）：

```sh
python3 -m http.server 8767 --bind 127.0.0.1
python3 docs/design/ui-system/review/audit.py --url http://127.0.0.1:8767/docs/design/ui-system/ --out /tmp/grayriver-ui-review
```

`audit.py` 是特征审查记录器：读取真实键鼠操作后的页面状态，将每项是否满足预期写入 JSON。**脚本完成并不意味着所有要求通过**。本次基线为 `2303650`（PR #57 的设计提交）；14 项观察中 10 项未满足，4 项满足，JavaScript 运行异常为 0。后续原型改动可能改变结果，应保留本次记录作为历史证据。

- [audit.json](audit.json)：状态、尺寸、命中区和特定色对比测量。
- [selected-form.png](selected-form.png)：已选过火石阵，重新打开后缺少当前项反馈。
- [skills-small-large-text.png](skills-small-large-text.png)：960×720、125% 文字下，最后一排槽位位于首屏可见范围之外，需要滚动。

截图沿用原型自己的已有素材与受控世界底图，来源见 [原始台账](../provenance.json)。色彩对比为指定十六进制色对的计算，不代表全部动态背景像素；按钮尺寸按 DOM 命中框，不能代替 Godot 控件或目标设备测量。没有运行实际游戏 AI、事务、存读档或性能基准。
