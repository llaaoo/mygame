# 动画基座验证记录

2026-11-09，云端Linux / Godot 4.6.3。实现、调研与可运行场景见[动画基座](ACTOR_ANIMATION_SYSTEM.md)。

## 场景和边界

- `actor_animation`用受控物理时钟、目标和位置验证实际动作相位、原生播放器、成本/位置/库存不变、事实提示不随渲染掉帧丢失、脚步接触点、资源校验和死亡战利品保存重进。它不代表自然战斗或性能验收。
- `animation_demo_input`通过实际Godot鼠标/键盘事件，从游戏内入口保存正式旅程并进入素材页，操作方向、动作、阶段、暂停/时间轴，在1152×648和960×540查看；然后进入武器和施法沙盒，测试连招/长按转向/武技/换装、纸娃娃、正常AI对练、真实火石与火球、内存F5/F9及正式旅程UID/余量保留。配装、知识和安全起点为演示预设。
- 原生窗口通过Xorg + Godot Compatibility运行；真实输入集成与截图取自同一个脚本，录像用于检查画面和操作过程。驱动不支持切换VSync，不把录像当成目标设备帧率或真人手感结论。
- 受击、死亡与遗骸走原CombatExecutor/库存与存档链；头像预览独立实例只读同一身体资源和真实装备。参考图自带武器，限制在明确标记的素材预览中。

## 最终交付验证

最终验证提交：`e806a58`。`git archive`导出到`/tmp/mygame-animation-reviewed-archive-92b9opip`，起始不含`.godot`，由统一runner完成首次导入。后续证据提交只增加文档与截图，不改变被测代码。

第一轮完整回归在`controls_workflow`发现新增演示条目改变设置默认项：名称排序将“动画”排到“施法”之前，首次进入不再显示改键。已修复为无有效历史选择时明确默认“施法与快捷操作”；已有选择与搜索仍保留。修复后针对`controls_workflow / animation_demo_input`的真实输入检查2/2通过（`/tmp/mygame-tests-4skgn_d5`）；旧全量运行已停止，以新提交重新归档运行全量。

另修正旧响应检查的计时起点：短按/长按从松键决定动作，测试仍保留两物理帧响应要求，但从真实release事件起算，不将输入辅助函数自身等待的按住时长算成响应延迟。修后`weapon_response_input`通过（`/tmp/mygame-tests-x2u68d23`）。连招间隔、成本与防额外出招检查不变。

`e78caaf`归档全量最终114/115，唯一失败为旧火地面测试固定等待1.1秒：地表0.5秒采样后燃烧还需自己的一秒周期，时序可能超过该等待。`e806a58`改为有界观察真实扣血，不插入地表、不直接推进状态，也不放宽伤害、推入火地面或耗材断言；单项通过（`/tmp/mygame-tests-2f5q2jve`），再从最终提交重跑全量。

最终原生窗口在`88cb9f6`归档复测，后续提交仅改上述测试仪表，游戏代码相同。`/tmp/grayriver-first30/actor-animation-reviewed/runtime.log`记录Godot退出0、`PASS animation demo input`及实际提交`DEMO_CASTS ["inscribe","fireball"]`。原生驱动仅有不支持设置VSync的警告，无脚本错误。

源录像位于该目录`weapon-response.mp4`；下列证据为最终原生窗口输入脚本产生。动图截取约21.7—25.8秒，裁剪放大角色区域、15fps、48色，仅便于观察动作，不作帧率测量。

| 证据 | 查看 |
|---|---|
| 八方向原生素材浏览、暂停/时间轴 | [素材页](playtests/actor-animation/gallery.png) |
| 实际按住蓄力姿态与武器 | [蓄力](playtests/actor-animation/combat-charge.png) |
| 轻击、转向、重击、武技过程 | [战斗动图](playtests/actor-animation/combat.gif) |
| 原生身体与真实装备纸娃娃 | [穿戴](playtests/actor-animation/paper-doll.png) |
| 实际火石阵与已提交火球组合 | [施法](playtests/actor-animation/cast-release.png) |

最终完整回归：在上述干净归档执行`python3 tools/run_tests.py --suite all --jobs 3`，runner正常退出0，最终`115/115 checks passed`，日志与隔离存档位于`/tmp/mygame-tests-f2wynxoa`。首次`--editor --import --recovery-mode`通过；全部检查没有runner识别的SCRIPT ERROR、ERROR或WARNING。该结果覆盖最终游戏代码及修正后的真实输入测试，不使用旧失败运行的局部进度拼接。

离线运行`python3 tools/build_actor_animation_assets.py`重建后，`content/animations`无差异；素材清单的字节数与SHA-256由动画检查核对。相关本地文档链接与`git diff --check`通过。截图/动图与文档证据提交不改变上述被测游戏和测试代码。
