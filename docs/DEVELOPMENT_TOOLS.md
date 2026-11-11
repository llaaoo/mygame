# 开发插件与回归流程

核对日期：2026-11-11；本项目使用Godot 4.6.3、GDScript与原生2D场景。插件须服务现有领域边界，不另建库存、任务、知识或AI权威。本轮操作、性能与引用清理改动见[整改说明](STUDIO_REVIEW_FIXES.md)，第三方局部修改见[清理补丁](dependencies/editor-cleanup-patches.md)。

## 为什么测试曾反复失败

此前有真实代码缺陷：元数据空默认值、校验器缩进、统一知识映射和任务准备提示；也有测试自身的错误假设：固定等帧跨越重击阈值/连招窗口、访问被真实攻击击杀的靶、使用旧武技查询、把启动时世界推进与自然回复当作存档错误、在短准备姿态结束后才采样。具体修复与最终142/142记录见[上一轮报告](playtests/rpg-world-depth/REPORT.md)。

开发流程也有问题：修改尚未稳定就反复启动全量，且定向测试、导入和原生窗口曾重叠运行，增加资源竞争与排查时间。失败不能一概称作环境问题；要先分清游戏缺陷、测试契约失效和平台限制。增加超时、重跑直到绿、禁用正常AI或放宽真实费用断言都不能替代诊断。

当前runner在日志之外生成`results.json`：记录源码提交/脏状态、引擎、平台、命令、退出码、耗时与首条诊断。类别只描述观察到的`script_error/godot_error/warning/exit_code/timeout`，不自动断定是游戏还是夹具的问题。前置失败明确列出`skipped`，不算通过。GUT额外要求存在非空JUnit结果，失败或待定用例不算绿色。

## ChatGPT插件：查询结果与实际使用

