class_name HitResult
extends RefCounted
## Acceptance is decided before reactions; damage_dealt is final on report_hit return.
var accepted := false
var damage_accepted := false
var status_accepted := false
var rejection := ""
var attempted_damage := 0
var damage_dealt := 0
var elemental_damage := 0
var buildup_triggered := false

var parried := false
var interrupted := false
var pushed := false
var blocked := false
var guard_broken := false
var impact_applied := 0.0
