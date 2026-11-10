class_name MemorySaveRepository
extends SaveRepository
## Isolated editor/demo session. No method reads or writes a filesystem path.
var snapshots: Dictionary={}
var archives: Array[Dictionary]=[]
func read(path: String) -> SaveRepository.ReadResult:
	if not snapshots.has(path): return ReadResult.new(Status.MISSING)
	var data: Dictionary=snapshots[path].duplicate(true)
	if int(data.get("version",1))>VERSION: return ReadResult.new(Status.UNSUPPORTED_VERSION)
	var prepared:=sections.prepare(data.get("extensions",{}))
	if prepared.status==SaveSections.Status.UNSUPPORTED: return ReadResult.new(Status.UNSUPPORTED_VERSION)
	if prepared.status!=SaveSections.Status.VALID or not _valid_shape(data): return ReadResult.new(Status.INVALID)
	data.extensions=prepared.data
	return ReadResult.new(Status.VALID,data)
func write(path: String,data: Dictionary) -> bool:
	if not _valid_shape(data) or int(data.get("version",0))!=VERSION or read(path).status==Status.UNSUPPORTED_VERSION: return false
	snapshots[path]=data.duplicate(true)
	return true
func start_new(path: String,fresh: Dictionary,current: Dictionary) -> String:
	if not _valid_shape(current) or not write(path,fresh): return ""
	archives.append(current.duplicate(true))
	return "memory://journey/%d"%archives.size()
