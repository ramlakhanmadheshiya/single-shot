class_name PromoVideo
extends Node
## Makes the share video: the game's opening, the player's winning shot in its
## room, the result card, and an end card that invites friends to play (QR code,
## web address, Google Play). Rendered off-screen frame by frame on a fixed clock,
## so it is smooth however fast the phone is; encoded to MP4 by the OCSVideo
## Android plugin with the menu theme underneath.

signal progress(fraction: float)
signal done(ok: bool, message: String)

const SIZE: Vector2i = Vector2i(540, 960)
const FPS: int = 30
const INTRO: float = 2.4
const AIM: float = 1.0
const RESULT: float = 2.8
const OUTRO: float = 3.4
const MAX_SHOT: float = 7.0
const MUSIC: String = "res://assets/promo/promo_music.wav"
const URL: String = "theramlakhan.com/one-clean-shot"

var info: Dictionary = {}
## Where the finished MP4 was written (Android).
var video_path: String = ""
var _busy: bool = false


static func available() -> bool:
	return Engine.has_singleton("OCSVideo") or (OS.is_debug_build() and not OS.has_feature("mobile") and not OS.has_feature("web"))


## Renders and encodes the video for `data` (the result card's share info).
func make(data: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	info = data
	var plugin: Object = Engine.get_singleton("OCSVideo") if Engine.has_singleton("OCSVideo") else null
	if plugin == null and not available():
		_busy = false
		done.emit(false, "Saving the video works in the Android app.")
		return
	if DisplayServer.get_name() == "headless":
		_busy = false
		done.emit(false, "No screen to render on.")
		return
	var level: Dictionary = info["level"]
	var pal: Dictionary = info["pal"]
	var angle: float = float(info["angle"])
	var t0: float = float(info.get("t0", 0.0))
	# How long the shot plays, sped up if it would drag on.
	var st: Dictionary = RicochetSim.initial_state(level)
	st["t0"] = t0
	var flight: float = float(RicochetSim.simulate(level, st, angle)["duration"]) / Board.SPEED
	var fast: float = 1.0
	var shot: float = flight + 1.3
	if shot > MAX_SHOT:
		fast = flight / (MAX_SHOT - 1.3)
		shot = MAX_SHOT
	var total: float = INTRO + AIM + shot + RESULT + OUTRO
	var frames: int = int(ceil(total * float(FPS)))

	# Off-screen stage.
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var splash: Splash = Splash.new()
	splash.manual = true
	splash.size = Vector2(SIZE)
	vp.add_child(splash)
	var room: _Room = _Room.new()
	room.pal = pal
	room.title = "%s  ·  Level %d" % [info["chapter"], int(info["number"])]
	room.size = Vector2(SIZE)
	room.visible = false
	vp.add_child(room)
	var board: Board = Board.new()
	board.quiet = true
	board.input_enabled = false
	board.position = Vector2(20, 120)
	board.size = Vector2(500, 760)
	room.add_child(board)
	board.setup(level, pal)
	board.set_process(false)
	var card: _ResultCard = _ResultCard.new()
	card.pal = pal
	card.info = info
	card.size = Vector2(SIZE)
	card.visible = false
	room.add_child(card)
	var outro: _Outro = _Outro.new()
	outro.size = Vector2(SIZE)
	outro.visible = false
	vp.add_child(outro)

	# Encoder.
	var dir: String = ProjectSettings.globalize_path("user://share")
	DirAccess.make_dir_recursive_absolute(dir)
	var name: String = "one-clean-shot-%s-%02d" % [str(info["chapter"]).to_lower(), int(info["number"])]
	video_path = dir.path_join(name + ".mp4")
	var frame_dir: String = dir.path_join("video_frames")
	if plugin != null:
		var wav: String = dir.path_join("promo_music.wav")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(MUSIC)
		if not bytes.is_empty():
			var f: FileAccess = FileAccess.open(wav, FileAccess.WRITE)
			if f != null:
				f.store_buffer(bytes)
				f.close()
		else:
			wav = ""
		if not bool(plugin.call("begin", video_path, SIZE.x, SIZE.y, FPS, frames, wav)):
			_cleanup(vp)
			done.emit(false, "Couldn't start the video (%s)." % str(plugin.call("lastError")))
			return
	else:
		# Desktop (debug): write the frames so the video can be checked.
		DirAccess.make_dir_recursive_absolute(frame_dir)

	var dt: float = 1.0 / float(FPS)
	var shot_start: float = INTRO + AIM
	var result_start: float = shot_start + shot
	var outro_start: float = result_start + RESULT
	var fired: bool = false
	for i: int in frames:
		var t: float = float(i) * dt
		splash.visible = t < INTRO
		room.visible = t >= INTRO and t < outro_start
		outro.visible = t >= outro_start
		if t < INTRO:
			splash.show_at(t)
		elif t < shot_start:
			# Line up the shot: the aim swings from straight up onto the winning angle,
			# and moving platforms glide into the moment of release.
			var k: float = (t - INTRO) / AIM
			var e: float = 1.0 - pow(1.0 - clampf(k * 1.4, 0.0, 1.0), 3.0)
			board._process(dt)
			board.set("_world_t", t0 - (shot_start - t) * Board.SPEED)
			board.has_aim = true
			board.aim_angle = lerp_angle(-PI / 2.0, angle, e)
			board.set("_preview", {})
		elif t < result_start:
			if not fired:
				fired = true
				board.replay(angle, t0)
				board.set("_fast", fast)
			board._process(dt)
		else:
			board._process(dt)
			card.visible = t < outro_start
			card.show_at(t - result_start)
		if outro.visible:
			outro.show_at(t - outro_start)
		room.queue_redraw()
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		if img == null:
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if plugin != null:
			if not bool(plugin.call("addFrame", img.get_data())):
				_cleanup(vp)
				done.emit(false, "The video stopped (%s)." % str(plugin.call("lastError")))
				return
		elif i % 3 == 0:
			img.save_jpg(frame_dir.path_join("frame_%04d.jpg" % i), 0.85)
		progress.emit(float(i + 1) / float(frames))
	_cleanup(vp)
	if plugin == null:
		done.emit(true, "Video frames saved (MP4 encoding runs on Android)")
		return
	if not bool(plugin.call("finish")):
		done.emit(false, "Couldn't finish the video (%s)." % str(plugin.call("lastError")))
		return
	if bool(plugin.call("saveToGallery", video_path, name + ".mp4")):
		done.emit(true, "Saved to Movies › One Clean Shot")
	else:
		done.emit(true, "Video ready. Share it to save a copy.")


func share(text: String) -> bool:
	if Engine.has_singleton("OCSVideo") and not video_path.is_empty():
		return bool(Engine.get_singleton("OCSVideo").call("share", video_path, text))
	return false


func _cleanup(vp: SubViewport) -> void:
	_busy = false
	vp.queue_free()


## The room scene: the chapter's backdrop and a title over the board.
class _Room:
	extends Control
	var pal: Dictionary
	var title: String = ""

	func _draw() -> void:
		var top: Color = pal["top"]
		var bottom: Color = pal["bottom"]
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
		var f: Font = UIKit.font(600)
		var w: float = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(f, Vector2((size.x - w) * 0.5, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, pal["ink"])
		var sub: String = "ONE SHOT"
		var f2: Font = UIKit.font(700)
		var w2: float = f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f2, Vector2((size.x - w2) * 0.5, 100), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, pal["accent"])
		var f3: Font = UIKit.font(500)
		var tag: String = "one clean shot"
		var w3: float = f3.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f3, Vector2((size.x - w3) * 0.5, size.y - 40), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pal["muted"])


