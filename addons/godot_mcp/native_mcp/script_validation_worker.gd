extends SceneTree
## No editor placeholders, no anonymous type identities, no gameplay scene or formal saves.
func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var request: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]+"/request.json"))
	if not request is Dictionary or not request.get("paths") is Array:quit(2);return
	var response: Dictionary=preload("res://addons/godot_mcp/utils/script_validation.gd").files(request.paths,bool(request.get("include_warnings",true)))
	response["godot_version"]=Engine.get_version_info().string
	response["user_data_dir"]=OS.get_user_data_dir()
	response["editor_hint"]=Engine.is_editor_hint()
	var output:=FileAccess.open(args[0]+"/result.json.tmp",FileAccess.WRITE)
	if not output:quit(2);return
	output.store_string(JSON.stringify(response));output.close()
	if DirAccess.rename_absolute(args[0]+"/result.json.tmp",args[0]+"/result.json")!=OK:quit(2);return
	var failed:=false
	for result: Dictionary in response.results.values():failed=failed or not result.valid
	quit(1 if failed else 0)
