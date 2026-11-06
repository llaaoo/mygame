extends Node
## Elemental contact rules belong to the combat world, independent of controllers.
var _effects: Array[TriggeredEffect] = []
func _ready() -> void:
	for tag in ["fire","ice","poison","water"]:
		var effect := OnHitApplyStatus.create(tag,ElementCatalog.definition(tag).hit_status_paths[0])
		_effects.append(effect)
		effect.register()
	var chain := OnHitChain.create("lightning",120.0,3,.6)
	_effects.append(chain)
	chain.register()
func _exit_tree() -> void:
	for effect in _effects: effect.unregister()
