class_name RuntimeCommand
extends RefCounted
## RuntimeCommand — 跨 Runtime 边界的异步命令
## 延迟世界工作使用带区域scope的队列；同步请求和查询使用领域公开接口

enum Target {
	COMBAT,        ## CombatRuntime
	WORLD,         ## WorldRuntime
	SIMULATION,    ## SimulationRuntime
	UI,            ## UIRuntime
	SAVE,          ## SaveRuntime
	ALL,           ## 广播
}

## ── 命令类型常量（domain-prefixed，调用方显式使用） ──
const TYPE_DESTROYED       := "world/destroyed"
const TYPE_SURFACE_CHANGE  := "simulation/surface_change"
const TYPE_RESPAWN_REQUEST := "world/respawn_request"

var type: String = ""           ## "HIT_REQUEST" / "DESTROYED" / "SURFACE_CHANGE" / "RESPAWN" / "CHUNK_LOAD"
var source: String = ""         ## 发起 Runtime 名称
var target: Target = Target.ALL ## 目标 Runtime
var payload: Dictionary = {}    ## 数据
var timestamp: int = 0          ## Time.get_ticks_msec()
var scope_id := 0


static func create(cmd_type: String, src: String, tgt: Target, data: Dictionary = {}) -> RuntimeCommand:
	var cmd := RuntimeCommand.new()
	cmd.type = cmd_type
	cmd.source = src
	cmd.target = tgt
	cmd.payload = data
	cmd.timestamp = Time.get_ticks_msec()
	return cmd


func _to_string() -> String:
	return "RuntimeCommand(%s | %s → %s | %s)" % [type, source, Target.keys()[target], payload]
