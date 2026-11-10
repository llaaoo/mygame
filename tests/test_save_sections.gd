extends SceneTree
var failures: Array[String]=[]
class Earlier extends SaveRecord:
	@export_storage var balance := 4
	@export_storage var settings: Dictionary={"enabled":true}
	var runtime_only := 77
class Additive extends Earlier:
	@export_storage var discoveries: Array[String]=["town"]
	@export_storage var optional_budget := 9
class Renamed extends SaveRecord:
	@export_storage var purse := 0
	func save_version() -> int:return 2
	func migrate_save_data(data: Dictionary,from_version: int) -> Variant:
		if from_version==0:return data
		if from_version!=1:return null
		data["purse"]=data.get("balance",0);data.erase("balance")
		return data
class UnsupportedMigration extends Earlier:
	func save_version() -> int:return 2
class Ordered extends Earlier:
	var id := ""
	var dependencies: PackedStringArray=[]
	var trace: Array[String]=[]
	func save_dependencies() -> PackedStringArray:return dependencies
	func deserialize_save_data(data: Dictionary) -> void:
		super.deserialize_save_data(data);trace.append(id)
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func root_payload() -> Dictionary:
	var root_data:=SaveData.Root.new()
	root_data.meta=SaveData.MetaData.new();root_data.player=SaveData.PlayerData.new();root_data.world=SaveData.WorldData.new();root_data.quest=SaveData.QuestSave.new()
	return root_data.serialize()