## The result: stars popping in, the title and how it went.
class _ResultCard:
	extends Control
	var pal: Dictionary
	var info: Dictionary
	var _t: float = 0.0

	func show_at(t: float) -> void:
		_t = t
		queue_redraw()

	func _text(s: String, y: float, fs: int, weight: int, col: Color) -> void:
		var f: Font = UIKit.font(weight)
		var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - w) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _draw() -> void:
		var a: float = clampf(_t / 0.3, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(pal["bottom"], 0.65 * a))
		var pop: float = 1.0 - pow(1.0 - clampf(_t / 0.4, 0.0, 1.0), 3.0)
		var card: Rect2 = Rect2(Vector2(40, 250), Vector2(460, 440))
		var c: Vector2 = card.get_center()
		card = Rect2(c - card.size * 0.5 * (0.9 + 0.1 * pop), card.size * (0.9 + 0.1 * pop))
		var sb: StyleBoxFlat = UIKit.card_style(pal)
		sb.bg_color = Color(sb.bg_color, a)
		draw_style_box(sb, card)
		_text("%s  ·  LEVEL %d" % [str(info["chapter"]).to_upper(), int(info["number"])], card.position.y + 70, 20, 700, Color(pal["accent"], a))
		_text(str(info["title"]), card.position.y + 140, 48, 500, Color(pal["ink"], a))
		for i: int in 3:
			var k: float = clampf((_t - 0.35 - 0.22 * float(i)) / 0.3, 0.0, 1.0)
			var s: float = (78.0 if i == 1 else 64.0) * (1.0 - pow(1.0 - k, 3.0)) * (1.0 + 0.15 * sin(k * PI))
			if s < 1.0:
				continue
			var p: Vector2 = Vector2(size.x * 0.5 + (float(i) - 1.0) * 100.0, card.position.y + 215.0 - (8.0 if i == 1 else 0.0))
			var r: Rect2 = Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
			if i < int(info["stars"]):
				draw_texture_rect(UIKit.icon("star-filled"), r, false, Color("#FFC53D"))
			else:
				draw_texture_rect(UIKit.icon("star"), r, false, Color(pal["ink"], 0.25))
		_text(str(info["verdict"]), card.position.y + 310, 28, 500, Color(pal["ink"], a))
		_text(str(info["stats"]), card.position.y + 352, 22, 500, Color(pal["muted"], a))
		_text("Can you do it in one shot?", card.position.y + 405, 22, 600, Color(pal["accent"], a * clampf((_t - 1.0) / 0.4, 0.0, 1.0)))


