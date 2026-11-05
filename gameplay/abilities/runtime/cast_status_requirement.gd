class_name CastStatusRequirement
extends RefCounted
enum ConsumptionMode { FULL, HALF_LIFETIME }

var id: String
var version: int
var consume: bool
var stacks := 0
var cost: int
var factor: float
var mode := ConsumptionMode.FULL

func _init(status_id: String, revision: int, spend: bool, mana: int = 0, multiplier: float = 1.0) -> void:
	id = status_id
	version = revision
	consume = spend
	cost = mana
	factor = multiplier

func fingerprint() -> Array:
	return [id, version, consume, stacks, cost, factor, mode]
