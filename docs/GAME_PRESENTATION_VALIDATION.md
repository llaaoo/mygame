# 整体游戏表现验证

2026-11-09，云端Linux、Godot 4.6.3 Compatibility。设计和接入入口见[整体表现基座](GAME_PRESENTATION_SYSTEM.md)。

## 覆盖与边界

- `presentation_system`为受控契约检查：原生资源与预制体安全、声音散列、数量上限/优先级/去重/剔除、对实际库存/生命/法力/根位置不写入、玩法独立随机流、真实无伤害命中声音与受伤镜头、减少动态效果和离区清理。
- `presentation_input`用实际Godot键鼠事件，从正式旅程设置页进入独立内存演示，在正常模拟和AI下做日夜视觉对照、真实F/鼠标采集、消耗2树液1炭屑的机关作业、枯竭/完成姿态、F5/F9与正式旅程装备/物资隔离，检查960×600设置页。设施位置、物资与撑木知识为明确演示条件，不代表自然开荒或正常旅程通关。
- 原生窗口使用Xorg/llvmpipe，视频仅记录画面，Godot音频驱动为Dummy。声音检查证明实际AudioStream/原生播放路径和音量接通，**不代表真人听感、扬声器混音或目标设备性能验收**。
- 环境“夜景对照”为纯视觉，不改变真实时间；正式游戏读取实际WorldTime。危险范围、投射物、交互与作业计时不会因减少动态效果、菜单或装饰剔除停止。

## 最终证据

基础实现`d5d9af8`的无缓存归档已完整运行117/117，runner退出0（`/tmp/mygame-tests-p7wr0x44`）。原生窗口进一步逐帧审查发现以前纳入的第15列仍绘有法杖，已用`abad0c3`剔除并收紧白名单；针对角色动画和整体输入的2/2复测通过（`/tmp/mygame-tests-a6u4o2rz`）。原始CC0 PNG未改动，正式帧选择改为16/17/0/1，八方向均已放大核对。

最终代码提交为`abad0c3`，无`.godot`的`git archive`导出到`/tmp/mygame-presentation-final-archive-nycwbh12`。在该最终归档运行`python3 tools/run_tests.py --suite all --jobs 3`，首次导入通过，runner最终退出0，**117/117 checks passed**；日志和隔离存档位于`/tmp/mygame-tests-l1vk0vdg`，无runner识别的脚本错误、错误或警告。该结果来自同一次最终运行，不拼接旧运行的局部结果。后续证据提交仅涉及文档与图像，不改变被测游戏/测试代码。

最终原生窗口也使用上述归档：`/tmp/grayriver-first30/game-presentation-reviewed/runtime.log`记录Godot退出0与`PASS presentation input`；无脚本错误，只有驱动不支持设置VSync的警告。视频源为同目录`weapon-response.mp4`（沿用录制工具文件名）。它是Xorg/llvmpipe画面与实际输入事件证据，不是目标设备性能测量或音频听感验收。

| 证据 | 实际查看内容 |
|---|---|
| [日景](playtests/game-presentation/day.png) / [夜景](playtests/game-presentation/night.png) | 相同展示区的光色、营火局部暖光、可交互实体；对照不改WorldTime |
| [实际作业动图](playtests/game-presentation/world-work.gif) | 亲手开始的材料作业，角色姿态读取真实进度，原生状态反馈与作业条共同推进 |
| [作业画面](playtests/game-presentation/mechanism-work.png) | 真正机关与装备、现场作业保持站定和取消提示 |
| [采后枯竭](playtests/game-presentation/harvest-depleted.png) | 采集成功后读取实际再生状态，不重复生成奖励 |
| [960×600设置](playtests/game-presentation/settings-small.png) | 减少动态效果、镜头开关、密度和两个音量；世界仍模拟 |
| [身体帧审查](playtests/game-presentation/body-frame-review.png) | 原始CC0图的八方向，按16/17/0/1列裁切放大，仅供审查，PNG源图未修改 |

动图从最终视频约63.0—67.2秒裁切角色/机关/作业区域，12fps、64色。截图同一裸地矩形的平均灰度为日景86.04、夜景60.32，确认环境光真正影响旧地形材质；这不是物理照度或性能指标。两个离线构建器重建后资源无差异，本地文档链接和`git diff --check`通过。
