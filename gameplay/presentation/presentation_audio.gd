class_name PresentationAudio
extends Node2D
## Bounded native voices. World/UI gain is local; no rewiring other systems' Master bus.
const MAX_VOICES := 12
var _voices: Array[Node]=[]
var played := 0
func play(definition: PresentationCue,point: Vector2,override: AudioStream=null) -> bool:
	if not is_inside_tree(): return false
	var stream:=override if override else definition.sound
	var gain:=float(PresentationPreferences.value(definition.channel+"_volume"))
	if not stream or gain<=0 or _voices.size()>=MAX_VOICES: return false
	var voice: Node
	if definition.channel=="ui": voice=AudioStreamPlayer.new()
	else: voice=AudioStreamPlayer2D.new()
	voice.set("stream",stream)
	voice.set("volume_db",definition.volume_db+linear_to_db(gain))
	voice.set_meta("base_gain",definition.volume_db)
	voice.set("max_polyphony",1)
	add_child(voice)
	if voice is AudioStreamPlayer2D: voice.global_position=point; voice.max_distance=1000
	_voices.append(voice)
	voice.connect("finished",_finished.bind(voice))
	voice.call("play"); played+=1
	return true
func _finished(voice: Node) -> void:
	_voices.erase(voice)
	if is_instance_valid(voice): voice.queue_free()
func clear() -> void:
	for voice in _voices:
		if is_instance_valid(voice): voice.queue_free()
	_voices.clear()
func _process(_delta: float) -> void:
	for voice in _voices:
		var ui:=voice is AudioStreamPlayer
		var gain:=float(PresentationPreferences.value("ui_volume" if ui else "world_volume"))
		voice.set("volume_db",-80.0 if gain<=0 else float(voice.get_meta("base_gain",-10.0))+linear_to_db(gain))

