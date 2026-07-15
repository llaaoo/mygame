# Roguelite 地图生成

## 目标

地图系统以可复现、可配置和可验证为核心。`RunManager` 只管理遭遇与房间推进，地图顺序和房间内部布局由独立生成器负责。

生成链路：

```text
run seed
  -> RunRoomGenerator.generate_run()
  -> 房间类型顺序与模板选择
  -> RunRoomLayout
  -> RunManager 实例化地面、障碍、道具、敌人和出口
```

## 文件

- `gameplay/rooms/run_room_template.gd`：配置资源，描述适用房型、权重、尺寸、结构模式和内容预算。
- `gameplay/rooms/run_room_layout.gd`：单个房间的完整生成结果。
- `gameplay/rooms/run_room_generator.gd`：确定性序列、模板抽取、坐标生成与安全检查。
- `content/rooms/*.tres`：可编辑的房间模板池。
- `tests/test_room_generation.gd`：确定性、边界、出生安全区和可达性验证。

## 当前模板

| 模板 | 结构 | 适用房型 |
|------|------|----------|
| 沉降庭院 | 四柱开放区 | 营区、机关、爆炸物 |
| 禁卫十字岗 | 交错掩体 | 营区、精英 |
| 断锁回廊 | 交替路障 | 机关、营区 |
| 黑火药库 | 分隔墙与货堆 | 爆炸物、机关 |
| 重卫刑场 | 环形掩体 | 精英 |
| 熔火审判厅 | Boss 四柱圣所 | Boss |

## 生成保证

- 相同 seed、房间序号和房型得到相同布局。
- 普通路线包含营区、机关和爆炸物房，末尾固定为精英房。
- 玩家入口、出口、障碍、交互物和敌人出生点保持安全距离。
- 障碍全部位于竞技场边界内。
- 入口到出口必须存在考虑玩家体积后的网格路径。
- 随机采样失败时使用合法网格扫描，不回退到未经验证的固定坐标。

## 新增模板

1. 在 `content/rooms/` 新建 `RunRoomTemplate` 资源。
2. 配置 `room_types`、`weight`、`arena_size`、`pattern`、`prop_budget` 和 `hazard_budget`。
3. 将资源路径加入 `RunRoomGenerator.TEMPLATE_PATHS`。
4. 若需要新结构，在 `_build_obstacles()` 增加新的 pattern。
5. 运行 `tests/test_room_generation.gd` 和 `tests/test_run_loop.gd`。

`RunState.room_plan` 会记录每个房间的 seed、类型和模板 ID，为后续局内存档、重放、每日挑战和分享 seed 保留稳定入口。
