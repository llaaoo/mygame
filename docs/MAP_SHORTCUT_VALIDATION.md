# M地图与G选材验证

2026-11-10（上海）。M开关地图，G开关点击式选材，按住中键选材保留。背包/技法导航、轮盘关闭键、HUD、手册、技能描述和当前操作指南同步更新；历史试玩证据保留原键位。不改变快捷槽、技能自定义或存档布局，两键继续是保留菜单键。

提交`b8b673fba81c7fde5f7d617fc89e0bed45ff36c0`导出无`.godot`归档，首次导入通过；针对性回归`input_bindings visual_interface interface_navigation flow_input realtime_interaction town_cells_input grayriver_journey content`最终 **8/8通过，退出0**，见[归档日志](playtests/map-shortcut/archive-tests.log)。本轮是菜单键位与提示调整，未再次运行全量玩法套件。

真实键鼠检查M开关地图、从背包/技法/轮盘进入地图、G开关轮盘、中键选材、搜索框输入M不导航、M/G拒绝被技能改绑、独立快捷槽、自定义按键/读档、室内地图和正常模拟。另在同归档Xorg原生图形窗口运行`visual_interface`，默认新档、正常AI/属性、实际步行读手册及小窗口通过，Godot退出0，见[原生日志](playtests/map-shortcut/native-input.log)、[启动结果](playtests/map-shortcut/native-runner.log)、[M地图](playtests/map-shortcut/m-map.png)和[G选材](playtests/map-shortcut/g-selector.png)。

环境为Godot4.6.3、Linux X11/Compatibility、Mesa软件渲染；驱动不支持切换VSync，未出现脚本错误。本轮不作为目标设备性能验收。GitHub Actions保持停用。
