class_name WorldScope
extends RefCounted
## Legacy scene adapters may omit a context; their own ancestor is the local scope.
static func resolve(actor: Node) -> Node:
	if not actor: return null
	if "world_provider" in actor and actor.world_provider.is_valid(): return actor.world_provider.call()
	if "actor_context" in actor and actor.actor_context:
		return actor.actor_context.world()
	var node:=actor
	while node.get_parent() and not node.get_parent() is Window:
		if node.has_method("get_active_region"):
			var root: Node=node.get_active_region()
			if is_instance_valid(root): return root
		node=node.get_parent()
	return node
static func presentation(actor: Node) -> Node:
	var node:=actor
	while node.get_parent() and not node.get_parent() is Window:
		node=node.get_parent()
		var ui:=node.get_node_or_null("Interface")
		if ui: return ui
	return node
