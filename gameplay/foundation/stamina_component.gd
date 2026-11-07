class_name StaminaComponent
extends Node
signal changed(current: float,maximum: float)
var _transaction: Dictionary={}
var _pending := false
var maximum := 100.0
var current := 100.0
var delay := 0.0
var regeneration := 10.0
func spend(amount: float) -> bool:
	if amount<0 or current+.00001<amount: return false
	current=maxf(0,current-amount)
	delay=.8
	_notify()
	return true
func advance(delta: float, guarding := false) -> void:
	var rest:=maxf(0,delta-delay)
	delay=maxf(0,delay-delta)
	if rest>0 and not guarding:
		current=minf(maximum,current+regeneration*rest)
		_notify()
func configure(endurance: float,recovery_multiplier := 1.0,bonus := 0.0) -> void:
	maximum=maxf(1,80+2*endurance)
	current=minf(current,maximum)
	regeneration=maxf(0,10*recovery_multiplier+bonus)
func snapshot() -> Dictionary: return {"current":current,"maximum":maximum,"delay":delay}
func restore(data: Dictionary) -> void:
	current=clampf(float(data.get("current",maximum)),0,maximum)
	delay=clampf(float(data.get("delay",0)),0,.8)

func _notify() -> void:
	if not _transaction.is_empty(): _pending=true
	else: changed.emit(current,maximum)
func begin_transaction() -> void:
	assert(_transaction.is_empty())
	_transaction=snapshot(); _pending=false
func finish_transaction(commit: bool) -> Callable:
	if not commit: restore(_transaction)
	_transaction.clear()
	var notify:=commit and _pending; _pending=false
	return changed.emit.bind(current,maximum) if notify else Callable()
