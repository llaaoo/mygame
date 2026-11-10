# 存档扩展与兼容契约

2026-11-10，北京时间。当前实现将文件封装、模块演进、领域状态与运行时场景分开。普通新增内容或可选字段不再要求改集中序列化清单或递增全局版本；改变旧字段的含义仍需显式迁移。验证记录见[SAVE_SYSTEM_VALIDATION](SAVE_SYSTEM_VALIDATION.md)。

## 所有权与格式

| 层 | 所有者 | 职责 |
|---|---|---|
| 文件 | SaveRepository | 有界纯值读取、历史封装迁移、临时文件替换、备份恢复、新旅程归档 |
| 槽位与装配 | SaveManager | 目标槽读取、模块收集、保存/加载入口，阻止不支持的旧读取器覆盖新档 |
| 独立模块 | SaveSections | 显式登记、模块版本、迁移、依赖顺序、全模块预校验 |
| 纯数据记录 | SaveRecord / SaveFields | 仅收集声明的持久字段、缺字段默认值、未知字段往返 |
| 现有领域服务 | SaveAdapter | 复用原服务snapshot/restore/validator，不建立第二份权威状态 |
| 战役 | ExplorationProgress / CampaignSession | 进度记录与战役服务的组合；库存、人物、余量、时间仍复用领域边界 |

文件封装当前为v10；v1—v9的历史迁移保留。v10引入独立模块版本契约，此后添加物品、配方、地图或可选字段，不因此升封装版本。顶层meta/player/world/quest保留旧模式兼容，新系统进入extensions或战役模块。

已有有效载荷结构保持原样，只增加保留键`__versions`：

```text
version: 10
extensions:
  __versions: {grayriver: 1}
  grayriver:
    ...探索进度字段...
    foundation:
      ...inventory / actors / clock_seconds...
      __versions: {production: 1, relations: 1, conversations: 1}
      production: {...}
      relations: {...}
      conversations: {...}
```

上面的grayriver是示意模块ID，实际使用CampaignGame.save_section。缺少版本元数据的旧模块按局部版本0处理。不存在的新模块按当前默认值初始化，不假装有一份历史数据来迁移。

## 新增可选字段

只用于无参构造、无副作用的RefCounted纯数据所有者：

```gdscript
class_name SurveyProgress
extends SaveRecord

@export_storage var discoveries: Array[String] = []
@export_storage var settings: Dictionary = {"show_markers": true}
var selected_marker := "" # 界面临时选择，不保存
```

`@export_storage`是Godot原生存储标记。SaveFields只读取这一类脚本属性，不枚举场景树或把所有成员自动写入文件。不要用编辑器`@export`代替，也不要把Node、Resource、Callable、Signal、RID或场景路径对象标记为持久字段；资源引用保存稳定内容ID或路径字符串，由领域目录解析。

声明中增加带默认值的字段即可，继承字段也包含在内。旧档缺字段时使用一份新实例的声明默认值，不使用上一次旅程残留状态；默认字典的新键会补齐，数组按保存的整体内容恢复，不逐元素合并。未知字段与字典键保留，快照和恢复数据都复制，避免UI修改快照影响实时状态。

SaveFields缓存纯原型的字段默认值，因此构造器不得注册事件、创建节点或启动服务。需要领域行为、嵌套实例、强约束或现有自定义格式的系统，用独立provider/SaveAdapter；不把复杂Node改成SaveRecord。类型、值边界之外的UID、容量、合法ID和跨引用仍由所属模块validator检查。空值默认字段不表达任意对象类型。

ExplorationProgress已移除手写保存字段清单，使用此方式；其库存、任务、成长等语义校验和历史规范化保留。

## 新增独立系统

在组合根完成配置后、读取存档前登记：

```gdscript
var survey := SurveyProgress.new()
session.save_sections.register("survey", survey)
```

