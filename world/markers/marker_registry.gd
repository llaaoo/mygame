class_name MarkerRegistry
extends RefCounted
## Finds an authored marker within one map, even before that map enters the tree.


static func find_marker(marker_id: String, scope: Node) -> WorldMarker:
	if marker_id.is_empty() or not is_instance_valid(scope) or scope.is_queued_for_deletion():
		return null
	var candidate := scope as WorldMarker
	if candidate and candidate.marker_id == marker_id:
		return candidate
	for child in scope.get_children():
		var marker := find_marker(marker_id, child)
		if marker:
			return marker
	return null
