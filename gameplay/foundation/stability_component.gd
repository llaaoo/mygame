class_name StabilityComponent
extends Node
var maximum := 100.0
var current := 100.0
var delay := 0.0
var recovery := 20.0
var grace := 0.0
func receive(impact: float) -> float:
	if impact<=0: return 0
	current=maxf(0,current-impact)
	delay=1.5
	if grace>0: return 0
	if current<=0: return 1.0
	return .25 if current<=maximum*.5 else 0.0
func advance(delta: float) -> void:
	grace=maxf(0,grace-delta)
	var rest:=maxf(0,delta-delay)
	delay=maxf(0,delay-delta)
	current=minf(maximum,current+recovery*rest)
func recovered() -> void:
	if current<=0: current=maximum
	grace=.6