func raw(path: String,data: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_var(data);file.close()
func run() -> void:
	await process_frame
	var old:=Earlier.new();old.balance=31;old.runtime_only=100
	var snapshot:=old.serialize_save_data()
	check(snapshot=={"balance":31,"settings":{"enabled":true}},"Unmarked runtime fields leaked or declared fields were omitted")
	var fresh:=Additive.new()
	fresh.deserialize_save_data(snapshot)
	check(fresh.balance==31 and fresh.optional_budget==9 and fresh.discoveries==["town"],"An additive field needed a central schema/version update")
	var data:=fresh.serialize_save_data();data.settings["future_setting"]={"level":7}
	fresh.discoveries.append("mine");data=fresh.serialize_save_data().merged({"settings":data.settings},true)
	old.deserialize_save_data(data);old.balance=32
	var roundtrip:=Additive.new();roundtrip.deserialize_save_data(old.serialize_save_data())
	check(roundtrip.balance==32 and roundtrip.discoveries==["town","mine"] and roundtrip.settings.future_setting.level==7,"An older record erased unknown future fields")
	var mutable:=roundtrip.serialize_save_data();mutable.discoveries.append("not-owned")
	check("not-owned" not in roundtrip.discoveries,"Serialization exposed mutable live state")
	roundtrip.deserialize_save_data({})
	check(roundtrip.balance==4 and roundtrip.optional_budget==9 and roundtrip.discoveries==["town"],"Missing fields reused previous-session values instead of defaults")
	roundtrip.deserialize_save_data({"settings":{"future_setting":7}})
	check(roundtrip.settings=={"enabled":true,"future_setting":7},"New nested defaults erased older optional settings")
	check(not roundtrip.validate_save_data({"balance":"bad"}) and not roundtrip.validate_save_data({"balance":INF}),"Declared fields accepted malformed or nonfinite data")
	var node:=Node.new()
	check(not roundtrip.validate_save_data({"future_node":node}) and not SaveValues.valid({"callback":run}),"Runtime objects/callbacks entered a value snapshot")
	node.free()
	var nodes: Array[Node]=[]
	check(not SaveValues.valid(nodes),"An empty runtime-object typed container entered a snapshot")
	var registry:=SaveSections.new();registry.register("account",fresh)
	check(not registry.register("account",Earlier.new()) and not registry.register(SaveSections.VERSIONS,fresh),"Duplicate/reserved module identity was accepted")
	check(registry.prepare({SaveSections.VERSIONS:{"absent":1}}).status==SaveSections.Status.INVALID,"A revision without its module payload was accepted")
	var state:=registry.capture({"foreign":{"unchanged":[2,3]},SaveSections.VERSIONS:{"foreign":17}})
	check(state.__versions.account==1 and state.__versions.foreign==17 and state.foreign=={"unchanged":[2,3]},"Provider capture destroyed unregistered data or its revision")
	var renamed:=Renamed.new();registry.unregister("account");registry.register("account",renamed)
	check(registry.restore(state) and renamed.purse==31 and registry.capture(state).__versions.account==2,"Local revision migration failed")
	registry.unregister("account");registry.register("account",UnsupportedMigration.new())
	check(registry.prepare(state).status==SaveSections.Status.INVALID,"A missing breaking migration silently reset data")
	var trace: Array[String]=[];var first:=Ordered.new();var second:=Ordered.new()
	first.id="first";first.trace=trace;second.id="second";second.trace=trace;second.dependencies=["first"]
	registry=SaveSections.new();registry.register("second",second);registry.register("first",first)
	check(registry.restore({"first":{"balance":9},"second":{"balance":8}}) and trace==["first","second"],"Restoration depended on registration order")
	trace.clear()
	check(not registry.restore({"first":{"balance":12},"second":{"balance":"bad"}}) and first.balance==9 and trace.is_empty(),"Invalid later module partially restored an earlier module")
	first.dependencies=["second"]
	check(registry.prepare({}).status==SaveSections.Status.INVALID,"Restore dependency cycle was accepted")
	# Real manager: unloaded extension survives another save, isolated by slot.
	var manager:=SaveManager.new();root.add_child(manager)
	var owner:=Earlier.new()
	check(manager.register_section("test.account",owner),"Provider did not register")
	check(manager.save_game(91),"Initial modular file save failed")
	var path:="user://save_91.sav";var disk:=manager.read_slot(91).data
	disk.extensions["optional.content"]={"ids":["future-item"],"value":12}
	disk.extensions.__versions["optional.content"]=12
	raw(path,disk)
	manager.unregister_section("test.account")
	check(manager.save_game(91),"Saving without an optional module failed")
	disk=manager.read_slot(91).data
	check(disk.extensions["optional.content"].value==12 and disk.extensions.__versions["optional.content"]==12 and disk.extensions["test.account"].balance==4,"Unregistered extension was deleted during real save")
	check(manager.save_game(92) and not manager.read_slot(92).data.extensions.has("optional.content"),"Opaque data leaked between save slots")
	manager.register_section("test.account",Earlier.new())
	disk.extensions.__versions["test.account"]=2;raw(path,disk)
	var bytes:=FileAccess.get_file_as_bytes(path);var backup:=FileAccess.get_file_as_bytes(path+".bak")
	check(manager.read_slot(91).status==SaveRepository.Status.UNSUPPORTED_VERSION and not manager.save_game(91),"Future module revision was downgraded to backup or overwritten")
	check(not manager.start_new_campaign(91,"test.account",{}) and FileAccess.get_file_as_bytes(path)==bytes and FileAccess.get_file_as_bytes(path+".bak")==backup,"Future module restart did not preserve original files")
	raw(path+".bak",disk);disk.extensions.__versions["test.account"]=1;raw(path,disk)
	bytes=FileAccess.get_file_as_bytes(path);backup=FileAccess.get_file_as_bytes(path+".bak")
	check(not manager.save_game(91) and not manager.start_new_campaign(91,"test.account",{}) and FileAccess.get_file_as_bytes(path)==bytes and FileAccess.get_file_as_bytes(path+".bak")==backup,"A future module in the backup was overwritten by save/restart")
	manager.unregister_section("test.account")
	manager.register_section("test.account",Renamed.new())
	check(manager.start_new_campaign(93,"test.account",{"purse":21}),"Fresh current-version campaign did not start")
	var fresh_data: Dictionary=manager.read_slot(93).data.extensions
	check(fresh_data.__versions["test.account"]==2 and fresh_data["test.account"].purse==21,"Current new-game data was incorrectly migrated as a legacy payload")
	manager.unregister_section("test.account")
	manager.free()
	if failures.is_empty():print("PASS save sections: opt-in fields/defaults, additive revisions, opaque round-trip/slot isolation, local migration, no implicit breaking reset, ordered all-validated restore, runtime value rejection and future module write/restart protection")
	quit(0 if failures.is_empty() else 1)