这样会进入CampaignSession.snapshot/restore，无须修改SaveManager、SaveData、全局迁移或集中收集列表。跨战役的模块可使用`save_manager.register_section("my.system", provider)`；同一ID重复绑定不同所有者会被拒绝，`__`前缀保留给元数据。RefCounted由登记表持有，Node只留WeakRef；卸载Node前应注销，不能让失效provider参与恢复。

provider实现`serialize_save_data() -> Dictionary`与`deserialize_save_data(Dictionary)`；推荐同时实现`validate_save_data(Variant) -> bool`。可选接口为`save_version()`（默认1）、`migrate_save_data(data, from_version)`、`save_dependencies()`和`save_read_status(data)`。嵌套登记表通过最后一个接口将未来版本状态传播到文件层。

生产、关系与交谈已用SaveAdapter接入。适配器在完成默认配置后捕获初始快照；缺失模块恢复这份默认值，保留原有卫兵敌对关系，不通过空快照清空默认规则。适配器保留未知顶层字段，列表成员和嵌套语义由原服务负责。

登记不是热插拔加载机制：加载完成后才登记的系统不会自动恢复旧载荷。游戏中的测试性晚登记只验证后续保存；正式系统必须在读档前登记。卸载模块的数据仍保留在该槽原载荷中，再次正常保存不会删除它，也不会将它复制到另一个槽。

## 何时需要迁移

| 变化 | 做法 |
|---|---|
| 新物品、地图、配方，复用现有语义 | 登记内容、保持稳定ID；不升存档版本 |
| 新可选字段，旧档可采用默认值 | 声明字段/default；不升局部版本 |
| 新服务 | 装配时登记自己的provider；不改集中格式 |
| 字段改名、单位/含义改变、结构调整、删除/替换持久ID | 所属模块升版，显式局部迁移并验证真实旧档 |
| 文件编码或封装兼容契约改变 | 才考虑SaveRepository.VERSION及封装迁移 |

局部迁移按0→1→2顺序执行，返回新字典；不能修改当前游戏或外部库存。例：

```gdscript
func save_version() -> int:
    return 2

func migrate_save_data(data: Dictionary, from_version: int) -> Variant:
    if from_version == 0:
        return data # 原无版本载荷兼容版本1
    if from_version == 1:
        data["purse"] = data.get("balance", 0)
        data.erase("balance")
        return data
    return null
```

缺少破坏兼容的迁移会拒绝该数据，不以空字典重建。SaveRecord默认只接受旧无版本载荷0→1；更高迁移必须明确实现。不要在迁移中给已有库存补模板、重分配UID或补满喷剂/涂层/计时。

## 恢复与故障边界

先完成纯值检查、所有已登记模块的迁移/校验与依赖排序，再调用恢复函数。`save_dependencies()`列出同一登记表内必须先恢复的ID；缺失依赖与环都会拒绝恢复。已知模块局部版本较新时返回UNSUPPORTED_VERSION，阻止回退到较老备份、自动/手动覆盖和重新开始覆盖。未知模块版本没有可比较的读取器，因此只原样保留，不执行它。

恢复函数须为通过校验后可确定完成的内存写入，不交易、不奖励、不广播施法或扣款事实。登记表防止校验失败导致前面模块已经恢复，但不为任意回调异常或外部副作用提供通用事务回滚；新复杂服务须把失败条件放到validator或自己的事务中。CampaignSession先恢复时钟、库存、人物记录，再恢复生产等依赖它们的服务。

文件get_var(false)不实例化对象；进一步限制64MiB封装、值深度和数量，拒绝运行时引用与非有限浮点。已有.tmp/.bak和新旅程归档规则保留。损坏文件仍按恢复规则选择有效备份；未来已知版本不属于损坏，不能因此加载并覆盖旧备份。F9失败保留当前游戏状态。

这不是删除或更换任意内容都自动兼容的承诺。业务语义变化仍需局部迁移；人物共同记录、库存、计时等专有格式仍由原领域维护。集中封装不再承担每项内容发布的维护成本。
