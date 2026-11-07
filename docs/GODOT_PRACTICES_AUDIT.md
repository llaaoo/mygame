# Godot 4.6 架构与代码审查

基线为 `c5f24fa`，项目指定 Godot 4.6.3。盘点覆盖三个游戏入口、角色和物品、战斗与区域运行时、世界物体、界面、存档以及导入和测试配置。基线有 338 个第一方游戏脚本，另有测试与工具脚本。本次排除了插件代码，保留项目已有的玩法和持久化契约。

| 检查面 | 当前证据 | 本轮处理及后续核查 |
| --- | --- | --- |
| 场景组合和所有权 | 灰河谷已由战役入口装配，角色共用组件场景。旧 HUD 和条件施法依赖全局场景或固定祖先。 | 三个入口为 HUD 指定 Player，旧入口同时指定 RunManager。SkillManager 显式装配施法组件，预检使用本次计划的施法者。旧入口在场景中指定玩家、初始地图和运行时，房间与地图使用同一个活动根。 |
| 运行时生命周期 | RegionSession 已有离区协议。NPC、地图物件及运行时订阅有重复延迟或逐帧重试，伤害数字留在场景根。 | 使用既有注册机制和一次性就绪信号，命令总线由组合根传入。伤害数字跟随目标所在区域释放，退出时取消订阅。旧传送先验证新地图与出生点，再卸载旧根；地图锚点改为在所属地图内查找。等待注册的节点退出时会清理登记，同一游戏根之外的节点不加入模拟或战斗总线。战斗订阅由原实例注销，分发途中注销的回调当轮失效。 |
| Resource 与实例数据 | SkillData、Buff 和 ItemData 等用于共享定义。SkillInstance、StatusInstance 和 ItemInstance 分开保存运行状态。技能升级、介质和恩赐修改使用运行时副本。 | 掉包、收包、换位与试炼容器释放由 InventoryService 写入；外部查询不再取得容器本身。装备槽校验在每个容器内执行。世界状态查询和存档恢复复制嵌套数据，防止返回值反写运行时。 |
| 输入、物理与界面 | 已有 InputMap、玩家输入适配器和场景内 UI。旧 HUD 曾靠轮询绑定，子弹窗由全局场景持有。 | HUD 改为入口注入并持有自己的子界面。旧地图传送移出物理回调，回归用例以物理重叠及 Esc 输入触发往返。打开面板或窗口失焦时立即取消未提交的施法，滚轮由 GUI 优先接收。用例覆盖真实键鼠事件、滚动、焦点和关闭面板后的法力状态。 |
| GDScript 规范 | 项目已有 LF 规则。样本中仍有较多单行分支、多语句和长方法，集中在近几轮新增的领域代码。 | EditorConfig 明确 GDScript 的 Tab 和文件尾换行。调整类声明顺序，展开 SkillManager 施法配置段的分支。后续按领域整理长方法、成员顺序和动态类型边界，避免纯格式大改掩盖行为差异。 |
| 导入和验证 | `tools/run_tests.py` 隔离数据、配置和缓存，并将错误与警告视为失败。GitHub Actions 已停用。 | Windows runner 使用独立的 APPDATA 和 LOCALAPPDATA，日志统一按 UTF-8 读取。对话 Autoload 使用资源路径，首次导入无需 UID 缓存。旧档仍用同一版本迁移路径；底层检查会拒绝类型错误和非有限值。 |

官方依据：[场景组织](https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html)、[Autoload 的适用范围](https://docs.godotengine.org/en/4.6/tutorials/best_practices/autoloads_versus_regular_nodes.html)、[Resource](https://docs.godotengine.org/en/4.6/tutorials/scripting/resources.html)、[GDScript 风格](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_styleguide.html)、[call_deferred 的执行时机](https://docs.godotengine.org/en/4.6/classes/class_object.html#class-object-method-call-deferred)。

本轮按用户指示在本地验证。Godot 4.6.3 从无 `.godot` 的 Git 树归档首次导入成功，`python tools/run_tests.py --godot <Godot console exe> --jobs 6 --timeout 90` 全部 66 项通过，包含入口启动、内容检查、真实键鼠、区域切换、战斗及持久化。云端验证留待后续。