通过Plugin Management目录查询`game development Godot`、`Blender game assets`、`Figma`、`Game Studio Godot Blender`，并单独查询`Godot`、`Blender`、`Game Studio`。搜索结果不穷尽整个[插件目录](https://chatgpt.com/plugins)。

| 工具 | 对本项目的用途 | 本轮状态 |
| --- | --- | --- |
| GitHub | 读取上游版本/许可、检查分支/保护、PR交付 | 已连接；实际读取GUT官方README核对4.6版本匹配 |
| Plugin Management | 查询可用插件及连接状态 | 已使用；不会把推荐或待连接写成已安装 |
| Cloud Environment | 环境/网络诊断，原生编辑器验证 | 已使用；当前会话没有暴露桌面控制工具，原生窗口另用Xorg验证 |
| Figma | HUD、装备页、菜单的设计稿与设计交付 | 已安装且工具可发现；实际whoami返回OAuth未认证，未读取或产出设计稿 |
| Context7 | 开发库文档/API检索，需逐库确认实际覆盖 | 目录返回，未连接；此次用GitHub与官方文档完成核对 |
| Superpowers | 规划、调试和开发流程技能 | 目录返回，未安装；此次按本仓库AGENTS执行 |
| Game Studio | 当前可见技能主要服务浏览器游戏、WebGL与网页界面 | 已采用UI信息层级与真实输入/截图规范，仍使用原生Godot |
| Design Game Studio | 现有Godot项目维护、玩法边界、素材、性能与协作验收 | 已采用相关技能；真实分工覆盖界面、武器表现、工具/性能诊断、配方与引用审计，并独立复核输入/字号边界 |

本次目录查询没有返回可确认的专用Godot/Blender连接器。没有调用未连接插件，没有提供API密钥、启动付费AI服务或安装外部服务端。Figma等需要用户完成ChatGPT连接后才能实际调用；这不阻塞Godot工程工作。

## Godot插件取舍

| 插件/本地版本 | 项目中的实际用途 | 决定 |
| --- | --- | --- |
| **GUT 9.6.1** | `tests/unit`中库存事务、装备身份、背包恢复、知识隔离；编辑器与统一runner共用目录 | 本轮新增并启用，MIT，Godot 4.6匹配 |
| **State Charts 0.22.4** | `entities/enemy/enemy.tscn`和Boss场景的Idle/Chase/Attack状态机 | 保留并验证既有实际使用，不再引入另一套行为树控制同一敌人 |
| LimboAI（已有GDExtension） | 已随库保存，原生编辑器可见；当前玩法源码未发现BTPlayer/LimboHSM引用 | 暂不另接一套行为树控制现有State Charts敌人，本轮未升级 |
| **Dialogue Manager 3.10.4** | 已启用，既有NPC对话适配与编辑器工具 | 保留；不在此轮升级到4.x，也不另造任务/人情状态，灰河谷会话仍归NpcConversationService |
| **Grayriver Map Authoring 1.0** | 编辑器地图校验、命名落点、隔离试玩 | 自有插件继续使用，见[工作流](MAP_AUTHORING.md) |
| Phantom Camera 0.11 | 已随库保存，但未启用或接入当前游戏镜头 | 适合后续镜头/过场；当前已有镜头表现服务，不为安装而替换瞄准链 |
| Importality 0.3.0 | 已保存，当前未启用 | 有Aseprite/Krita导入需求且工具链/许可核实后再接；不声称已导入新动画 |
| Godot MCP Native 1.0.0 | 已启用的编辑器桥 | 已通过项目CLI实际连通；支持隔离运行检查、输入和截图，见[MCP工作流](GODOT_MCP_WORKFLOW.md)。当前ChatGPT工具列表仍没有直接注册的Godot工具 |
| Godot AI / Gamedev AI | 已保存、未启用 | 本轮不接付费提供商或引入运行时网络依赖 |

参考上游：[GUT版本矩阵](https://github.com/bitwes/Gut/blob/v9.6.1/README.md)、[GUT 9.6.1文档](https://gut.readthedocs.io/en/v9.6.1/)、[State Charts](https://github.com/derkork/godot-statecharts)、[Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager)、[Phantom Camera](https://phantom-camera.dev/)。注意上游最新版和本地已安装版本不同，不能拿最新版文档直接宣称本地拥有全部能力。

### GUT来源、许可与本地补丁

- 上游：https://github.com/bitwes/Gut ，tag `v9.6.1`，提交`c80954f47bed74a0a2c471d472c0389f98e0a8f6`。
- 仅复制上游`addons/gut`，包含MIT许可`addons/gut/LICENSE.md`、资源与UID；散列见[依赖清单](dependencies/gut-9.6.1.sha256)。不在运行时下载插件。
- 唯一本地源码补丁：`gut_plugin.gd`的自动更新请求受`gut/auto_check_updates`控制，默认false。云端Godot HTTPRequest的可选更新请求实测失败，不能让它成为编辑器启动错误；仍保留用户主动检查更新和本地版本校验。没有屏蔽测试错误，也未修改GUT断言。
- GUT是开发工具，不作为新增玩法单例，不替代真实输入、正常AI、保存重进和原生渲染验收。

## 怎么运行

```sh
# 不启动游戏，验证runner确实识别错误、超时、空结果、前置失败与竞争运行
python3 -m unittest tools/test_run_tests.py -v

# 快速、无世界启动的真实领域规则（GUT，仍由runner隔离user://）
python3 tools/run_tests.py --tests gut_domain

# 先做和改动对应的集成检查
python3 tools/run_tests.py --tests foundation_inventory world_depth_knowledge

# 代码稳定后，从干净提交归档做一次完整回归
python3 tools/run_tests.py --suite all --jobs 2 --timeout 300 --report /tmp/grayriver-results.json
```

同一检出目录由OS文件锁防止两个runner同时启动；进程退出自动释放锁。首次导入采用recovery模式，不启动编辑器插件。选中`content/maps/gut_domain`时先执行这些前置，失败就停止后续；其他检查按`--jobs`并行，继承真实输入探针或含输入事件的脚本放到最后串行，避免短战斗窗口与其他Godot进程竞争。`--tests`仍只运行指定项目，不悄悄扩大全量。

归档没有`.git`时，可用`--source-revision <归档提交SHA>`标注来源；`dirty`记为null，表示runner无法自行从Git核对工作区，不能将其误写成clean。归档命令与实际来源另在验收报告登记。

编辑器启用GUT后可在底部GUT面板或`Project → Tools → GUT`运行。首次编辑器使用时，在GUT设置中载入项目根的`.gutconfig.json`，目录应为`res://tests/unit`，不要把旧SceneTree集成脚本目录一起扫描。编辑器使用其本机`user://`配置；需要测试保存行为时仍用隔离runner。

新纯领域测试用GUT验证失败边界、守恒、防重和查询隔离；需要场景/物理/输入/AI/持久化时继续用现有集成夹具。异步探针等待实际可观察状态并设置上界，动作窗口内不要塞额外准备帧。不得在完整回归进行时继续改源码、运行导入或启动图形试玩；检查最终报告，不能凭若干中间PASS宣称全量通过。GitHub Actions继续停用。

本轮定向、原生编辑器与干净归档完整回归证据见[验证报告](playtests/development-tools/REPORT.md)。
