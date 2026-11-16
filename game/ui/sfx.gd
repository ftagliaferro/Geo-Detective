## Tiny sound-effect player with a voice pool. Any script can call Sfx.play("coin").
## Sounds are synthesized by tools/make_sfx.py (original audio, no third-party assets).
extends Node

const NAMES := ["click", "tick", "pop", "static", "lock", "shutter", "coin", "whoosh", "plane",
	"siren", "stamp", "success", "fail", "hit", "alert"]
const VOICES := 8

static var instance: Node
static var muted := false

var _streams := {}
var _players: Array = []
var _next := 0


func _ready() -> void:
	instance = self
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


static func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if instance == null or muted:
		return
	instance._play(name, volume_db, pitch)


func _play(name: String, volume_db: float, pitch: float) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
