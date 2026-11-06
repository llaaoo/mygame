class_name RegionContext
extends RefCounted
var root: Node2D
var id := ""
var generation := 0
var navigation: RegionNavigation
func available(token := -1) -> bool:
	return is_instance_valid(root) and root.is_inside_tree() and (token<0 or token==generation)
func leave() -> void:
	generation+=1
	root=null
	navigation=null
