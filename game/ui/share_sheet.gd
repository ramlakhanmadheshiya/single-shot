extends Overlay
## Share your shot: a preview of the picture, then Share (the picture), Save (a
## video of the shot: the game's opening, your shot, the result and an invite to
## play) and Copy link.

var info: Dictionary = {}
var _image: Image
var _preview: TextureRect
var _status: Label
var _bar: _Bar
var _video: PromoVideo
var _share_video: Button
var _save_wanted: bool = false


func build() -> void:
	name = "Share"
	add_title("Share your shot")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 16)
	var holder: CenterContainer = CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 560)
	body.add_child(holder)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(432, 540)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(_preview)
	_preview.pivot_offset = Vector2(216, 270)
	_preview.rotation = deg_to_rad(-2.5)
	_status = UIKit.label("Making your card…", 20, pal["muted"], 500)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	body.add_child(row)
	row.add_child(_action("share-2", "SHARE", "ShareNow", func() -> void: ShareService.share(_image, info)))
	row.add_child(_action("download", "SAVE VIDEO", "Save", _save_video))
	row.add_child(_action("link", "COPY LINK", "CopyLink", func() -> void: ShareService.copy_link(info)))
	_bar = _Bar.new()
	_bar.pal = pal
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.visible = false
	body.add_child(_bar)
	_share_video = UIKit.pill("Share video", pal, "accent", Vector2(0, 84), 26)
	_share_video.name = "ShareVideo"
	_share_video.visible = false
	_share_video.pressed.connect(func() -> void:
		if not _video.share(ShareService.message_for(info)):
			_status.text = "Couldn't open sharing."
	)
	body.add_child(_share_video)
	ShareService.finished.connect(func(_ok: bool, msg: String) -> void:
		if is_inside_tree() and not msg.is_empty():
			_status.text = msg
	)
	_prepare_video.call_deferred()
	ShareCard.render(self, info, func(img: Image) -> void:
		if not is_inside_tree():
			return
		_image = img
		if img != null:
			_preview.texture = ImageTexture.create_from_image(img)
			_status.text = "Can your friends match it?"
		else:
			_status.text = "Share the link with your friends."
	)


## Makes the video and saves it to the gallery, with progress.
## Starts building the video quietly as soon as the card opens (on phones), so
## Save is usually instant.
func _prepare_video() -> void:
	if _video != null or not Engine.has_singleton("SingleShotVideo"):
		return
	_video = PromoVideo.new()
	add_child(_video)
	_video.progress.connect(func(f: float) -> void:
		_bar.value = f
		_bar.queue_redraw()
		if _save_wanted:
			_status.text = "Making your video…  %d%%" % int(f * 100.0)
	)
	_video.done.connect(func(ok: bool, msg: String) -> void:
		_bar.visible = false
		if not ok:
			_status.text = msg
		elif _save_wanted:
			_finish_save()
	)
	_video.make(info)


## Saves the video: right away if it's ready, otherwise as soon as it is.
func _save_video() -> void:
	if not PromoVideo.available():
		_status.text = "Saving the video works in the Android app. Here's the picture instead."
		ShareService.save(_image, info)
		return
	if _video == null:
		if Engine.has_singleton("SingleShotVideo"):
			_prepare_video()
		else:
			# Desktop (debug): writes the frames for checking.
			_video = PromoVideo.new()
			add_child(_video)
			_video.done.connect(func(_ok: bool, msg: String) -> void:
				_bar.visible = false
				_status.text = msg
			)
			_video.make(info)
	_save_wanted = true
	if _video.finished:
		_finish_save()
	else:
		_bar.visible = true
		_status.text = "Making your video…  %d%%" % int(_bar.value * 100.0)


func _finish_save() -> void:
	_save_wanted = false
	if _video.save_to_gallery():
		_status.text = "Saved to Movies › Single Shot"
		AudioManager.play("unlock", 1.0, -6.0)
	else:
		_status.text = "Video ready. Share it to keep a copy."
	_share_video.visible = true


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var b: Button = UIKit.icon_button(icon_name, pal, 84.0)
	b.name = node_name
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.label(caption, 16, pal["muted"], 600))
	if _first_focus == null:
		_first_focus = b
	return box


## A thin progress bar.
class _Bar:
	extends Control
	var pal: Dictionary
	var value: float = 0.0

	func _draw() -> void:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(5)
		sb.bg_color = Color(pal["ink"], 0.1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		sb.bg_color = pal["accent"]
		draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * value), size.y)))
