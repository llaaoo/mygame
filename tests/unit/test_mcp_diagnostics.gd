extends GutTest
const Validation=preload("res://addons/godot_mcp/utils/script_validation.gd")
const Capture=preload("res://addons/godot_mcp/utils/diagnostic_capture.gd")

class ProbeBridge extends RefCounted:
	var fresh: Dictionary={}
	func get_captured_messages(_count: int,_offset: int,_order: String) -> Dictionary:return {}
	func get_captured_message_after_sequence(sequence: int,_messages: Array,_errors: Array,_fields: Dictionary) -> Dictionary:
		return fresh if int(fresh.get("sequence",0))>sequence else {}
	func get_latest_message_payload(_message: String,_fields: Dictionary={}) -> Dictionary:return {"fps":999}

func test_named_project_types_keep_their_real_compilation_context() -> void:
	for path in ["res://gameplay/foundation/campaign_session.gd","res://gameplay/foundation/data/world_condition.gd"]:
		var original:=load(path) as GDScript
		var source:=FileAccess.get_file_as_string(path)
		var result:=Validation.context(path,source)
		assert_true(result.get("compiled",false),path)
		assert_same(result.get("script"),original,"Validation must not replace live global-class resources")
		assert_eq(original.source_code,source)

func test_unsaved_named_type_reports_missing_context_instead_of_syntax_error() -> void:
	var result:=Validation.context("","class_name UnsavedSelfReference\nextends RefCounted\nvar next: UnsavedSelfReference\n")
	assert_eq(result.get("validation_status"),"requires_saved_context")
	assert_true(result.has("error"))

func test_stdout_capture_preserves_duplicate_messages_and_closes_scope() -> void:
	var capture:=Capture.new();capture.begin()
	print("mcp-scope-proof");print("mcp-scope-proof")
	var result:=capture.finish()
	assert_true(result.success)
	assert_eq(result.output,["mcp-scope-proof","mcp-scope-proof"])
	print("outside-mcp-scope")
	assert_eq(result.output.size(),2)

func test_old_debugger_messages_cannot_complete_a_new_runtime_request() -> void:
	var tools:=DebugToolsNative.new();var bridge:=ProbeBridge.new()
	assert_true(tools._extract_pending_runtime_probe_response(bridge,{"baseline_sequence":10},["mcp:performance_snapshot"],{}).is_empty())
	bridge.fresh={"sequence":11,"message":"mcp:performance_snapshot","data":[{"fps":60}]}
	var result:=tools._extract_pending_runtime_probe_response(bridge,{"baseline_sequence":10},["mcp:performance_snapshot"],{})
	assert_eq(result.get("status"),"success")
	assert_eq(result.get("fps"),60)
	assert_true(tools._extract_pending_runtime_probe_response(bridge,{"baseline_sequence":11},["mcp:performance_snapshot"],{}).is_empty())

func test_validation_worker_propagates_real_compile_failure() -> void:
	var folder:=OS.get_user_data_dir().path_join("mcp-negative-worker")
	DirAccess.make_dir_recursive_absolute(folder)
	var fixture:=FileAccess.open(folder+"/invalid.gd",FileAccess.WRITE)
	fixture.store_string("extends RefCounted\nfunc broken(\n");fixture.close()
	var request:=FileAccess.open(folder+"/request.json",FileAccess.WRITE)
	request.store_string(JSON.stringify({"paths":[folder+"/invalid.gd"],"include_warnings":false}));request.close()
	var output: Array=[]
	var args:=PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://addons/godot_mcp/native_mcp/script_validation_worker.gd","--",folder])
	var code:=OS.execute(OS.get_executable_path(),args,output,true)
	assert_eq(code,1,"A real parse failure cannot be reported as successful worker exit")
	assert_true(FileAccess.file_exists(folder+"/result.json"))
	if not FileAccess.file_exists(folder+"/result.json"):return
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/result.json"))
	var result: Dictionary=report.results[folder+"/invalid.gd"]
	assert_false(result.valid)
	assert_gt(int(result.error_count),0)
	assert_false(report.editor_hint)
	assert_true(str(output).contains("Parse Error"),"Fixture must exercise the actual Godot compiler")
	var log:=FileAccess.open(folder+"/expected-compile-error.log",FileAccess.WRITE)
	for part in output:log.store_string(str(part))
	log.close()
