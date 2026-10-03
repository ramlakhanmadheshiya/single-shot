extends Node
## Small pooled one-shot player system plus independently mixed music.
const SOUND_DIR: String = "res://assets/audio/"
var music_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("UI")
	music_player = _make_player("Music")
	ui_player = _make_player("UI")
	for index: int in 8:
		sfx_players.append(_make_player("SFX"))
	Events.sound_requested.connect(play_sfx)
	_apply_volumes()
	if DisplayServer.get_name() != "headless":
		music_player.stream = load(SOUND_DIR + "menu_waltz.wav") as AudioStream
		if music_player.stream is AudioStreamWAV:
			(music_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		music_player.volume_db = -9.0
		if not OS.has_feature("web"):
			music_player.play()

func start_after_user_gesture() -> void:
	if music_player != null and music_player.stream != null and not music_player.playing:
		music_player.play()

func _make_player(bus_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func play_sfx(sound_id: String) -> void:
	var path: String = SOUND_DIR + sound_id + ".wav"
	if not ResourceLoader.exists(path):
		path = SOUND_DIR + "ui_click.wav"
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = sfx_players[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % sfx_players.size()
	player.stream = stream
	player.pitch_scale = _rng.randf_range(0.92, 1.08)
	player.play()

func play_ui(sound_id: String = "ui_click") -> void:
	var path: String = SOUND_DIR + sound_id + ".wav"
	if ResourceLoader.exists(path):
		ui_player.stream = load(path) as AudioStream
		ui_player.play()

func set_bus_linear(bus_name: String, amount: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		var clamped: float = clampf(amount, 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.0001)))

func _apply_volumes() -> void:
	set_bus_linear("Music", float(SaveSystem.get_setting("music", 0.65)))
	set_bus_linear("SFX", float(SaveSystem.get_setting("sfx", 0.8)))
	set_bus_linear("UI", float(SaveSystem.get_setting("ui", 0.85)))
