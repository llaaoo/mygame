class_name RecoveryAccounting
extends RefCounted
## Allocate actual clamped recovery proportionally; never count overflow.
static func regeneration(receipt: Signal, actual: int, base: float, bonuses: Dictionary) -> void:
	var total := maxf(0, base)
	for amount in bonuses.values(): total += maxf(0, float(amount))
	if actual <= 0 or total <= 0: return
	if base > 0: receipt.emit(actual * base / total, "natural")
	for source in bonuses:
		if float(bonuses[source]) > 0: receipt.emit(actual * float(bonuses[source]) / total, str(source))
