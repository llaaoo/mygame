class_name OperationResult
extends RefCounted
var accepted := false
var reason := ""
var moved := 0
var item_uids: Array[String] = []
static func reject(why: String) -> OperationResult:
	var result:=OperationResult.new()
	result.reason=why
	return result
static func success(count := 0) -> OperationResult:
	var result:=OperationResult.new()
	result.accepted=true
	result.moved=count
	return result