## The invitation: the icon, the name, where to get it, and a QR code.
class _Outro:
	extends Control
	var _t: float = 0.0
	var _icon: Texture2D = load("res://assets/icon.svg")
	var _qr: Texture2D = load("res://assets/share/qr.png")

	func show_at(t: float) -> void:
		_t = t
		queue_redraw()

	func _text(s: String, y: float, fs: int, weight: int, col: Color) -> void:
		var f: Font = UIKit.font(weight)
		var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - w) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var top: Color = Color("#3A2F7A")
		var bottom: Color = Color("#15122F")
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
		var k: float = 1.0 - pow(1.0 - clampf(_t / 0.5, 0.0, 1.0), 3.0)
		var s: float = 176.0 * (0.8 + 0.2 * k)
		draw_texture_rect(_icon, Rect2(Vector2((size.x - s) * 0.5, 120 + (176.0 - s) * 0.5), Vector2(s, s)), false, Color(1, 1, 1, k))
		var a1: float = clampf((_t - 0.25) / 0.4, 0.0, 1.0)
		_text("One Clean Shot", 380, 50, 400, Color("#F4F1FF", a1))
		_text("a quiet ricochet puzzle", 420, 22, 500, Color(1, 1, 1, 0.55 * a1))
		var a2: float = clampf((_t - 0.6) / 0.4, 0.0, 1.0)
		_text("Can you do it in one shot?", 500, 28, 600, Color("#FFC9A8", a2))
		# "Free on Google Play" pill.
		var pill: Rect2 = Rect2(Vector2(110, 540), Vector2(320, 64))
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#FF6B5B", a2)
		sb.set_corner_radius_all(32)
		draw_style_box(sb, pill)
		_text("Free on Google Play", pill.position.y + 42, 24, 600, Color(1, 1, 1, a2))
		var a3: float = clampf((_t - 0.9) / 0.4, 0.0, 1.0)
		var q: float = 150.0
		var qr: Rect2 = Rect2(Vector2((size.x - q) * 0.5, 660), Vector2(q, q))
		var back: StyleBoxFlat = StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, a3)
		back.set_corner_radius_all(18)
		draw_style_box(back, qr.grow(10))
		draw_texture_rect(_qr, qr, false, Color(1, 1, 1, a3))
		_text("SCAN TO PLAY  ·  " + URL, 870, 18, 600, Color(1, 1, 1, 0.6 * a3))
