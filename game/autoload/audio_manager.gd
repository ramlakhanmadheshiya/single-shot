extends Node
## Crossfading music per chapter plus a pooled, pitchable sound-effect player.

const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DB: float = -12.0
## C major pentatonic, two octaves: target pops climb this ladder within a shot.
const PENTATONIC: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5, 3.0]

var mute_for_tests: bool = false
var _music: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current_track: String = ""
var _sfx: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _unlocked: bool = false
var _last_play_msec: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for bus: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i: int in 2:
		var m: AudioStreamPlayer = AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	for i: int in 12:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	# Browsers only allow audio after a user gesture.
	_unlocked = not OS.has_feature("web")
	Events.setting_changed.connect(_on_setting)
	_apply_settings()


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
		_unlocked = true
		if not _current_track.is_empty():
			var wanted: String = _current_track
			_current_track = ""
			play_music(wanted)


func _silent() -> bool:
	return mute_for_tests or DisplayServer.get_name() == "headless"


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_cache[path] = s
	return s


## Crossfades to a music track ("menu", "ch1"...). Safe to call repeatedly.
func play_music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	if _silent() or not _unlocked:
		return
	var stream: AudioStream = _load(MUSIC_DIR + track + ".wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	var old: AudioStreamPlayer = _music[_active]
	_active = 1 - _active
	var new: AudioStreamPlayer = _music[_active]
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(new, "volume_db", MUSIC_DB, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(old, "volume_db", -60.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(old.stop)


## Plays a one-shot effect. pitch < 0 means a small random variation.
func play(id: String, pitch: float = -1.0, volume_db: float = 0.0) -> void:
	if _silent():
		return
	# Avoid machine-gun stacking of the same sound within a few milliseconds.
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play_msec.get(id, -1000)) < 28:
		return
	_last_play_msec[id] = now
	var stream: AudioStream = _load(SFX_DIR + id + ".wav")
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx[_cursor]
	_cursor = (_cursor + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = pitch if pitch > 0.0 else _rng.randf_range(0.95, 1.05)
	p.volume_db = volume_db
	p.play()


## The n-th note of the pop ladder, so combo chains sound like a melody.
func play_note(id: String, step: int, volume_db: float = 0.0) -> void:
	play(id, PENTATONIC[clampi(step, 0, PENTATONIC.size() - 1)], volume_db)


func play_ui(id: String = "ui_tap") -> void:
	play(id, 1.0, -2.0)


func _on_setting(_key: String, _value: Variant) -> void:
	_apply_settings()


func _apply_settings() -> void:
	_set_bus("Music", float(SaveSystem.get_setting("music_volume", 0.5)))
	var sound: float = float(SaveSystem.get_setting("sound_volume", 0.75))
	_set_bus("SFX", sound)
	_set_bus("UI", sound)


## Volume is a 0..1 slider value; perceived loudness is logarithmic, so map to dB.
func _set_bus(bus: String, amount: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, amount <= 0.01)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(amount, 0.0001, 1.0)))
